import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca_ble.dart';
import 'package:samba_app/nucleo/ble/conexao_equipamento.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

import '../ble/pacotes_firmware.dart';

class ConexaoEquipamentoFalsa implements ConexaoEquipamento {
  final _medicoes = StreamController<Uint8List>();
  final _estados = StreamController<Uint8List>();
  final comandos = <List<int>>[];
  Uint8List estadoAtual = estadoComStatus(0x0004);
  void Function(List<int> comando)? responder;
  bool desconectada = false;

  @override
  Stream<Uint8List> get medicoes => _medicoes.stream;

  @override
  Stream<Uint8List> get estados => _estados.stream;

  @override
  Future<Uint8List> lerEstado() async => estadoAtual;

  @override
  Future<void> escreverControle(Uint8List comando) async {
    comandos.add(List.of(comando));
    responder?.call(comando);
  }

  @override
  Future<void> desconectar() async {
    desconectada = true;
  }

  void notificarMedicao(Uint8List pacote) => _medicoes.add(pacote);

  void notificarEstado(int status) {
    estadoAtual = estadoComStatus(status);
    _estados.add(estadoAtual);
  }

  void notificarEstadoBruto(Uint8List dados) => _estados.add(dados);

  void falhar(Object erro) => _medicoes.addError(erro);

  Future<void> encerrar() => _medicoes.close();
}

Future<void> aguardarEntregas() => Future<void>.delayed(Duration.zero);

