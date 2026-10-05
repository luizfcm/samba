class AmostraForca {
  const AmostraForca({
    required this.sequencia,
    required this.timestampUs,
    required this.forcaN,
    required this.status,
  });

  final int sequencia;

  /// Tempo de aquisição em microssegundos, relativo ao relógio da fonte.
  final int timestampUs;

  /// Força em newtons; valores negativos são preservados.
  final double forcaN;
  final int status;

  double get timestampSegundos => timestampUs / 1e6;
}
