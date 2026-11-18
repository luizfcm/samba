import 'dart:math';

import '../../../nucleo/modelos/amostra_forca.dart';
import 'detector_repeticoes.dart';
import 'metricas_forca.dart';
import 'processador_exercicio.dart';

class RfdJanela {
  const RfdJanela({
    required this.janelaUs,
    required this.rfdNPorS,
    required this.rfdPercentualPorS,
  });

  final int janelaUs;

  /// Nula quando a janela não cabe na repetição.
  final double? rfdNPorS;

  /// Em %Fmáx/s, relativa ao pico da repetição.
  final double? rfdPercentualPorS;
}

class ResultadoRepeticao {
  ResultadoRepeticao({
    required this.inicioS,
    required this.duracaoS,
    required this.picoN,
    required this.instantePicoS,
    required this.impulsoNs,
    required this.inicioContracaoS,
    required List<RfdJanela> rfdJanelas,
    required this.rfdMaxima,
    required this.forcaSustentadaN,
    required this.desvioForcaSustentadaN,
    required this.coeficienteVariacaoPercentual,
  }) : rfdJanelas = List.unmodifiable(rfdJanelas);

  /// Segundos desde a primeira amostra da série, como os demais instantes.
  final double inicioS;
  final double duracaoS;
  final double picoN;
  final double instantePicoS;
  final double impulsoNs;
  final double inicioContracaoS;

  /// Na mesma ordem de [ProcessadorIsometria.janelasRfdUs].
  final List<RfdJanela> rfdJanelas;
  final RfdJanela rfdMaxima;

  /// Nulos quando a repetição é mais curta que a janela de força sustentada.
  final double? forcaSustentadaN;
  final double? desvioForcaSustentadaN;
  final double? coeficienteVariacaoPercentual;
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
  const ProcessadorIsometria({
    this.limiarInicioN = 10,
    this.janelasRfdUs = const [50000, 100000, 200000],
    this.janelaRfdMaximaUs = 20000,
    this.janelaForcaSustentadaUs = 1000000,
  });

  final double limiarInicioN;
  final List<int> janelasRfdUs;
  final int janelaRfdMaximaUs;
  final int janelaForcaSustentadaUs;

  /// O mapa de parâmetros não é usado.
  @override
  ResultadoIsometria processar({
    required List<AmostraForca> amostras,
    required Map<String, double> parametros,
  }) {
    if (!(limiarInicioN >= 0) ||
        janelaRfdMaximaUs <= 0 ||
        janelaForcaSustentadaUs <= 0 ||
        janelasRfdUs.any((janelaUs) => janelaUs <= 0)) {
      throw ArgumentError('Parâmetros da isometria inválidos.');
    }

    final metricas = calcularMetricasForca(amostras);
    final origemUs = amostras.first.timestampUs;
    final repeticoes = <ResultadoRepeticao>[];
    var fimAnterior = 0;
    for (final repeticao in detectarRepeticoes(amostras)) {
      repeticoes.add(
        _processarRepeticao(amostras, repeticao, fimAnterior, origemUs),
      );
      fimAnterior = repeticao.indiceFim;
    }

    return ResultadoIsometria(
      metricas: metricas,
      instantePicoS: _instantePicoS(amostras, metricas, origemUs),
      repeticoes: repeticoes,
    );
  }

  ResultadoRepeticao _processarRepeticao(
    List<AmostraForca> amostras,
    Repeticao repeticao,
    int fimAnterior,
    int origemUs,
  ) {
    final trecho = amostras.sublist(
      repeticao.indiceInicio,
      repeticao.indiceFim,
    );
    final metricas = calcularMetricasForca(trecho);
    final picoN = metricas.forcaMaximaN;
    final indicePico =
        repeticao.indiceInicio +
        trecho.indexWhere((amostra) => amostra.forcaN == picoN);
    final inicio = _inicioContracao(
      amostras,
      fimAnterior,
      repeticao.indiceInicio,
    );
    final inicioUs = amostras[inicio].timestampUs;
    final fimUs = amostras[repeticao.indiceFim - 1].timestampUs;

    RfdJanela rfdJanela(int janelaUs, double? rfdNPorS) => RfdJanela(
      janelaUs: janelaUs,
      rfdNPorS: rfdNPorS,
      rfdPercentualPorS: rfdNPorS == null ? null : rfdNPorS / picoN * 100,
    );

    final sustentada = _forcaSustentada(
      amostras,
      repeticao.indiceInicio,
      repeticao.indiceFim,
    );

    return ResultadoRepeticao(
      inicioS: (trecho.first.timestampUs - origemUs) / 1e6,
      duracaoS: metricas.duracaoS,
      picoN: picoN,
      instantePicoS: _instantePicoS(trecho, metricas, origemUs),
      impulsoNs: metricas.impulsoNs,
      inicioContracaoS: (inicioUs - origemUs) / 1e6,
      rfdJanelas: [
        for (final janelaUs in janelasRfdUs)
          rfdJanela(
            janelaUs,
            inicioUs + janelaUs > fimUs
                ? null
                : _inclinacao(amostras, inicio, janelaUs),
          ),
      ],
      rfdMaxima: rfdJanela(
        janelaRfdMaximaUs,
        _rfdMaxima(amostras, inicio, indicePico),
      ),
      forcaSustentadaN: sustentada?.mediaN,
      desvioForcaSustentadaN: sustentada?.desvioN,
      coeficienteVariacaoPercentual: sustentada?.coeficienteVariacaoPercentual,
    );
  }