void main() {
  group('FonteForcaBle', () {
    late ConexaoEquipamentoFalsa conexao;
    late FonteForcaBle fonte;
    late List<AmostraForca> recebidas;
    late List<Object> erros;

    setUp(() {
      conexao = ConexaoEquipamentoFalsa();
      fonte = FonteForcaBle(
        conexao: conexao,
        tempoLimiteInicio: const Duration(milliseconds: 100),
        silencioParada: const Duration(milliseconds: 40),
        tempoLimiteParada: const Duration(milliseconds: 300),
        tempoLimiteTara: const Duration(milliseconds: 100),
      );
      recebidas = [];
      erros = [];
      final assinatura = fonte.amostras.listen(
        recebidas.add,
        onError: erros.add,
      );
      addTearDown(assinatura.cancel);
    });

    void confirmarInicio() => conexao.responder = (comando) {
      if (comando.first == 0x01) conexao.notificarEstado(0x0024);
    };

    test('usa os tempos padrão do protocolo', () {
      final padrao = FonteForcaBle(conexao: ConexaoEquipamentoFalsa());

      expect(padrao.tempoLimiteInicio, const Duration(seconds: 2));
      expect(padrao.silencioParada, const Duration(milliseconds: 600));
      expect(padrao.tempoLimiteParada, const Duration(seconds: 10));
      expect(padrao.tempoLimiteTara, const Duration(seconds: 3));
    });

    test('decodifica os pacotes do firmware em amostras', () async {
      conexao.notificarMedicao(bytesHex(pacoteCompletoFirmware));
      conexao.notificarMedicao(bytesHex(pacoteParcialFirmware));
      await aguardarEntregas();

      expect(recebidas.map((amostra) => amostra.sequencia), [
        for (var indice = 0; indice < 26; indice++) indice,
      ]);
      expect(recebidas.first.forcaN, 0.12);
      expect(recebidas.last.timestampUs, 21458);
      expect(recebidas.last.forcaN, 56.21);
      expect(erros, isEmpty);
    });

    test('conta e ignora pacotes inválidos sem interromper o fluxo', () async {
      conexao.notificarMedicao(Uint8List.fromList([0x01, 0x00]));
      conexao.notificarMedicao(
        bytesHex(pacoteCompletoFirmware).sublist(0, 100),
      );
      conexao.notificarMedicao(bytesHex(pacoteCompletoFirmware));
      await aguardarEntregas();

      expect(fonte.pacotesInvalidos, 2);
      expect(recebidas, hasLength(20));
      expect(erros, isEmpty);
    });

    test('repassa como erro a falha e o fim da conexão', () async {
      final falha = Exception('Falha na notificação.');
      conexao.falhar(falha);
      await conexao.encerrar();
      await aguardarEntregas();

      expect(erros, hasLength(2));
      expect(erros.first, same(falha));
      expect(erros.last, isStateError);
    });

    test('inicia com START e espera a aquisição ligar', () async {
      confirmarInicio();

      await fonte.iniciar();
      await fonte.iniciar();

      expect(conexao.comandos, [
        [0x01],
      ]);
      expect(fonte.ultimoEstado!.aquisicaoEmAndamento, isTrue);
    });

    test('desliga o modo bruto antes do START', () async {
      conexao.estadoAtual = estadoComStatus(0x0014);
      confirmarInicio();

      await fonte.iniciar();

      expect(conexao.comandos, [
        [0x04, 0x00],
        [0x01],
      ]);
    });

    test('envia STOP e falha sem confirmação do início', () async {
      await expectLater(fonte.iniciar(), throwsA(isA<TimeoutException>()));

      expect(conexao.comandos, [
        [0x01],
        [0x02],
      ]);
    });

    test('para com STOP e espera os pacotes cessarem', () async {
      confirmarInicio();
      await fonte.iniciar();
      final relogio = Stopwatch()..start();
      final parada = fonte.parar();
      var concluiu = false;
      unawaited(parada.then((_) => concluiu = true));

      for (var passo = 0; passo < 3; passo++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        conexao.notificarMedicao(bytesHex(pacoteParcialFirmware));
      }
      expect(concluiu, isFalse);
      await parada;

      // Último pacote em cerca de 60 ms, mais 40 ms de silêncio.
      expect(relogio.elapsedMilliseconds, greaterThanOrEqualTo(95));
      expect(recebidas, hasLength(18));
      expect(conexao.comandos.last, [0x02]);

      await fonte.parar();
      expect(conexao.comandos, hasLength(2));
    });

    test('falha ao parar se os pacotes não cessarem', () async {
      confirmarInicio();
      await fonte.iniciar();
      final envio = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => conexao.notificarMedicao(bytesHex(pacoteParcialFirmware)),
      );
      addTearDown(envio.cancel);

      await expectLater(fonte.parar(), throwsA(isA<TimeoutException>()));
    });

    test('tara esperando o bit de tara ligar e desligar', () async {
      var desligou = false;
      conexao.responder = (comando) {
        conexao.notificarEstado(0x0006);
        Timer(const Duration(milliseconds: 30), () {
          desligou = true;
          conexao.notificarEstado(0x0004);
        });
      };

      await fonte.tarar();

      expect(desligou, isTrue);
      expect(conexao.comandos, [
        [0x03],
      ]);
      expect(fonte.ultimoEstado!.taraEmAndamento, isFalse);
    });

    test('falha a tara se o bit de tara não desligar', () async {
      conexao.responder = (comando) => conexao.notificarEstado(0x0006);

      await expectLater(fonte.tarar(), throwsA(isA<TimeoutException>()));
    });

    test('expõe o último estado e ignora estados inválidos', () async {
      conexao.notificarEstado(0x0001);
      await aguardarEntregas();
      conexao.notificarEstadoBruto(Uint8List(5));
      await aguardarEntregas();

      expect(fonte.ultimoEstado!.saturacao, isTrue);
      expect(fonte.ultimoEstado!.taxaNominalHz, 1200);
    });

    test('desconecta e encerra o fluxo de amostras sem erro', () async {
      final fim = fonte.amostras.toList();
      await fonte.desconectar();

      expect(conexao.desconectada, isTrue);
      expect(await fim, isEmpty);
      expect(erros, isEmpty);
    });
  });
}
