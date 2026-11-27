import 'dart:typed_data';

/// Características do serviço SAMBA, sem depender de um pacote de Bluetooth.
abstract interface class ConexaoEquipamento {
  /// Cada evento é uma notificação da característica Medição.
  Stream<Uint8List> get medicoes;

  /// Cada evento é uma notificação da característica Estado.
  Stream<Uint8List> get estados;

  /// Conclui quando a conexão termina, pelo equipamento ou por [desconectar].
  Future<void> get encerrada;

  Future<Uint8List> lerEstado();

  Future<void> escreverControle(Uint8List comando);

  Future<void> desconectar();
}

abstract interface class EquipamentoEncontrado {
  String get nome;
  String get identificador;
  int get rssiDbm;
}

/// Busca e abertura de conexões, separadas da conexão para permitir testes.
abstract interface class ConectorEquipamento {
  Future<List<EquipamentoEncontrado>> procurar({Duration tempoLimite});

  Future<ConexaoEquipamento> conectar(EquipamentoEncontrado equipamento);
}
