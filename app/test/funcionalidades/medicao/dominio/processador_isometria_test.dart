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
