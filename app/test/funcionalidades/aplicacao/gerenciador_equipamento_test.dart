import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/controlador_medicao.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/gerenciador_equipamento.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca_ble.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca_simulada.dart';
import 'package:samba_app/nucleo/ble/conexao_equipamento.dart';

import '../../nucleo/ble/pacotes_firmware.dart';

class EquipamentoFalso implements EquipamentoEncontrado {
  @override
  String get nome => 'SAMBA';

  @override
  String get identificador => 'AA:BB:CC:DD:EE:FF';

  @override
  int get rssiDbm => -55;
}

class ConexaoFalsa implements ConexaoEquipamento {
  final _medicoes = StreamController<Uint8List>.broadcast();
  final _estados = StreamController<Uint8List>.broadcast();
  final _fim = Completer<void>();
  final comandos = <List<int>>[];
  Uint8List estadoAtual = estadoComStatus(0x0004);
  int desconexoes = 0;

  @override
  Stream<Uint8List> get medicoes => _medicoes.stream;

  @override
  Stream<Uint8List> get estados => _estados.stream;

  @override
  Future<void> get encerrada => _fim.future;

  @override
  Future<Uint8List> lerEstado() async => estadoAtual;

  @override
  Future<void> escreverControle(Uint8List comando) async {
    comandos.add(List.of(comando));
    switch (comando.first) {
      case 0x01:
        notificarEstado(0x0024);
        notificarMedicao(bytesHex(pacoteCompletoFirmware));
      case 0x02:
        notificarEstado(0x0004);
      case 0x03:
        notificarEstado(0x0006);
        Timer(const Duration(milliseconds: 10), () => notificarEstado(0x0004));
    }
  }

  @override
  Future<void> desconectar() async {
    desconexoes++;
    await _terminar();
  }

  void notificarEstado(int status) {
    estadoAtual = estadoComStatus(status);
    _estados.add(estadoAtual);
  }

  void notificarMedicao(Uint8List pacote) => _medicoes.add(pacote);

  Future<void> cair() async {
    _medicoes.addError(StateError('O equipamento desconectou.'));
    await _terminar();
  }

  Future<void> _terminar() async {
    if (_fim.isCompleted) return;
    await _medicoes.close();
    await _estados.close();
    _fim.complete();
  }
}

class ConectorFalso implements ConectorEquipamento {
  final conexoes = <ConexaoFalsa>[];
  Completer<void>? busca;
  Exception? erroAoConectar;

  @override
  Future<List<EquipamentoEncontrado>> procurar({
    Duration tempoLimite = const Duration(seconds: 5),
  }) async {
    await busca?.future;
    return [EquipamentoFalso()];
  }

  @override
  Future<ConexaoEquipamento> conectar(EquipamentoEncontrado equipamento) async {
    if (erroAoConectar case final erro?) throw erro;
    final conexao = ConexaoFalsa();
    conexoes.add(conexao);
    return conexao;
  }
}

Future<void> aguardarEntregas() => Future<void>.delayed(Duration.zero);

