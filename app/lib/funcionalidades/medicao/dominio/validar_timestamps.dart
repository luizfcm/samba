import '../../../nucleo/modelos/amostra_forca.dart';

/// Lança ArgumentError indicando a primeira amostra cujo timestamp não é maior
/// que o da anterior.
void validarTimestamps(List<AmostraForca> amostras) {
  for (var indice = 1; indice < amostras.length; indice++) {
    if (amostras[indice].timestampUs <= amostras[indice - 1].timestampUs) {
      throw ArgumentError(
        'Os timestamps das amostras devem ser estritamente crescentes '
        '(índice $indice).',
      );
    }
  }
}
