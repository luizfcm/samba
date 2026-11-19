import '../../../nucleo/modelos/amostra_forca.dart';
import '../dominio/exercicio.dart';
import '../dominio/processador_isometria.dart';
import '../dominio/processador_salto.dart';
import '../dominio/sessao_medicao.dart';

sealed class ResumoSessao {
  const ResumoSessao();
}

class ResumoIsometria extends ResumoSessao {
  const ResumoIsometria({
    required this.maiorPicoN,
    required this.mediaPicosN,
    required this.repeticoes,
    this.rfdMaximaNPorS,
    this.rfdMaximaPercentualPorS,
    this.forcaSustentadaN,
    this.coeficienteVariacaoPercentual,
  });

  final double maiorPicoN;
  final double? mediaPicosN;
  final int repeticoes;

  /// Da repetição de maior pico; nulos sem repetições ou sem valor nela.
  final double? rfdMaximaNPorS;
  final double? rfdMaximaPercentualPorS;
  final double? forcaSustentadaN;
  final double? coeficienteVariacaoPercentual;
}

class ResumoSalto extends ResumoSessao {
  const ResumoSalto({
    required this.melhorAlturaM,
    required this.alturaMediaM,
    required this.saltos,
    required this.massaKg,
    this.indiceFadigaPercentual,
    this.potenciaMediaConcentricaW,
    this.impulsoConcentricoNs,
    this.tempoFrenagemS,
    this.rfdFrenagemNPorS,
  });

  /// Altura pelo tempo de voo; nula quando não há saltos.
  final double? melhorAlturaM;
  final double? alturaMediaM;
  final int saltos;
  final double massaKg;
  final double? indiceFadigaPercentual;

  /// Do melhor salto; nulos sem saltos ou sem valor nele.
  final double? potenciaMediaConcentricaW;
  final double? impulsoConcentricoNs;
  final double? tempoFrenagemS;
  final double? rfdFrenagemNPorS;
}

class ResumoNaoProcessado extends ResumoSessao {
  const ResumoNaoProcessado(this.motivo);

  final String motivo;
}

/// Uma série que o processador rejeita vira [ResumoNaoProcessado], sem exceção.
ResumoSessao resumirSessao(SessaoMedicao sessao) {
  try {
    return switch (sessao.exercicio) {
      Exercicio.remada ||
      Exercicio.extensora => _resumirIsometria(sessao.amostras),
      Exercicio.salto => _resumirSalto(sessao.amostras),
      Exercicio.terra => const ResumoNaoProcessado(
        'Não há processamento para o terra.',
      ),
    };
  } on ArgumentError catch (erro) {
    return ResumoNaoProcessado('${erro.message}');
  }
}

ResumoIsometria _resumirIsometria(List<AmostraForca> amostras) {
  final resultado = const ProcessadorIsometria().processar(
    amostras: amostras,
    parametros: const {},
  );
  ResultadoRepeticao? melhor;
  for (final repeticao in resultado.repeticoes) {
    if (melhor == null || repeticao.picoN > melhor.picoN) melhor = repeticao;
  }
  return ResumoIsometria(
    maiorPicoN: resultado.metricas.forcaMaximaN,
    mediaPicosN: resultado.mediaPicosN,
    repeticoes: resultado.repeticoes.length,
    rfdMaximaNPorS: melhor?.rfdMaxima.rfdNPorS,
    rfdMaximaPercentualPorS: melhor?.rfdMaxima.rfdPercentualPorS,
    forcaSustentadaN: melhor?.forcaSustentadaN,
    coeficienteVariacaoPercentual: melhor?.coeficienteVariacaoPercentual,
  );
}

ResumoSalto _resumirSalto(List<AmostraForca> amostras) {
  final resultado = const ProcessadorSalto().processar(
    amostras: amostras,
    parametros: const {},
  );
  final melhor = resultado.melhorSalto;
  return ResumoSalto(
    melhorAlturaM: melhor?.alturaVooM,
    alturaMediaM: resultado.alturaMediaM,
    saltos: resultado.saltos.length,
    massaKg: resultado.massaKg,
    indiceFadigaPercentual: resultado.indiceFadigaPercentual,
    potenciaMediaConcentricaW: melhor?.potenciaMediaConcentricaW,
    impulsoConcentricoNs: melhor?.impulsoConcentricoNs,
    tempoFrenagemS: melhor?.tempoFrenagemS,
    rfdFrenagemNPorS: melhor?.rfdFrenagemNPorS,
  );
}

/// Maior pico em N na isometria e melhor altura em cm no salto; travessão
/// quando não há valor.
String valorDestaque(ResumoSessao resumo) => switch (resumo) {
  ResumoIsometria(:final maiorPicoN) => '${maiorPicoN.round()} N',
  ResumoSalto(melhorAlturaM: final alturaM?) =>
    '${(alturaM * 100).toStringAsFixed(1).replaceAll('.', ',')} cm',
  ResumoSalto() || ResumoNaoProcessado() => '—',
};
