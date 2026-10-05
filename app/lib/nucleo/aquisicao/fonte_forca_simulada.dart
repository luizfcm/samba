import 'dart:async';

import '../modelos/amostra_forca.dart';
import 'fonte_forca.dart';

/// Gera um sinal triangular entre 0 e 100 N, com período nominal de um segundo.
///
/// O temporizador solicita uma amostra a cada 10 ms. Os timestamps usam um
/// relógio monotonicamente crescente para registrar o tempo real transcorrido,
/// inclusive quando o agendamento atrasa. Cada aquisição reinicia o sinal,
/// a sequência e o timestamp em zero.
class FonteForcaSimulada implements FonteForca {
  static const _intervalo = Duration(milliseconds: 10);
  final _controlador = StreamController<AmostraForca>.broadcast();
  final _relogio = Stopwatch();
  Timer? _temporizador;
  int _sequencia = 0;

  @override
  Stream<AmostraForca> get amostras => _controlador.stream;

  @override
  Future<void> iniciar() async {
    if (_temporizador != null) return;

    _sequencia = 0;
    _relogio
      ..reset()
      ..start();
    _temporizador = Timer.periodic(_intervalo, (_) => _emitirAmostra());
    _emitirAmostra(timestampUs: 0);
  }

  @override
  Future<void> parar() async {
    _temporizador?.cancel();
    _temporizador = null;
    _relogio.stop();
  }

  void _emitirAmostra({int? timestampUs}) {
    final fase = _sequencia % 100;
    final forcaN = (fase <= 50 ? fase : 100 - fase) * 2.0;
    _controlador.add(
      AmostraForca(
        sequencia: _sequencia,
        timestampUs: timestampUs ?? _relogio.elapsedMicroseconds,
        forcaN: forcaN,
        status: 0,
      ),
    );
    _sequencia++;
  }
}
