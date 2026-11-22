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

/// Uma sessão sem dados suficientes vira [ResumoNaoProcessado], com o motivo
/// para o usuário.
ResumoSessao resumirSessao(SessaoMedicao sessao) => switch (sessao.exercicio) {
  Exercicio.remada || Exercicio.extensora => _resumirIsometria(sessao.amostras),
  Exercicio.salto => _resumirSalto(sessao.amostras),
  Exercicio.terra => const ResumoNaoProcessado(
    'Não há processamento para o terra.',
  ),
};

ResumoSessao _resumirIsometria(List<AmostraForca> amostras) {
  final resultado = const ProcessadorIsometria().processar(
    amostras: amostras,
    parametros: const {},
  );
  final metricas = resultado.metricas;
  if (metricas == null) {
    return const ResumoNaoProcessado(
      'A medição terminou antes de registrar dados suficientes.',
    );
  }
  ResultadoRepeticao? melhor;
  for (final repeticao in resultado.repeticoes) {
    if (melhor == null || repeticao.picoN > melhor.picoN) melhor = repeticao;
  }
  return ResumoIsometria(
    maiorPicoN: metricas.forcaMaximaN,
    mediaPicosN: resultado.mediaPicosN,
    repeticoes: resultado.repeticoes.length,
    rfdMaximaNPorS: melhor?.rfdMaxima.rfdNPorS,
    rfdMaximaPercentualPorS: melhor?.rfdMaxima.rfdPercentualPorS,
    forcaSustentadaN: melhor?.forcaSustentadaN,
    coeficienteVariacaoPercentual: melhor?.coeficienteVariacaoPercentual,
  );
}

ResumoSessao _resumirSalto(List<AmostraForca> amostras) {
  const processador = ProcessadorSalto();
  final resultado = processador.processar(
    amostras: amostras,
    parametros: const {},
  );
  final massaKg = resultado.massaKg;
  if (massaKg == null) {
    final duracaoUs = amostras.length < 2
        ? 0
        : amostras.last.timestampUs - amostras.first.timestampUs;
    return ResumoNaoProcessado(
      duracaoUs < processador.duracaoRepousoInicialUs
          ? 'A medição terminou antes do primeiro segundo parado na plataforma.'
          : 'Não houve um momento com a pessoa parada na plataforma para '
                'estimar a massa.',
    );
  }
  final melhor = resultado.melhorSalto;
  return ResumoSalto(
    melhorAlturaM: melhor?.alturaVooM,
    alturaMediaM: resultado.alturaMediaM,
    saltos: resultado.saltos.length,
    massaKg: massaKg,
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
