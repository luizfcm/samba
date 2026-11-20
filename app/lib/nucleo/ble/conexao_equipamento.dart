import 'dart:typed_data';

/// Características do serviço SAMBA, sem depender de um pacote de Bluetooth.
abstract interface class ConexaoEquipamento {
  /// Cada evento é uma notificação da característica Medição.
  Stream<Uint8List> get medicoes;

  /// Cada evento é uma notificação da característica Estado.
  Stream<Uint8List> get estados;

  Future<Uint8List> lerEstado();

  Future<void> escreverControle(Uint8List comando);

  Future<void> desconectar();
}
