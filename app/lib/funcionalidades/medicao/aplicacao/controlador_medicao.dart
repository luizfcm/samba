import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../nucleo/aquisicao/fonte_forca.dart';
import '../../../nucleo/modelos/amostra_forca.dart';
import '../dominio/exercicio.dart';
import '../dominio/sessao_medicao.dart';

enum EstadoMedicao { ociosa, medindo, finalizada }

class ControladorMedicao extends ChangeNotifier {
  ControladorMedicao({required this._fonte});

  final FonteForca _fonte;
  EstadoMedicao _estado = EstadoMedicao.ociosa;
  SessaoMedicao? _sessao;
  StreamSubscription<AmostraForca>? _assinatura;
  int? _ultimaSequencia;
  int? _ultimoTimestampUs;
  int _amostrasPerdidas = 0;
  int _amostrasDescartadas = 0;
  bool _encerrado = false;

  EstadoMedicao get estado => _estado;
  SessaoMedicao? get sessao => _sessao;

  /// Amostras descartadas só pelo timestamp avançam a referência de sequência
  /// e não contam como perdidas.
  int get amostrasPerdidas => _amostrasPerdidas;
  int get amostrasDescartadas => _amostrasDescartadas;

  Future<void> iniciar(Exercicio exercicio, {DateTime? inicio}) async {
    if (_estado == EstadoMedicao.medindo) {
      throw StateError('Já existe uma medição em andamento.');
    }
    _sessao = SessaoMedicao(exercicio: exercicio, inicio: inicio);
    _ultimaSequencia = null;
    _ultimoTimestampUs = null;
    _amostrasPerdidas = 0;
    _amostrasDescartadas = 0;
    final assinatura = _fonte.amostras.listen(_receberAmostra);
    _assinatura = assinatura;
    _alterarEstado(EstadoMedicao.medindo);

    try {
      await _fonte.iniciar();
    } catch (_) {
      if (identical(_assinatura, assinatura)) {
        _assinatura = null;
        await assinatura.cancel();
        _sessao = null;
        _alterarEstado(EstadoMedicao.ociosa);
      }
      rethrow;
    }
  }

  /// O estado só passa a finalizada depois que a fonte conclui a parada, mesmo
  /// que ela falhe; amostras recebidas nesse intervalo são ignoradas.
  Future<SessaoMedicao> finalizar({DateTime? termino}) async {
    final assinatura = _assinatura;
    if (_estado != EstadoMedicao.medindo || assinatura == null) {
      throw StateError('Não há medição em andamento.');
    }
    final sessao = _sessao!;
    final instante = termino ?? DateTime.now();
    _assinatura = null;

    try {
      await assinatura.cancel();
      await _fonte.parar();
    } finally {
      sessao.finalizar(termino: instante);
      _alterarEstado(EstadoMedicao.finalizada);
    }
    return sessao;
  }

  @override
  void dispose() {
    _encerrado = true;
    final assinatura = _assinatura;
    if (assinatura != null) {
      _assinatura = null;
      unawaited(assinatura.cancel());
      _fonte.parar().ignore();
    }
    super.dispose();
  }

  void _receberAmostra(AmostraForca amostra) {
    final ultimaSequencia = _ultimaSequencia;
    if (ultimaSequencia != null) {
      if (amostra.sequencia <= ultimaSequencia) {
        _amostrasDescartadas++;
        return;
      }
      _amostrasPerdidas += amostra.sequencia - ultimaSequencia - 1;
    }
    _ultimaSequencia = amostra.sequencia;

    final ultimoTimestampUs = _ultimoTimestampUs;
    if (ultimoTimestampUs != null && amostra.timestampUs <= ultimoTimestampUs) {
      _amostrasDescartadas++;
      return;
    }
    _ultimoTimestampUs = amostra.timestampUs;
    _sessao!.adicionarAmostra(amostra);
  }

  void _alterarEstado(EstadoMedicao estado) {
    _estado = estado;
    if (!_encerrado) notifyListeners();
  }
}
