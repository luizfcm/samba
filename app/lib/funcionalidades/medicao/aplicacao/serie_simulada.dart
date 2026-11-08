import '../../../nucleo/aquisicao/series_simuladas.dart';
import '../dominio/exercicio.dart';

/// O terra não tem série simulada enquanto o modelo mecânico não for definido.
List<double> serieSimulada(Exercicio exercicio) => switch (exercicio) {
  Exercicio.salto => gerarSerieSalto(),
  Exercicio.remada || Exercicio.extensora => gerarSerieIsometria(),
  Exercicio.terra => throw ArgumentError('Não há série simulada para o terra.'),
};