void main() {
  group('GerenciadorEquipamento', () {
    late ConectorFalso conector;
    late GerenciadorEquipamento gerenciador;
    late List<EstadoConexao> estados;

    setUp(() {
      conector = ConectorFalso();
      gerenciador = GerenciadorEquipamento(conector: conector);
      estados = [];
      gerenciador.addListener(() {
        if (estados.lastOrNull != gerenciador.estado) {
          estados.add(gerenciador.estado);
        }
      });
    });

    Future<ConexaoFalsa> conectar() async {
      final encontrados = await gerenciador.procurar();
      await gerenciador.conectar(encontrados.single);
      return conector.conexoes.last;
    }

    test('começa desconectado no modo bluetooth', () {
      expect(gerenciador.estado, EstadoConexao.desconectado);
      expect(gerenciador.modo, ModoAquisicao.bluetooth);
      expect(gerenciador.conexao, isNull);
      expect(gerenciador.ultimoEstado, isNull);
    });

    test('procura e volta a desconectado com os encontrados', () async {
      conector.busca = Completer<void>();
      final busca = gerenciador.procurar();
      expect(gerenciador.estado, EstadoConexao.procurando);

      conector.busca!.complete();
      final encontrados = await busca;

      expect(encontrados.single.nome, 'SAMBA');
      expect(gerenciador.encontrados, encontrados);
      expect(estados, [EstadoConexao.procurando, EstadoConexao.desconectado]);
    });

    test('conecta e lê o estado do equipamento', () async {
      await conectar();

      expect(gerenciador.estado, EstadoConexao.conectado);
      expect(gerenciador.equipamento!.identificador, 'AA:BB:CC:DD:EE:FF');
      expect(gerenciador.ultimoEstado!.semCalibracao, isTrue);
      expect(gerenciador.ultimoEstado!.taxaNominalHz, 1200);
      expect(estados, [
        EstadoConexao.procurando,
        EstadoConexao.desconectado,
        EstadoConexao.conectando,
        EstadoConexao.conectado,
      ]);
    });

    test('volta a desconectado quando a conexão falha', () async {
      final erro = Exception('Equipamento fora de alcance.');
      conector.erroAoConectar = erro;

      await expectLater(
        gerenciador.conectar(EquipamentoFalso()),
        throwsA(same(erro)),
      );
      expect(gerenciador.estado, EstadoConexao.desconectado);
      expect(gerenciador.conexao, isNull);
    });

    test('rejeita procurar ou conectar sem estar desconectado', () async {
      await conectar();

      await expectLater(gerenciador.procurar(), throwsStateError);
      await expectLater(
        gerenciador.conectar(EquipamentoFalso()),
        throwsStateError,
      );
      expect(gerenciador.estado, EstadoConexao.conectado);
    });

    test('mantém a conexão aberta entre medições', () async {
      final conexao = await conectar();
      final fonte = gerenciador.criarFonte(Exercicio.remada);

      for (var medicao = 0; medicao < 2; medicao++) {
        final controlador = ControladorMedicao(
          fonte: gerenciador.criarFonte(Exercicio.remada),
        );
        await controlador.iniciar(Exercicio.remada);
        await aguardarEntregas();
        final sessao = await controlador.finalizar();
        controlador.dispose();

        expect(sessao.quantidadeAmostras, 20);
      }

      expect(gerenciador.criarFonte(Exercicio.salto), same(fonte));
      expect(fonte, isA<FonteForcaBle>());
      expect(conexao.desconexoes, 0);
      expect(gerenciador.estado, EstadoConexao.conectado);
      expect(conexao.comandos, [
        [0x01],
        [0x02],
        [0x01],
        [0x02],
      ]);
    });

    test('falha ao criar a fonte bluetooth sem conexão', () {
      expect(
        () => gerenciador.criarFonte(Exercicio.remada),
        throwsA(
          isA<StateError>().having(
            (erro) => erro.message,
            'message',
            contains('conecte o equipamento'),
          ),
        ),
      );
    });

    test('cria uma fonte simulada por medição no modo simulado', () {
      gerenciador.modo = ModoAquisicao.simulado;

      final primeira = gerenciador.criarFonte(Exercicio.salto);
      final segunda = gerenciador.criarFonte(Exercicio.salto);

      expect(primeira, isA<FonteForcaSimulada>());
      expect(segunda, isNot(same(primeira)));
    });

    test('volta a desconectado quando o equipamento desconecta', () async {
      final conexao = await conectar();
      final controlador = ControladorMedicao(
        fonte: gerenciador.criarFonte(Exercicio.remada),
      );
      await controlador.iniciar(Exercicio.remada);

      await conexao.cair();
      await aguardarEntregas();

      expect(gerenciador.estado, EstadoConexao.desconectado);
      expect(gerenciador.ultimoEstado, isNull);
      expect(controlador.interrompida, isTrue);
      expect(controlador.motivoInterrupcao, 'O equipamento desconectou.');
      expect(() => gerenciador.criarFonte(Exercicio.remada), throwsStateError);
      controlador.dispose();
    });

    test('desconecta pelo gerenciador e aceita repetir', () async {
      final conexao = await conectar();

      await gerenciador.desconectar();
      await gerenciador.desconectar();

      expect(conexao.desconexoes, 1);
      expect(gerenciador.estado, EstadoConexao.desconectado);
      expect(gerenciador.conexao, isNull);
    });

    test('tara o equipamento conectado', () async {
      final conexao = await conectar();

      await gerenciador.tarar();

      expect(conexao.comandos, [
        [0x03],
      ]);
      expect(gerenciador.ultimoEstado!.taraEmAndamento, isFalse);
    });

    test('rejeita tarar sem conexão e não tara no modo simulado', () async {
      await expectLater(gerenciador.tarar(), throwsStateError);

      gerenciador.modo = ModoAquisicao.simulado;
      await gerenciador.tarar();
    });

    test('rejeita tarar durante uma medição', () async {
      final conexao = await conectar();
      conexao.notificarEstado(0x0024);
      await aguardarEntregas();

      await expectLater(gerenciador.tarar(), throwsStateError);
      expect(conexao.comandos, isEmpty);
    });

    test('acompanha e notifica o último estado do equipamento', () async {
      final conexao = await conectar();
      var notificacoes = 0;
      gerenciador.addListener(() => notificacoes++);

      conexao.notificarEstado(0x0009);
      await aguardarEntregas();

      expect(gerenciador.ultimoEstado!.saturacao, isTrue);
      expect(gerenciador.ultimoEstado!.erroAdc, isTrue);
      expect(notificacoes, 1);
    });
  });
}
