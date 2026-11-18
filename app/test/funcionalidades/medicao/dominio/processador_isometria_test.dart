import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/processador_isometria.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca amostra(int timestampUs, double forcaN) => AmostraForca(
  sequencia: 0,
  timestampUs: timestampUs,
  forcaN: forcaN,
  status: 0,
);

ResultadoIsometria processar(List<AmostraForca> amostras) =>
    const ProcessadorIsometria().processar(amostras: amostras, parametros: {});

List<AmostraForca> serieRampa({
  double rampaS = 0.5,
  double platoS = 3,
  double baseN = 0,
  double ruidoN = 0,
}) {
  const passoUs = 500;
  final aleatorio = Random(1);
  final forcasN = <double>[];
  void trecho(double duracaoS, double Function(int indice, int total) forca) {
    final total = (duracaoS * 1e6 / passoUs).round();
    for (var indice = 0; indice < total; indice++) {
      forcasN.add(forca(indice, total));
    }
  }

  trecho(1, (indice, total) => 0);
  trecho(rampaS, (indice, total) => 400 * indice / total);
  trecho(platoS, (indice, total) => 400);
  trecho(0.5, (indice, total) => 400 * (total - indice) / total);
  trecho(1, (indice, total) => 0);
  return [
    for (var indice = 0; indice < forcasN.length; indice++)
      amostra(
        indice * passoUs,
        baseN + forcasN[indice] + (aleatorio.nextDouble() * 2 - 1) * ruidoN,
      ),
  ];
}

