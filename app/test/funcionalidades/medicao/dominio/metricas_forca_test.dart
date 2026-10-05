import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/metricas_forca.dart';

AmostraForca amostra(int timestampUs, double forcaN) => AmostraForca(
  sequencia: 0,
  timestampUs: timestampUs,
  forcaN: forcaN,
  status: 0,
);

void main() {
  group('calcularMetricasForca', () {
    // Intervalos de 0,5 s e 1 s, com origem temporal diferente de zero.
    final amostras = [
      amostra(1000000, 10),
      amostra(1500000, 30),
      amostra(2500000, 20),
    ];

    test('calcula a força máxima', () {
      expect(calcularMetricasForca(amostras).forcaMaximaN, 30);
    });

    test('calcula a média aritmética da força', () {
      expect(calcularMetricasForca(amostras).forcaMediaN, 20);
    });

    test('calcula a duração em segundos', () {
      expect(calcularMetricasForca(amostras).duracaoS, 1.5);
    });

    test('integra o impulso com os intervalos medidos', () {
      // (10 + 30) / 2 * 0.5 + (30 + 20) / 2 * 1 = 35 N.s.
      expect(calcularMetricasForca(amostras).impulsoNs, closeTo(35, 1e-9));
    });

    test('aceita duas amostras e duração fracionária', () {
      final metricas = calcularMetricasForca([
        amostra(2000000, 12),
        amostra(2250000, 12),
      ]);

      expect(metricas.forcaMaximaN, 12);
      expect(metricas.forcaMediaN, 12);
      expect(metricas.duracaoS, 0.25);
      expect(metricas.impulsoNs, closeTo(3, 1e-9));
    });

    test('preserva o sinal das métricas para forças negativas', () {
      final metricas = calcularMetricasForca([
        amostra(0, -30),
        amostra(500000, -10),
      ]);

      expect(metricas.forcaMaximaN, -10);
      expect(metricas.forcaMediaN, -20);
      expect(metricas.duracaoS, 0.5);
      expect(metricas.impulsoNs, closeTo(-10, 1e-9));
    });

    test('rejeita lista vazia', () {
      expect(() => calcularMetricasForca([]), throwsArgumentError);
    });

    test('rejeita uma única amostra', () {
      expect(
        () => calcularMetricasForca([amostra(0, 10)]),
        throwsArgumentError,
      );
    });

    test('rejeita timestamps repetidos', () {
      expect(
        () => calcularMetricasForca([amostra(100, 10), amostra(100, 20)]),
        throwsArgumentError,
      );
    });

    test('rejeita timestamps decrescentes', () {
      expect(
        () => calcularMetricasForca([amostra(200, 10), amostra(100, 20)]),
        throwsArgumentError,
      );
    });

    test('rejeita amostra fora de ordem mesmo com duração total positiva', () {
      expect(
        () => calcularMetricasForca([
          amostra(0, 10),
          amostra(200, 20),
          amostra(100, 30),
          amostra(300, 40),
        ]),
        throwsArgumentError,
      );
    });
  });
}
