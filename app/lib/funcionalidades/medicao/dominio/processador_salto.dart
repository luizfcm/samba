import 'dart:math';

import '../../../nucleo/modelos/amostra_forca.dart';
import 'processador_exercicio.dart';
import 'validar_timestamps.dart';

const _gravidadeMs2 = 9.81;

class PontoSalto {
  const PontoSalto({
    required this.tempoS,
    required this.forcaN,
    required this.aceleracaoMs2,
    required this.velocidadeMs,
    required this.potenciaW,
  });

  /// Segundos desde a primeira amostra da série.
  final double tempoS;
  final double forcaN;
  final double aceleracaoMs2;
  final double velocidadeMs;
  final double potenciaW;
}

class ResultadoSaltoIndividual {
  ResultadoSaltoIndividual({
    required this.inicioS,
    required this.decolagemS,
    required this.aterrissagemS,
    required this.tempoVooS,
    required this.velocidadeDecolagemMs,
    required this.potenciaMaximaW,
    required this.forcaMaximaN,
    required this.velocidadeMinimaMs,
    required this.tempoFrenagemS,
    required this.impulsoExcentricoNs,
    required this.rfdFrenagemNPorS,
    required this.impulsoConcentricoNs,
    required this.forcaMaximaConcentricaN,
    required this.potenciaMediaConcentricaW,
    required List<PontoSalto> pontos,
  }) : pontos = List.unmodifiable(pontos);

  final double inicioS;
  final double decolagemS;
  final double aterrissagemS;
  final double tempoVooS;
  final double velocidadeDecolagemMs;
  final double potenciaMaximaW;
  final double forcaMaximaN;

  /// Nulos sem contramovimento: a velocidade não fica negativa ou não volta a
  /// zero antes da decolagem.
  final double? velocidadeMinimaMs;
  final double? tempoFrenagemS;
  final double? impulsoExcentricoNs;
  final double? rfdFrenagemNPorS;

  final double impulsoConcentricoNs;
  final double forcaMaximaConcentricaN;

  /// Nula se a propulsão tiver uma amostra só.
  final double? potenciaMediaConcentricaW;

  /// Do início do salto até a última amostra antes da decolagem.
  final List<PontoSalto> pontos;

  double get alturaVooM => _gravidadeMs2 * tempoVooS * tempoVooS / 8;
  double get alturaVelocidadeM =>
      velocidadeDecolagemMs * velocidadeDecolagemMs / (2 * _gravidadeMs2);
}

class ResultadoSalto {
  ResultadoSalto({
    required this.massaKg,
    required List<ResultadoSaltoIndividual> saltos,
  }) : saltos = List.unmodifiable(saltos);

  /// Nula quando não há repouso com a pessoa parada; então não há saltos.
  final double? massaKg;
  final List<ResultadoSaltoIndividual> saltos;

  double? get alturaMediaM {
    if (saltos.isEmpty) return null;
    var soma = 0.0;
    for (final salto in saltos) {
      soma += salto.alturaVooM;
    }
    return soma / saltos.length;
  }

  /// Decréscimo percentual em relação a repetir sempre a melhor altura pelo
  /// voo; nulo com menos de dois saltos.
  double? get indiceFadigaPercentual {
    if (saltos.length < 2) return null;
    var somaM = 0.0;
    for (final salto in saltos) {
      somaM += salto.alturaVooM;
    }
    return 100 * (1 - somaM / (melhorSalto!.alturaVooM * saltos.length));
  }

  /// Em empate, vale o primeiro salto.
  ResultadoSaltoIndividual? get melhorSalto {
    if (saltos.isEmpty) return null;
    var melhor = saltos.first;
    for (final salto in saltos) {
      if (salto.alturaVooM > melhor.alturaVooM) melhor = salto;
    }
    return melhor;
  }
}

class ProcessadorSalto implements ProcessadorExercicio<ResultadoSalto> {
  const ProcessadorSalto({
    this.duracaoRepousoInicialUs = 1000000,
    this.forcaMinimaRepousoN = 200,
    this.fracaoVoo = 0.1,
    this.duracaoMinimaVooUs = 100000,
    this.duracaoMaximaVooUs = 1000000,
    this.fracaoRepouso = 0.05,
    this.duracaoMinimaRepousoUs = 100000,
  });

  final int duracaoRepousoInicialUs;

  /// Média mínima do repouso, para não confundir a plataforma vazia com a
  /// pessoa parada.
  final double forcaMinimaRepousoN;
  final double fracaoVoo;
  final int duracaoMinimaVooUs;

  /// Trechos mais longos sem força são a pessoa fora da plataforma, não voo.
  final int duracaoMaximaVooUs;
  final double fracaoRepouso;
  final int duracaoMinimaRepousoUs;