void main() {
  group('ProcessadorIsometria', () {
    test('informa as métricas, o pico e o instante do pico', () {
      final resultado = processar([
        amostra(0, 10),
        amostra(250000, 40),
        amostra(500000, 55),
        amostra(750000, 30),
      ]);

      expect(resultado.metricas.forcaMaximaN, 55);
      expect(resultado.instantePicoS, 0.5);
      expect(resultado.metricas.forcaMediaN, 33.75);
      expect(resultado.metricas.duracaoS, 0.75);
      // (10 + 40) / 2 * 0.25 + (40 + 55) / 2 * 0.25 + (55 + 30) / 2 * 0.25.
      expect(resultado.metricas.impulsoNs, closeTo(28.75, 1e-9));
    });

    test('usa o primeiro instante quando há empate no pico', () {
      final resultado = processar([
        amostra(0, 10),
        amostra(100000, 50),
        amostra(300000, 50),
        amostra(400000, 20),
      ]);

      expect(resultado.metricas.forcaMaximaN, 50);
      expect(resultado.instantePicoS, 0.1);
    });

    test('mede o instante a partir da primeira amostra', () {
      final resultado = processar([
        amostra(2000000, 5),
        amostra(2400000, 25),
        amostra(3100000, 15),
      ]);

      expect(resultado.metricas.forcaMaximaN, 25);
      expect(resultado.instantePicoS, 0.4);
    });

    test('informa instante zero quando o pico é a primeira amostra', () {
      final resultado = processar([amostra(1500000, 80), amostra(1600000, 60)]);

      expect(resultado.metricas.forcaMaximaN, 80);
      expect(resultado.instantePicoS, 0);
    });

    test('preserva o sinal do pico para forças negativas', () {
      final resultado = processar([
        amostra(0, -30),
        amostra(200000, -5),
        amostra(600000, -12),
      ]);

      expect(resultado.metricas.forcaMaximaN, -5);
      expect(resultado.instantePicoS, 0.2);
    });

    test('calcula as métricas de cada uma de três repetições', () {
      final forcas = <double>[
        ...[0, 100, 100, 100, 100, 50],
        ...[0, 0, 60, 80, 70, 30],
        ...[0, 0, 40, 90, 90, 20],
        ...[5, 0],
      ];
      final resultado = processar([
        for (var indice = 0; indice < forcas.length; indice++)
          amostra(5000000 + indice * 100000, forcas[indice]),
      ]);

      // Limiares de 20 N e 10 N sobre o pico de 100 N: os trechos são os
      // índices 1 a 5, 8 a 11 e 14 a 17, em passos de 0,1 s.
      expect(resultado.metricas.forcaMaximaN, 100);
      expect(resultado.instantePicoS, 0.1);
      expect(resultado.repeticoes, hasLength(3));
      expect(resultado.repeticoes.clear, throwsUnsupportedError);

      final [primeira, segunda, terceira] = resultado.repeticoes;
      expect(primeira.inicioS, 0.1);
      expect(primeira.duracaoS, 0.4);
      expect(primeira.picoN, 100);
      expect(primeira.instantePicoS, 0.1);
      // 3 × (100 + 100) / 2 × 0,1 + (100 + 50) / 2 × 0,1.
      expect(primeira.impulsoNs, closeTo(37.5, 1e-9));

      expect(segunda.inicioS, 0.8);
      expect(segunda.duracaoS, 0.3);
      expect(segunda.picoN, 80);
      expect(segunda.instantePicoS, 0.9);
      // (60 + 80) / 2 × 0,1 + (80 + 70) / 2 × 0,1 + (70 + 30) / 2 × 0,1.
      expect(segunda.impulsoNs, closeTo(19.5, 1e-9));

      expect(terceira.inicioS, 1.4);
      expect(terceira.duracaoS, 0.3);
      expect(terceira.picoN, 90);
      // Empate em 90 N: vale o primeiro instante.
      expect(terceira.instantePicoS, 1.5);
      // (40 + 90) / 2 × 0,1 + (90 + 90) / 2 × 0,1 + (90 + 20) / 2 × 0,1.
      expect(terceira.impulsoNs, closeTo(21, 1e-9));

      expect(resultado.mediaPicosN, 90);
    });

    test('não informa repetições quando nenhuma é detectável', () {
      final resultado = processar([
        amostra(0, 0),
        amostra(100000, 50),
        amostra(200000, 50),
        amostra(300000, 0),
      ]);

      expect(resultado.metricas.forcaMaximaN, 50);
      expect(resultado.instantePicoS, 0.1);
      expect(resultado.repeticoes, isEmpty);
      expect(resultado.mediaPicosN, isNull);
    });

    test('marca o início da contração antes do início detectado', () {
      final repeticao = processar(serieRampa()).repeticoes.single;

      // A rampa de 800 N/s começa em 1 s e chega a 10 N em 12,5 ms.
      expect(repeticao.inicioContracaoS, closeTo(1.0125, 1e-9));
      expect(repeticao.inicioContracaoS, lessThan(repeticao.inicioS));
    });

    test('usa a mediana do repouso anterior como linha de base', () {
      final repeticao = processar(serieRampa(baseN: 20)).repeticoes.single;

      // Linha de base de 20 N: o limiar de 30 N é atingido nos mesmos 12,5 ms.
      expect(repeticao.inicioContracaoS, closeTo(1.0125, 1e-9));
    });

    test('calcula a rfd média nas janelas e a rfd máxima', () {
      final repeticao = processar(serieRampa()).repeticoes.single;

      // Rampa de 400 N em 0,5 s: 800 N/s, ou 200 %Fmáx/s com pico de 400 N.
      expect(repeticao.rfdJanelas.map((rfd) => rfd.janelaUs), [
        50000,
        100000,
        200000,
      ]);
      for (final rfd in [...repeticao.rfdJanelas, repeticao.rfdMaxima]) {
        expect(rfd.rfdNPorS, closeTo(800, 1e-6));
        expect(rfd.rfdPercentualPorS, closeTo(200, 1e-6));
      }
      expect(repeticao.rfdMaxima.janelaUs, 20000);
    });

    test('calcula a força sustentada no platô', () {
      final repeticao = processar(serieRampa()).repeticoes.single;

      expect(repeticao.forcaSustentadaN, closeTo(400, 1e-9));
      expect(repeticao.desvioForcaSustentadaN, closeTo(0, 1e-9));
      expect(repeticao.coeficienteVariacaoPercentual, closeTo(0, 1e-9));
    });

    test('devolve nulo quando a repetição é mais curta que a janela', () {
      final repeticao =
          const ProcessadorIsometria(janelasRfdUs: [50000, 1000000])
              .processar(
                amostras: serieRampa(rampaS: 0.1, platoS: 0.4),
                parametros: {},
              )
              .repeticoes
              .single;

      expect(repeticao.forcaSustentadaN, isNull);
      expect(repeticao.desvioForcaSustentadaN, isNull);
      expect(repeticao.coeficienteVariacaoPercentual, isNull);
      expect(repeticao.rfdJanelas[0].rfdNPorS, isNotNull);
      expect(repeticao.rfdJanelas[1].rfdNPorS, isNull);
      expect(repeticao.rfdJanelas[1].rfdPercentualPorS, isNull);
    });

    test('mede a variabilidade do ruído uniforme no platô', () {
      final repeticao = processar(serieRampa(ruidoN: 2)).repeticoes.single;

      // Ruído uniforme de ±2 N tem desvio padrão de 2 / √3 ≈ 1,15 N.
      expect(repeticao.desvioForcaSustentadaN, closeTo(2 / sqrt(3), 0.1));
      expect(repeticao.forcaSustentadaN, closeTo(400, 0.5));
      expect(repeticao.coeficienteVariacaoPercentual, closeTo(0.29, 0.03));
    });

    test('rejeita parâmetros inválidos', () {
      final amostras = serieRampa();

      for (final processador in [
        const ProcessadorIsometria(limiarInicioN: -1),
        const ProcessadorIsometria(limiarInicioN: double.nan),
        const ProcessadorIsometria(janelasRfdUs: [0]),
        const ProcessadorIsometria(janelasRfdUs: [50000, -1]),
        const ProcessadorIsometria(janelaRfdMaximaUs: 0),
        const ProcessadorIsometria(janelaForcaSustentadaUs: 0),
      ]) {
        expect(
          () => processador.processar(amostras: amostras, parametros: {}),
          throwsArgumentError,
        );
      }
    });

    test('repassa os erros de validação das métricas', () {
      expect(() => processar([]), throwsArgumentError);
      expect(() => processar([amostra(0, 10)]), throwsArgumentError);
      expect(
        () => processar([amostra(100, 10), amostra(100, 20)]),
        throwsArgumentError,
      );
      expect(
        () => processar([amostra(200, 10), amostra(100, 20)]),
        throwsArgumentError,
      );
    });
  });
}
