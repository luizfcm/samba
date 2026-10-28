import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/detector_repeticoes.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

const gravidadeMs2 = 9.81;

List<AmostraForca> amostras(List<double> forcasN) => [
  for (var indice = 0; indice < forcasN.length; indice++)
    AmostraForca(
      sequencia: indice,
      timestampUs: indice * 1000,
      forcaN: forcasN[indice],
      status: 0,
    ),
];

void main() {
  group('gerarSerieIsometria', () {
    test('gera uma força por milissegundo durante toda a série', () {
      // 2 s + 10 × (0,5 + 3 + 0,5 + 5) s = 92 s.
      expect(gerarSerieIsometria(), hasLength(92000));
      // 2 s + 3 × 9 s = 29 s.
      expect(gerarSerieIsometria(repeticoes: 3), hasLength(29000));
    });

    test('tem dez repetições detectáveis com picos decrescentes', () {
      final serie = amostras(gerarSerieIsometria());
      final repeticoes = detectarRepeticoes(serie);

      expect(repeticoes, hasLength(10));
      for (var indice = 0; indice < repeticoes.length; indice++) {
        final trecho = serie.sublist(
          repeticoes[indice].indiceInicio,
          repeticoes[indice].indiceFim,
        );
        final picoN = trecho
            .map((amostra) => amostra.forcaN)
            .reduce((a, b) => a > b ? a : b);

        expect(picoN, closeTo(400 * (1 - 0.02 * indice), 2));
      }
    });

    test('a mesma semente gera a mesma série', () {
      expect(gerarSerieIsometria(), gerarSerieIsometria());
      expect(gerarSerieIsometria(semente: 2), isNot(gerarSerieIsometria()));
    });
  });

  group('gerarSerieSalto', () {
    test('gera uma força por milissegundo durante toda a série', () {
      // 2 s + 10 × (0,3 + 0,3 + 0,4 + 0,3 + 5) s = 65 s.
      expect(gerarSerieSalto(), hasLength(65000));
      // 2 s + 2 × (0,3 + 0,3 + 0,5 + 0,3 + 5) s = 14,8 s.
      expect(gerarSerieSalto(saltos: 2, tempoVooS: 0.5), hasLength(14800));
    });

    test('a força média do repouso inicial é o peso', () {
      final repouso = gerarSerieSalto().sublist(0, 2000);
      final mediaN = repouso.reduce((a, b) => a + b) / repouso.length;

      expect(mediaN, closeTo(75 * gravidadeMs2, 0.2));
    });

    for (final tempoVooS in [0.4, 0.5]) {
      test('o voo dura $tempoVooS s com força zero', () {
        final serie = gerarSerieSalto(tempoVooS: tempoVooS);
        final inicioVoo = serie.indexOf(0);
        var fimVoo = inicioVoo;
        while (serie[fimVoo] == 0) {
          fimVoo++;
        }

        // Repouso de 2 s, depois descida e propulsão de 0,3 s cada.
        expect(inicioVoo, 2600);
        expect((fimVoo - inicioVoo) / 1000, tempoVooS);
      });
    }

    test('descida e propulsão levam à velocidade de decolagem', () {
      const massaKg = 75.0;
      final serie = gerarSerieSalto(saltos: 1, ruidoN: 0);
      var velocidadeMs = 0.0;
      for (var indice = 2000; indice < 2600; indice++) {
        velocidadeMs +=
            (serie[indice] - massaKg * gravidadeMs2) / massaKg / 1000;
      }

      // v = g × tempoVooS / 2 = 9,81 × 0,4 / 2.
      const decolagemMs = gravidadeMs2 * 0.4 / 2;
      expect(velocidadeMs, closeTo(decolagemMs, decolagemMs * 0.01));
    });

    test('a mesma semente gera a mesma série', () {
      expect(gerarSerieSalto(), gerarSerieSalto());
      expect(gerarSerieSalto(semente: 2), isNot(gerarSerieSalto()));
    });
  });
}
