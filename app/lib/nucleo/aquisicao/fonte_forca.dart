import '../modelos/amostra_forca.dart';

abstract interface class FonteForca {
  /// Não retém amostras anteriores à assinatura do Stream.
  Stream<AmostraForca> get amostras;

  /// Chamadas durante uma aquisição ativa não a reiniciam.
  Future<void> iniciar();

  /// Conclui quando não houver mais amostras a entregar; a parada permite uma
  /// nova aquisição no mesmo Stream.
  Future<void> parar();

  /// Conclui quando o equipamento termina de gravar o novo zero.
  Future<void> tarar();
}
