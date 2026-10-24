import 'dart:math';

import '../../../nucleo/modelos/amostra_forca.dart';
import 'processador_exercicio.dart';

const _gravidadeMs2 = 9.81;

class PontoSalto {
  const PontoSalto({
    required this.tempoS,
    required this.aceleracaoMs2,
    required this.velocidadeMs,
    required this.potenciaW,
  });

  /// Segundos desde a primeira amostra da série.
  final double tempoS;
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
    required List<PontoSalto> pontos,
  }) : pontos = List.unmodifiable(pontos);

  final double inicioS;
  final double decolagemS;
  final double aterrissagemS;
  final double tempoVooS;
  final double velocidadeDecolagemMs;
  final double potenciaMaximaW;
  final double forcaMaximaN;

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

  final double massaKg;
  final List<ResultadoSaltoIndividual> saltos;

  double? get alturaMediaM {
    if (saltos.isEmpty) return null;
    var soma = 0.0;
    for (final salto in saltos) {
      soma += salto.alturaVooM;
    }
    return soma / saltos.length;
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
    this.fracaoVoo = 0.1,
    this.duracaoMinimaVooUs = 100000,
    this.fracaoRepouso = 0.05,
    this.duracaoMinimaRepousoUs = 100000,
  });

  final int duracaoRepousoInicialUs;
  final double fracaoVoo;
  final int duracaoMinimaVooUs;
  final double fracaoRepouso;
  final int duracaoMinimaRepousoUs;

  /// A série precisa começar com a pessoa parada; saltos sem repouso antes da
  /// decolagem são ignorados. O mapa de parâmetros não é usado.
  @override
  ResultadoSalto processar({
    required List<AmostraForca> amostras,
    required Map<String, double> parametros,
  }) {
    for (var indice = 1; indice < amostras.length; indice++) {
      if (amostras[indice].timestampUs <= amostras[indice - 1].timestampUs) {
        throw ArgumentError(
          'Os timestamps das amostras devem ser estritamente crescentes '
          '(índice $indice).',
        );
      }
    }

    final massaKg = _calcularMassaKg(amostras);
    final pesoN = massaKg * _gravidadeMs2;
    final saltos = <ResultadoSaltoIndividual>[];
    var limite = 0;
    for (final (decolagem, aterrissagem) in _encontrarVoos(amostras, pesoN)) {
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

  double _calcularMassaKg(List<AmostraForca> amostras) {
    if (amostras.isEmpty ||
        amostras.last.timestampUs - amostras.first.timestampUs <
            duracaoRepousoInicialUs) {
      throw ArgumentError('A série é mais curta que o repouso inicial.');
    }

    final origemUs = amostras.first.timestampUs;
    final forcasN = amostras
        .takeWhile(
          (amostra) => amostra.timestampUs - origemUs < duracaoRepousoInicialUs,
        )
        .map((amostra) => amostra.forcaN)
        .toList();
    final mediaN = forcasN.reduce((a, b) => a + b) / forcasN.length;
    var somaQuadrados = 0.0;
    for (final forcaN in forcasN) {
      somaQuadrados += (forcaN - mediaN) * (forcaN - mediaN);
    }
    final desvioN = sqrt(somaQuadrados / forcasN.length);

    if (mediaN <= 0 || desvioN > 0.02 * mediaN) {
      throw ArgumentError('A série precisa começar com a pessoa parada.');
    }
    return mediaN / _gravidadeMs2;
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
        if (duracaoUs >= duracaoMinimaVooUs) voos.add((decolagem, indice));
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
          aceleracaoMs2: aceleracaoMs2,
          velocidadeMs: velocidadeMs,
          potenciaW: potenciaW,
        ),
      );
      aceleracaoAnteriorMs2 = aceleracaoMs2;
      potenciaMaximaW = max(potenciaMaximaW, potenciaW);
      forcaMaximaN = max(forcaMaximaN, forcaN);
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
      pontos: pontos,
    );
  }
}
