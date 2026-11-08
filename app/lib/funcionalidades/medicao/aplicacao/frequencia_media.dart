import '../../../nucleo/modelos/amostra_forca.dart';

/// Frequência média pelos timestamps, arredondada; zero com menos de duas
/// amostras.
int frequenciaMediaHz(List<AmostraForca> amostras) {
  if (amostras.length < 2) return 0;
  final duracaoUs = amostras.last.timestampUs - amostras.first.timestampUs;
  return ((amostras.length - 1) * 1e6 / duracaoUs).round();
}
