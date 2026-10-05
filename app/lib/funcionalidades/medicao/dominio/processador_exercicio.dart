import '../../../nucleo/modelos/amostra_forca.dart';

abstract interface class ProcessadorExercicio<T> {
  T processar({
    required List<AmostraForca> amostras,
    required Map<String, double> parametros,
  });
}
