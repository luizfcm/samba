import '../../../nucleo/aquisicao/series_simuladas.dart';
import '../dominio/exercicio.dart';

/// Com o sinal do equipamento: o salto comprime a célula e chega negativo. O
/// terra não tem série simulada enquanto o modelo mecânico não for definido.
List<double> serieSimulada(Exercicio exercicio) => switch (exercicio) {
  Exercicio.salto => [for (final forcaN in gerarSerieSalto()) 0.0 - forcaN],
  Exercicio.remada || Exercicio.extensora => gerarSerieIsometria(),
  Exercicio.terra => throw ArgumentError('Não há série simulada para o terra.'),
};
