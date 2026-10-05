import '../modelos/amostra_forca.dart';

abstract interface class FonteForca {
  /// Não retém amostras anteriores à assinatura do Stream.
  Stream<AmostraForca> get amostras;

  /// Chamadas durante uma aquisição ativa não a reiniciam.
  Future<void> iniciar();

  /// A parada permite uma nova aquisição no mesmo Stream.
  Future<void> parar();
}
