import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/frequencia_media.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca amostra(int timestampUs) =>
    AmostraForca(sequencia: 0, timestampUs: timestampUs, forcaN: 0, status: 0);

void main() {
  group('frequenciaMediaHz', () {
    test('calcula a frequência pelos timestamps', () {
      expect(
        frequenciaMediaHz([
          for (var indice = 0; indice < 100; indice++) amostra(indice * 1000),
        ]),
        1000,
      );
    });

    test('arredonda a média de intervalos irregulares', () {
      // Dois intervalos em 3 ms: 666,7 Hz.
      expect(
        frequenciaMediaHz([amostra(0), amostra(1000), amostra(3000)]),
        667,
      );
    });

    test('devolve zero com menos de duas amostras', () {
      expect(frequenciaMediaHz([]), 0);
      expect(frequenciaMediaHz([amostra(0)]), 0);
    });
  });
}
