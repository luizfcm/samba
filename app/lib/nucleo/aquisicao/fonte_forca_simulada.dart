import 'dart:async';
import 'dart:math';

import '../modelos/amostra_forca.dart';
import 'fonte_forca.dart';
import 'series_simuladas.dart';

/// Envia a série em lotes de 20 amostras a cada 20 ms, como o ESP32. O tempo
/// de cada amostra vem da posição dela na série.
class FonteForcaSimulada implements FonteForca {
  FonteForcaSimulada({List<double>? forcasN})
    : _forcasN = List.unmodifiable(forcasN ?? gerarSerieIsometria());

  static const _amostrasPorLote = 20;
  static const _intervalo = Duration(milliseconds: 20);
  static const _passoUs = 1000;
  final List<double> _forcasN;
  final _controlador = StreamController<AmostraForca>.broadcast();
  Timer? _temporizador;
  int _indice = 0;

  @override
  Stream<AmostraForca> get amostras => _controlador.stream;

  @override
  Future<void> iniciar() async {
    if (_temporizador != null) return;

    _indice = 0;
    _temporizador = Timer.periodic(_intervalo, (_) => _emitirLote());
    _emitirLote();
  }

  @override
  Future<void> parar() async => _cancelarTemporizador();

  void _cancelarTemporizador() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  void _emitirLote() {
    final fim = min(_indice + _amostrasPorLote, _forcasN.length);
    for (; _indice < fim; _indice++) {
      _controlador.add(
        AmostraForca(
          sequencia: _indice,
          timestampUs: _indice * _passoUs,
          forcaN: _forcasN[_indice],
          status: 0,
        ),
      );
    }
    if (_indice >= _forcasN.length) _cancelarTemporizador();
  }
}