  /// Última amostra antes do início detectado com força até a mediana do
  /// repouso anterior mais [limiarInicioN]; sem ela, o próprio início detectado.
  int _inicioContracao(
    List<AmostraForca> amostras,
    int fimAnterior,
    int inicioDetectado,
  ) {
    if (fimAnterior >= inicioDetectado) return inicioDetectado;

    final repousoN = [
      for (var indice = fimAnterior; indice < inicioDetectado; indice++)
        amostras[indice].forcaN,
    ]..sort();
    final meio = repousoN.length ~/ 2;
    final linhaBaseN = repousoN.length.isOdd
        ? repousoN[meio]
        : (repousoN[meio - 1] + repousoN[meio]) / 2;

    for (var indice = inicioDetectado - 1; indice >= fimAnterior; indice--) {
      if (amostras[indice].forcaN <= linhaBaseN + limiarInicioN) return indice;
    }
    return inicioDetectado;
  }

  double? _rfdMaxima(List<AmostraForca> amostras, int inicio, int indicePico) {
    final picoUs = amostras[indicePico].timestampUs;
    double? maximaNPorS;
    for (
      var indice = inicio;
      amostras[indice].timestampUs + janelaRfdMaximaUs <= picoUs;
      indice++
    ) {
      final inclinacao = _inclinacao(amostras, indice, janelaRfdMaximaUs);
      if (maximaNPorS == null || inclinacao > maximaNPorS) {
        maximaNPorS = inclinacao;
      }
    }
    return maximaNPorS;
  }

  ({double mediaN, double desvioN, double? coeficienteVariacaoPercentual})?
  _forcaSustentada(List<AmostraForca> amostras, int inicio, int fim) {
    final fimUs = amostras[fim - 1].timestampUs;
    if (fimUs - amostras[inicio].timestampUs < janelaForcaSustentadaUs) {
      return null;
    }

    var melhorInicio = inicio;
    var melhorFim = inicio;
    var melhorMediaN = double.negativeInfinity;
    var somaN = 0.0;
    var proxima = inicio;
    for (
      var indice = inicio;
      amostras[indice].timestampUs + janelaForcaSustentadaUs <= fimUs;
      indice++
    ) {
      final limiteUs = amostras[indice].timestampUs + janelaForcaSustentadaUs;
      while (proxima < fim && amostras[proxima].timestampUs <= limiteUs) {
        somaN += amostras[proxima].forcaN;
        proxima++;
      }
      final mediaN = somaN / (proxima - indice);
      if (mediaN > melhorMediaN) {
        melhorMediaN = mediaN;
        melhorInicio = indice;
        melhorFim = proxima;
      }
      somaN -= amostras[indice].forcaN;
    }

    final janela = amostras.sublist(melhorInicio, melhorFim);
    final mediaN =
        janela.fold(0.0, (soma, amostra) => soma + amostra.forcaN) /
        janela.length;
    final variancia =
        janela.fold(
          0.0,
          (soma, amostra) =>
              soma + (amostra.forcaN - mediaN) * (amostra.forcaN - mediaN),
        ) /
        janela.length;
    final desvioN = sqrt(variancia);
    return (
      mediaN: mediaN,
      desvioN: desvioN,
      coeficienteVariacaoPercentual: mediaN > 0 ? desvioN / mediaN * 100 : null,
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

/// Inclinação em N/s da amostra [indice] até [janelaUs] depois dela.
double _inclinacao(List<AmostraForca> amostras, int indice, int janelaUs) {
  final inicial = amostras[indice];
  final finalN = _forcaEm(amostras, inicial.timestampUs + janelaUs);
  return (finalN - inicial.forcaN) * 1e6 / janelaUs;
}

/// Interpola linearmente pelo tempo entre as amostras vizinhas; [tempoUs] deve
/// estar dentro da série.
double _forcaEm(List<AmostraForca> amostras, int tempoUs) {
  var baixo = 0;
  var alto = amostras.length - 1;
  while (alto - baixo > 1) {
    final meio = (baixo + alto) ~/ 2;
    if (amostras[meio].timestampUs <= tempoUs) {
      baixo = meio;
    } else {
      alto = meio;
    }
  }
  final anterior = amostras[baixo];
  final seguinte = amostras[alto];
  if (tempoUs <= anterior.timestampUs) return anterior.forcaN;
  if (tempoUs >= seguinte.timestampUs) return seguinte.forcaN;
  final fracao =
      (tempoUs - anterior.timestampUs) /
      (seguinte.timestampUs - anterior.timestampUs);
  return anterior.forcaN + (seguinte.forcaN - anterior.forcaN) * fracao;
}
