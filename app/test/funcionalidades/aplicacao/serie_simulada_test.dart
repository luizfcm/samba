import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/serie_simulada.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';

void main() {
  group('serieSimulada', () {
    test('usa a série de salto com força negativa no salto', () {
      final serie = serieSimulada(Exercicio.salto);

      expect(serie, [for (final forcaN in gerarSerieSalto()) -forcaN]);
      expect(serie.where((forcaN) => forcaN == 0), isNotEmpty);
      expect(serie.any((forcaN) => forcaN == 0 && forcaN.isNegative), isFalse);
    });

    test('usa a série de isometria na remada e na extensora', () {
      expect(serieSimulada(Exercicio.remada), gerarSerieIsometria());
      expect(serieSimulada(Exercicio.extensora), gerarSerieIsometria());
    });

    test('rejeita o terra', () {
      expect(() => serieSimulada(Exercicio.terra), throwsArgumentError);
    });
  });
}
