import '../dominio/sessao_medicao.dart';

/// Uma linha por amostra, separada por vírgulas, com ponto decimal e quebra de
/// linha `\n`, inclusive depois da última.
String gerarCsvSessao(SessaoMedicao sessao) {
  final csv = StringBuffer('sequencia,timestamp_us,forca_n,status\n');
  for (final amostra in sessao.amostrasDesde(0)) {
    csv
      ..write(amostra.sequencia)
      ..write(',')
      ..write(amostra.timestampUs)
      ..write(',')
      ..write(amostra.forcaN)
      ..write(',')
      ..write(amostra.status)
      ..write('\n');
  }
  return csv.toString();
}
