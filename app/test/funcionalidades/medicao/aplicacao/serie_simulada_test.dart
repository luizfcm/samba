import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/serie_simulada.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';

void main() {
  group('serieSimulada', () {
    test('usa a série de salto no salto', () {
      expect(serieSimulada(Exercicio.salto), gerarSerieSalto());
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
