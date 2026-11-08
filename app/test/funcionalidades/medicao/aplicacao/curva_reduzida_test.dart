import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/curva_reduzida.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca amostra(int timestampUs, double forcaN) => AmostraForca(
  sequencia: 0,
  timestampUs: timestampUs,
  forcaN: forcaN,
  status: 0,
);

List<(double, double)> pares(List<PontoCurva> pontos) => [
  for (final ponto in pontos) (ponto.tempoS, ponto.forcaN),
];

void main() {
  group('reduzirCurva', () {
    test('mantém todas as amostras quando cabem no limite', () {
      final curva = reduzirCurva([
        amostra(1000000, 10),
        amostra(1500000, 30),
        amostra(2500000, 20),
      ]);

      expect(pares(curva), [(0.0, 10.0), (0.5, 30.0), (1.5, 20.0)]);
    });

    test('guarda a maior força de cada intervalo de tempo', () {
      final forcasN = <double>[1, 5, 2, 8, 3, 4, 0, 9, 1, 7];
      final curva = reduzirCurva([
        for (var indice = 0; indice < forcasN.length; indice++)
          amostra(indice * 1000, forcasN[indice]),
      ], maximoPontos: 4);

      // Quatro intervalos sobre 0 a 9 ms: amostras 0–2, 3–4, 5–6 e 7–9.
      expect(pares(curva), [
        (0.001, 5.0),
        (0.003, 8.0),
        (0.005, 4.0),
        (0.007, 9.0),
      ]);
    });

    test('reduz uma série completa sem perder o pico', () {
      final forcasN = gerarSerieIsometria();
      final curva = reduzirCurva([
        for (var indice = 0; indice < forcasN.length; indice++)
          amostra(indice * 1000, forcasN[indice]),
      ]);
      double maximo(Iterable<double> valores) =>
          valores.reduce((a, b) => a > b ? a : b);

      expect(curva.length, lessThanOrEqualTo(1500));
      expect(curva.length, greaterThan(1400));
      expect(maximo(curva.map((ponto) => ponto.forcaN)), maximo(forcasN));
      expect(curva.last.tempoS, lessThan(92));
    });

    test('devolve lista vazia sem amostras', () {
      expect(reduzirCurva([]), isEmpty);
    });

    test('rejeita limite menor que um ponto', () {
      expect(
        () => reduzirCurva([amostra(0, 1)], maximoPontos: 0),
        throwsArgumentError,
      );
    });
  });
}
