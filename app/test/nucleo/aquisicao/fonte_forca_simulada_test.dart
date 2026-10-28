import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca_simulada.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

List<double> rampa(int quantidade) => [
  for (var indice = 0; indice < quantidade; indice++) indice.toDouble(),
];

Future<List<AmostraForca>> coletarAmostras(FonteForca fonte, int quantidade) =>
    fonte.amostras
        .take(quantidade)
        .toList()
        .timeout(const Duration(seconds: 5));

Future<void> aguardarEntregas() => Future<void>.delayed(Duration.zero);

void main() {
  group('FonteForcaSimulada', () {
    late FonteForca fonte;
    late List<AmostraForca> recebidas;

    setUp(() {
      fonte = FonteForcaSimulada(forcasN: rampa(100));
      recebidas = [];
      final assinatura = fonte.amostras.listen(recebidas.add);
      addTearDown(assinatura.cancel);
    });

    tearDown(() async {
      await fonte.parar();
    });

    test('não emite antes de iniciar', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(recebidas, isEmpty);
    });

    test('emite lotes de 20 amostras a cada 20 ms', () async {
      final relogio = Stopwatch()..start();
      final coleta = coletarAmostras(fonte, 60);
      await fonte.iniciar();
      await aguardarEntregas();
      expect(recebidas, hasLength(20));

      await coleta;
      relogio.stop();

      // O primeiro lote sai no início e os outros dois após 40 ms; a margem
      // considera a precisão do agendamento do sistema.
      expect(relogio.elapsedMilliseconds, greaterThanOrEqualTo(35));
      expect(recebidas, hasLength(60));
    });

    test('numera e marca o tempo das amostras pelo índice da série', () async {
      await fonte.iniciar();
      await coletarAmostras(fonte, 40);

      for (var indice = 0; indice < 40; indice++) {
        expect(recebidas[indice].sequencia, indice);
        expect(recebidas[indice].timestampUs, indice * 1000);
        expect(recebidas[indice].forcaN, indice);
        expect(recebidas[indice].status, 0);
      }
    });

    test('reproduz a série de isometria por padrão', () async {
      final fonte = FonteForcaSimulada();
      addTearDown(fonte.parar);
      final coleta = coletarAmostras(fonte, 20);
      await fonte.iniciar();

      expect(
        (await coleta).map((amostra) => amostra.forcaN),
        gerarSerieIsometria().sublist(0, 20),
      );
    });

    test('para de emitir ao fim da série e pode ser reiniciada', () async {
      final fonte = FonteForcaSimulada(forcasN: rampa(45));
      addTearDown(fonte.parar);
      final recebidas = <AmostraForca>[];
      final assinatura = fonte.amostras.listen(recebidas.add);
      addTearDown(assinatura.cancel);

      await fonte.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(recebidas, hasLength(45));
      expect(recebidas.last.sequencia, 44);
      expect(recebidas.last.timestampUs, 44000);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(recebidas, hasLength(45));

      await fonte.iniciar();
      await aguardarEntregas();
      expect(recebidas, hasLength(65));
      expect(recebidas[45].sequencia, 0);
      expect(recebidas[45].timestampUs, 0);
    });

    test('iniciar novamente não duplica nem reinicia a série', () async {
      final primeiraColeta = coletarAmostras(fonte, 40);
      await Future.wait([fonte.iniciar(), fonte.iniciar()]);
      await primeiraColeta;
      final segundaColeta = coletarAmostras(fonte, 20);
      await fonte.iniciar();
      await segundaColeta;
      await fonte.parar();

      expect(recebidas.map((amostra) => amostra.sequencia).take(60), [
        for (var indice = 0; indice < 60; indice++) indice,
      ]);
    });

    test('parar cancela a emissão e pode ser chamado repetidamente', () async {
      await fonte.parar();
      final coleta = coletarAmostras(fonte, 20);
      await fonte.iniciar();
      await coleta;
      await fonte.parar();
      await aguardarEntregas();
      final quantidade = recebidas.length;

      await fonte.parar();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(recebidas, hasLength(quantidade));
    });

    test('parar imediatamente entrega só o primeiro lote', () async {
      await fonte.iniciar();
      await fonte.parar();
      await aguardarEntregas();
      expect(recebidas, hasLength(20));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(recebidas, hasLength(20));
    });

    test('reiniciar recomeça do início da série', () async {
      final primeiraColeta = coletarAmostras(fonte, 30);
      await fonte.iniciar();
      final primeiras = await primeiraColeta;
      await fonte.parar();
      final segundaColeta = coletarAmostras(fonte, 30);
      await fonte.iniciar();
      final segundas = await segundaColeta;

      for (var indice = 0; indice < 30; indice++) {
        expect(segundas[indice].sequencia, primeiras[indice].sequencia);
        expect(segundas[indice].timestampUs, primeiras[indice].timestampUs);
        expect(segundas[indice].forcaN, primeiras[indice].forcaN);
      }
      expect(segundas.first.sequencia, 0);
    });

    test('compartilha as mesmas amostras entre assinantes', () async {
      final primeiraColeta = coletarAmostras(fonte, 20);
      final segundaColeta = coletarAmostras(fonte, 20);
      await fonte.iniciar();
      final coletas = await Future.wait([primeiraColeta, segundaColeta]);

      expect(coletas[0], hasLength(20));
      expect(coletas[1], orderedEquals(coletas[0]));
    });
  });
}