  /// A massa vem do primeiro repouso estável; sem ele, o resultado vem vazio.
  /// Saltos antes do repouso ou sem repouso antes da decolagem são ignorados.
  /// O mapa de parâmetros não é usado.
  @override
  ResultadoSalto processar({
    required List<AmostraForca> amostras,
    required Map<String, double> parametros,
  }) {
    validarTimestamps(amostras);
    final repouso = _estimarRepouso(amostras);
    if (repouso == null) return ResultadoSalto(massaKg: null, saltos: const []);
    final massaKg = repouso.massaKg;
    final pesoN = massaKg * _gravidadeMs2;
    final saltos = <ResultadoSaltoIndividual>[];
    var limite = repouso.fim;
    for (final (decolagem, aterrissagem) in _encontrarVoos(amostras, pesoN)) {
      if (decolagem < limite) continue;
      final inicio = _encontrarInicio(amostras, pesoN, limite, decolagem);
      limite = aterrissagem;
      if (inicio != null) {
        saltos.add(
          _processarSalto(amostras, massaKg, inicio, decolagem, aterrissagem),
        );
      }
    }
    return ResultadoSalto(massaKg: massaKg, saltos: saltos);
  }

  /// Primeira janela de [duracaoRepousoInicialUs] com média acima de
  /// [forcaMinimaRepousoN] e desvio abaixo de 2% da média; [fim] é exclusivo.
  /// Nula se a série for mais curta que a janela ou não tiver esse repouso.
  ({double massaKg, int fim})? _estimarRepouso(List<AmostraForca> amostras) {
    if (amostras.isEmpty ||
        amostras.last.timestampUs - amostras.first.timestampUs <
            duracaoRepousoInicialUs) {
      return null;
    }

    var somaN = 0.0;
    var somaQuadrados = 0.0;
    var fim = 0;
    for (
      var inicio = 0;
      amostras.last.timestampUs - amostras[inicio].timestampUs >=
          duracaoRepousoInicialUs;
      inicio++
    ) {
      final limiteUs = amostras[inicio].timestampUs + duracaoRepousoInicialUs;
      while (amostras[fim].timestampUs < limiteUs) {
        final forcaN = amostras[fim].forcaN;
        somaN += forcaN;
        somaQuadrados += forcaN * forcaN;
        fim++;
      }
      final quantidade = fim - inicio;
      final mediaN = somaN / quantidade;
      final desvioN = sqrt(
        max(0.0, somaQuadrados / quantidade - mediaN * mediaN),
      );
      if (mediaN > forcaMinimaRepousoN && desvioN < 0.02 * mediaN) {
        var somaExataN = 0.0;
        for (var indice = inicio; indice < fim; indice++) {
          somaExataN += amostras[indice].forcaN;
        }
        return (massaKg: somaExataN / quantidade / _gravidadeMs2, fim: fim);
      }
      final saindoN = amostras[inicio].forcaN;
      somaN -= saindoN;
      somaQuadrados -= saindoN * saindoN;
    }
    return null;
  }

  /// Pares (decolagem, aterrissagem); um voo sem aterrissagem é ignorado.
  List<(int, int)> _encontrarVoos(List<AmostraForca> amostras, double pesoN) {
    final limiarN = fracaoVoo * pesoN;
    final voos = <(int, int)>[];
    int? decolagem;
    for (var indice = 0; indice < amostras.length; indice++) {
      if (amostras[indice].forcaN < limiarN) {
        decolagem ??= indice;
      } else if (decolagem != null) {
        final duracaoUs =
            amostras[indice].timestampUs - amostras[decolagem].timestampUs;
        if (duracaoUs >= duracaoMinimaVooUs &&
            duracaoUs <= duracaoMaximaVooUs) {
          voos.add((decolagem, indice));
        }
        decolagem = null;
      }
    }
    return voos;
  }

  int? _encontrarInicio(
    List<AmostraForca> amostras,
    double pesoN,
    int limite,
    int decolagem,
  ) {
    final toleranciaN = fracaoRepouso * pesoN;
    int? inicioTrecho;
    int? fimRepouso;
    for (var indice = limite; indice < decolagem; indice++) {
      if ((amostras[indice].forcaN - pesoN).abs() <= toleranciaN) {
        inicioTrecho ??= indice;
        final duracaoUs =
            amostras[indice].timestampUs - amostras[inicioTrecho].timestampUs;
        if (duracaoUs >= duracaoMinimaRepousoUs) fimRepouso = indice;
      } else {
        inicioTrecho = null;
      }
    }
    return fimRepouso;
  }

