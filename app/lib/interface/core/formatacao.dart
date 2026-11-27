String formatarValor(double? valor, int casas, String unidade) {
  if (valor == null) return '—';
  final texto = valor.toStringAsFixed(casas).replaceAll('.', ',');
  return '$texto $unidade';
}
