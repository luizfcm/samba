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
  });

  final double maiorPicoN;
  final double? mediaPicosN;
  final int repeticoes;
}

class ResumoSalto extends ResumoSessao {
  const ResumoSalto({
    required this.melhorAlturaM,
    required this.alturaMediaM,
    required this.saltos,
    required this.massaKg,
  });

  /// Altura pelo tempo de voo; nula quando não há saltos.
  final double? melhorAlturaM;
  final double? alturaMediaM;
  final int saltos;
  final double massaKg;
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
  return ResumoIsometria(
    maiorPicoN: resultado.metricas.forcaMaximaN,
    mediaPicosN: resultado.mediaPicosN,
    repeticoes: resultado.repeticoes.length,
  );
}

ResumoSalto _resumirSalto(List<AmostraForca> amostras) {
  final resultado = const ProcessadorSalto().processar(
    amostras: amostras,
    parametros: const {},
  );
  return ResumoSalto(
    melhorAlturaM: resultado.melhorSalto?.alturaVooM,
    alturaMediaM: resultado.alturaMediaM,
    saltos: resultado.saltos.length,
    massaKg: resultado.massaKg,
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