  ResultadoSaltoIndividual _processarSalto(
    List<AmostraForca> amostras,
    double massaKg,
    int inicio,
    int decolagem,
    int aterrissagem,
  ) {
    final origemUs = amostras.first.timestampUs;
    double segundos(int indice) =>
        (amostras[indice].timestampUs - origemUs) / 1e6;

    final pontos = <PontoSalto>[];
    var velocidadeMs = 0.0;
    var aceleracaoAnteriorMs2 = 0.0;
    var potenciaMaximaW = double.negativeInfinity;
    var forcaMaximaN = double.negativeInfinity;
    for (var indice = inicio; indice < decolagem; indice++) {
      final forcaN = amostras[indice].forcaN;
      final aceleracaoMs2 = (forcaN - massaKg * _gravidadeMs2) / massaKg;
      if (indice > inicio) {
        final intervaloS =
            (amostras[indice].timestampUs - amostras[indice - 1].timestampUs) /
            1e6;
        velocidadeMs +=
            (aceleracaoAnteriorMs2 + aceleracaoMs2) / 2 * intervaloS;
      }
      final potenciaW = forcaN * velocidadeMs;
      pontos.add(
        PontoSalto(
          tempoS: segundos(indice),
          forcaN: forcaN,
          aceleracaoMs2: aceleracaoMs2,
          velocidadeMs: velocidadeMs,
          potenciaW: potenciaW,
        ),
      );
      aceleracaoAnteriorMs2 = aceleracaoMs2;
      potenciaMaximaW = max(potenciaMaximaW, potenciaW);
      forcaMaximaN = max(forcaMaximaN, forcaN);
    }

    final pesoN = massaKg * _gravidadeMs2;
    double integrar(int de, int ate, double Function(PontoSalto) valor) {
      var integral = 0.0;
      for (var indice = de + 1; indice <= ate; indice++) {
        final anterior = pontos[indice - 1];
        final atual = pontos[indice];
        integral +=
            (valor(anterior) + valor(atual)) /
            2 *
            (atual.tempoS - anterior.tempoS);
      }
      return integral;
    }

    var indiceMinimo = 0;
    for (var indice = 1; indice < pontos.length; indice++) {
      if (pontos[indice].velocidadeMs < pontos[indiceMinimo].velocidadeMs) {
        indiceMinimo = indice;
      }
    }
    int? pontoMaisBaixo;
    if (pontos[indiceMinimo].velocidadeMs < 0) {
      for (var indice = indiceMinimo + 1; indice < pontos.length; indice++) {
        if (pontos[indice].velocidadeMs >= 0) {
          pontoMaisBaixo = indice;
          break;
        }
      }
    }

    double? tempoFrenagemS;
    double? impulsoExcentricoNs;
    double? rfdFrenagemNPorS;
    if (pontoMaisBaixo != null) {
      final inicioFrenagem = pontos[indiceMinimo];
      final fimFrenagem = pontos[pontoMaisBaixo];
      tempoFrenagemS = fimFrenagem.tempoS - inicioFrenagem.tempoS;
      impulsoExcentricoNs = integrar(
        indiceMinimo,
        pontoMaisBaixo,
        (ponto) => ponto.forcaN - pesoN,
      );
      rfdFrenagemNPorS =
          (fimFrenagem.forcaN - inicioFrenagem.forcaN) / tempoFrenagemS;
    }

    final inicioPropulsao = pontoMaisBaixo ?? 0;
    final fimPropulsao = pontos.length - 1;
    final duracaoPropulsaoS =
        pontos[fimPropulsao].tempoS - pontos[inicioPropulsao].tempoS;
    var forcaMaximaConcentricaN = double.negativeInfinity;
    for (var indice = inicioPropulsao; indice <= fimPropulsao; indice++) {
      forcaMaximaConcentricaN = max(
        forcaMaximaConcentricaN,
        pontos[indice].forcaN,
      );
    }

    return ResultadoSaltoIndividual(
      inicioS: segundos(inicio),
      decolagemS: segundos(decolagem),
      aterrissagemS: segundos(aterrissagem),
      tempoVooS:
          (amostras[aterrissagem].timestampUs -
              amostras[decolagem].timestampUs) /
          1e6,
      velocidadeDecolagemMs: velocidadeMs,
      potenciaMaximaW: potenciaMaximaW,
      forcaMaximaN: forcaMaximaN,
      velocidadeMinimaMs: pontoMaisBaixo == null
          ? null
          : pontos[indiceMinimo].velocidadeMs,
      tempoFrenagemS: tempoFrenagemS,
      impulsoExcentricoNs: impulsoExcentricoNs,
      rfdFrenagemNPorS: rfdFrenagemNPorS,
      impulsoConcentricoNs: integrar(
        inicioPropulsao,
        fimPropulsao,
        (ponto) => ponto.forcaN - pesoN,
      ),
      forcaMaximaConcentricaN: forcaMaximaConcentricaN,
      potenciaMediaConcentricaW: duracaoPropulsaoS > 0
          ? integrar(
                  inicioPropulsao,
                  fimPropulsao,
                  (ponto) => ponto.potenciaW,
                ) /
                duracaoPropulsaoS
          : null,
      pontos: pontos,
    );
  }
}
