import '../../../nucleo/modelos/amostra_forca.dart';
import 'metricas_forca.dart';
import 'processador_exercicio.dart';

class ResultadoIsometria {
  const ResultadoIsometria({
    required this.metricas,
    required this.instantePicoS,
  });

  final MetricasForca metricas;

  /// Segundos desde a primeira amostra; em empate, vale o primeiro instante.
  final double instantePicoS;
}

class ProcessadorIsometria implements ProcessadorExercicio<ResultadoIsometria> {
  const ProcessadorIsometria();

  /// O mapa de parâmetros não é usado.
  @override
  ResultadoIsometria processar({
    required List<AmostraForca> amostras,
    required Map<String, double> parametros,
  }) {
    final metricas = calcularMetricasForca(amostras);
    final pico = amostras.firstWhere(
      (amostra) => amostra.forcaN == metricas.forcaMaximaN,
    );

    return ResultadoIsometria(
      metricas: metricas,
      instantePicoS: (pico.timestampUs - amostras.first.timestampUs) / 1e6,
    );
  }
}
