import 'dart:async';

import 'package:flutter/foundation.dart';

enum EstadoConexao { desconectado, procurando, conectado }

int nivelBateria(int percentual) => (percentual / 25).ceil().clamp(0, 4);

class ConexaoEquipamento extends ChangeNotifier {
  ConexaoEquipamento({
    this.duracaoBusca = const Duration(seconds: 2),
    this.bateriaSimuladaPercentual = 80,
  });

  static final ConexaoEquipamento instancia = ConexaoEquipamento();

  final Duration duracaoBusca;
  final int bateriaSimuladaPercentual;

  EstadoConexao _estado = EstadoConexao.desconectado;
  String? _nomeDispositivo;
  int? _bateriaPercentual;
  Timer? _timer;
  bool _encerrado = false;

  EstadoConexao get estado => _estado;
  bool get conectado => _estado == EstadoConexao.conectado;
  String? get nomeDispositivo => _nomeDispositivo;
  int? get bateriaPercentual => _bateriaPercentual;

  /// De 0 a 4, em passos de 1/4. Nulo quando a bateria não é conhecida.
  int? get bateriaNivel {
    final percentual = _bateriaPercentual;
    return percentual == null ? null : nivelBateria(percentual);
  }

  void conectar() {
    if (_estado != EstadoConexao.desconectado) return;
    _alterar(EstadoConexao.procurando);
    _timer = Timer(duracaoBusca, () {
      _nomeDispositivo = 'SAMBA-A1B2';
      _bateriaPercentual = bateriaSimuladaPercentual;
      _alterar(EstadoConexao.conectado);
    });
  }

  void desconectar() {
    _timer?.cancel();
    _timer = null;
    _nomeDispositivo = null;
    _bateriaPercentual = null;
    _alterar(EstadoConexao.desconectado);
  }

  @override
  void dispose() {
    _encerrado = true;
    _timer?.cancel();
    super.dispose();
  }

  void _alterar(EstadoConexao estado) {
    _estado = estado;
    if (!_encerrado) notifyListeners();
  }
}
