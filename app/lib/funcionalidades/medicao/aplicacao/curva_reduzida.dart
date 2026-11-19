import '../../../nucleo/modelos/amostra_forca.dart';

class PontoCurva {
  const PontoCurva({required this.tempoS, required this.forcaN});

  /// Segundos desde a origem, por padrão a primeira amostra.
  final double tempoS;
  final double forcaN;
}

/// Divide a duração em até [maximoPontos] intervalos de tempo iguais e guarda,
/// de cada um, a amostra de maior força, para não perder os picos.
List<PontoCurva> reduzirCurva(
  List<AmostraForca> amostras, {
  int maximoPontos = 1500,
  int? origemUs,
}) {
  if (maximoPontos < 1) {
    throw ArgumentError('O número máximo de pontos deve ser positivo.');
  }
  if (amostras.isEmpty) return const [];

  final inicioUs = amostras.first.timestampUs;
  final referenciaUs = origemUs ?? inicioUs;
  PontoCurva ponto(AmostraForca amostra) => PontoCurva(
    tempoS: (amostra.timestampUs - referenciaUs) / 1e6,
    forcaN: amostra.forcaN,
  );

  if (amostras.length <= maximoPontos) {
    return List.unmodifiable(amostras.map(ponto));
  }

  final duracaoUs = amostras.last.timestampUs - inicioUs;
  final pontos = <PontoCurva>[];
  AmostraForca? maior;
  var intervaloAtual = 0;
  for (final amostra in amostras) {
    final intervalo =
        (amostra.timestampUs - inicioUs) * maximoPontos ~/ (duracaoUs + 1);
    if (intervalo != intervaloAtual && maior != null) {
      pontos.add(ponto(maior));
      maior = null;
    }
    intervaloAtual = intervalo;
    if (maior == null || amostra.forcaN > maior.forcaN) maior = amostra;
  }
  pontos.add(ponto(maior!));
  return List.unmodifiable(pontos);
}
