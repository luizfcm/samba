import '../../../nucleo/modelos/amostra_forca.dart';
import 'detector_repeticoes.dart';
import 'metricas_forca.dart';
import 'processador_exercicio.dart';

class ResultadoRepeticao {
  const ResultadoRepeticao({
    required this.inicioS,
    required this.duracaoS,
    required this.picoN,
    required this.instantePicoS,
    required this.impulsoNs,
  });

  /// Segundos desde a primeira amostra da série, como [instantePicoS].
  final double inicioS;
  final double duracaoS;
  final double picoN;
  final double instantePicoS;
  final double impulsoNs;
}

class ResultadoIsometria {
  ResultadoIsometria({
    required this.metricas,
    required this.instantePicoS,
    required List<ResultadoRepeticao> repeticoes,
  }) : repeticoes = List.unmodifiable(repeticoes);

  final MetricasForca metricas;

  /// Segundos desde a primeira amostra; em empate, vale o primeiro instante.
  final double instantePicoS;
  final List<ResultadoRepeticao> repeticoes;

  double? get mediaPicosN {
    if (repeticoes.isEmpty) return null;
    var soma = 0.0;
    for (final repeticao in repeticoes) {
      soma += repeticao.picoN;
    }
    return soma / repeticoes.length;
  }
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
    final origemUs = amostras.first.timestampUs;

    return ResultadoIsometria(
      metricas: metricas,
      instantePicoS: _instantePicoS(amostras, metricas, origemUs),
      repeticoes: [
        for (final repeticao in detectarRepeticoes(amostras))
          _processarRepeticao(
            amostras.sublist(repeticao.indiceInicio, repeticao.indiceFim),
            origemUs,
          ),
      ],
    );
  }

  ResultadoRepeticao _processarRepeticao(
    List<AmostraForca> trecho,
    int origemUs,
  ) {
    final metricas = calcularMetricasForca(trecho);
    return ResultadoRepeticao(
      inicioS: (trecho.first.timestampUs - origemUs) / 1e6,
      duracaoS: metricas.duracaoS,
      picoN: metricas.forcaMaximaN,
      instantePicoS: _instantePicoS(trecho, metricas, origemUs),
      impulsoNs: metricas.impulsoNs,
    );
  }

  double _instantePicoS(
    List<AmostraForca> amostras,
    MetricasForca metricas,
    int origemUs,
  ) {
    final pico = amostras.firstWhere(
      (amostra) => amostra.forcaN == metricas.forcaMaximaN,
    );
    return (pico.timestampUs - origemUs) / 1e6;
  }
}
