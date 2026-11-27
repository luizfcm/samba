import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/detector_repeticoes.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca amostra(int timestampUs, double forcaN) => AmostraForca(
  sequencia: 0,
  timestampUs: timestampUs,
  forcaN: forcaN,
  status: 0,
);

List<AmostraForca> serie(List<double> forcas) => [
  for (var indice = 0; indice < forcas.length; indice++)
    amostra(1000000 + indice * 10000, forcas[indice]),
];

List<double> repouso(int quantidade) => List.filled(quantidade, 0);

List<double> subida(double picoN) => [
  for (var passo = 1; passo <= 10; passo++) picoN * passo / 10,
];

List<double> plato(double picoN, int quantidade) =>
    List.filled(quantidade, picoN);

List<double> descida(double picoN) => [
  for (var passo = 1; passo <= 10; passo++) picoN * (10 - passo) / 10,
];

List<double> trapezio(double picoN) => [
  ...subida(picoN),
  ...plato(picoN, 30),
  ...descida(picoN),
];

List<AmostraForca> serieMilissegundos(List<double> forcasN) => [
  for (var indice = 0; indice < forcasN.length; indice++)
    amostra(indice * 1000, forcasN[indice]),
];

List<double> serieDescansoCurto() {
  const preCargaN = 60.0;
  const amplitudeN = 340.0;
  return [
    ...List.filled(2000, preCargaN),
    for (var repeticao = 0; repeticao < 10; repeticao++) ...[
      for (var indice = 0; indice < 500; indice++)
        preCargaN + amplitudeN * indice / 500,
      ...List.filled(3000, preCargaN + amplitudeN),
      for (var indice = 0; indice < 500; indice++)
        preCargaN + amplitudeN * (500 - indice) / 500,
      ...List.filled(1500, preCargaN),
    ],
  ];
}

List<(int, int)> intervalos(List<Repeticao> repeticoes) => [
  for (final repeticao in repeticoes)
    (repeticao.indiceInicio, repeticao.indiceFim),
];

void main() {
  group('detectarRepeticoes', () {
    test('detecta três contrações em forma de trapézio', () {
      final amostras = serie([
        ...repouso(20),
        ...trapezio(100),
        ...repouso(20),
        ...trapezio(80),
        ...repouso(20),
        ...trapezio(90),
        ...repouso(20),
      ]);

      // Limiares de 20 N e 10 N. Cada trapézio ocupa 50 amostras, seguidas
      // de 20 em repouso: começa na subida em 20, 24 e 27 N e termina na
      // descida em 0, 8 e 9 N.
      expect(intervalos(detectarRepeticoes(amostras)), [
        (21, 69),
        (92, 138),
        (162, 208),
      ]);
    });

    test('ignora picos curtos de ruído', () {
      final amostras = serie([
        ...repouso(10),
        ...trapezio(100),
        ...repouso(10),
        60,
        ...repouso(10),
        50,
        50,
        50,
        ...repouso(10),
      ]);

      expect(intervalos(detectarRepeticoes(amostras)), [(11, 59)]);
    });

    test('não cria repetições extras com força oscilando no limiar', () {
      final amostras = serie([
        ...repouso(10),
        ...[18, 22, 17, 23, 19, 25],
        ...plato(100, 40),
        ...[25, 15, 22, 12, 24, 14],
        ...repouso(10),
      ]);

      // Começa em 22 N e só termina no repouso: oscilar entre 12 e 25 N não
      // fica abaixo de 10 N.
      expect(intervalos(detectarRepeticoes(amostras)), [(11, 62)]);
    });

    test('estende até a última amostra a contração não encerrada', () {
      final amostras = serie([
        ...repouso(10),
        ...trapezio(100),
        ...repouso(10),
        ...subida(100),
        ...plato(100, 30),
      ]);

      expect(intervalos(detectarRepeticoes(amostras)), [(11, 59), (71, 110)]);
    });

    test('mede as repetições a partir da linha de base da pré-carga', () {
      final amostras = serieMilissegundos([
        for (final forcaN in gerarSerieIsometria(picoN: 340, ruidoN: 0))
          60 + forcaN,
      ]);

      // Linha de base de 60 N e pico de 400 N: limiares de 128 N e 94 N. Sem
      // a linha de base, o limiar de fim seria 40 N, abaixo da pré-carga.
      expect(detectarRepeticoes(amostras), hasLength(10));
    });

    test('encontra a linha de base com descanso curto', () {
      final amostras = serieMilissegundos(serieDescansoCurto());

      // 40 s de contração em 57 s de série: 70%. O 10º percentil fica na
      // pré-carga de 60 N; a mediana cairia no platô de 400 N, igual ao pico.
      expect(detectarRepeticoes(amostras), hasLength(10));
      expect(detectarRepeticoes(amostras, percentilLinhaBase: 0.5), isEmpty);
    });

    test('devolve lista vazia sem força positiva', () {
      expect(detectarRepeticoes([]), isEmpty);
      expect(detectarRepeticoes(serie(repouso(50))), isEmpty);
      expect(detectarRepeticoes(serie(List.filled(50, -20))), isEmpty);
    });

    test('rejeita frações inválidas', () {
      final amostras = serie(trapezio(100));

      for (final (inicio, fim) in [
        (0.2, 0.2),
        (0.1, 0.2),
        (0.0, 0.1),
        (1.5, 0.1),
        (0.2, 0.0),
        (0.2, -0.1),
        (double.nan, 0.1),
      ]) {
        expect(
          () => detectarRepeticoes(
            amostras,
            fracaoInicio: inicio,
            fracaoFim: fim,
          ),
          throwsArgumentError,
          reason: 'início $inicio, fim $fim',
        );
      }
    });

    test('rejeita percentil da linha de base fora de [0, 1)', () {
      final amostras = serie(trapezio(100));

      for (final percentil in [-0.1, 1.0, double.nan]) {
        expect(
          () => detectarRepeticoes(amostras, percentilLinhaBase: percentil),
          throwsArgumentError,
          reason: 'percentil $percentil',
        );
      }
    });

    test('rejeita timestamps que não sejam estritamente crescentes', () {
      expect(
        () => detectarRepeticoes([amostra(100, 10), amostra(100, 20)]),
        throwsArgumentError,
      );
      expect(
        () => detectarRepeticoes([
          amostra(0, 10),
          amostra(200, 20),
          amostra(100, 30),
        ]),
        throwsArgumentError,
      );
    });
  });
}
