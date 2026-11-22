import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../nucleo/aquisicao/fonte_forca.dart';
import '../../../nucleo/ble/bits_status.dart';
import '../../../nucleo/modelos/amostra_forca.dart';
import '../dominio/exercicio.dart';
import '../dominio/sessao_medicao.dart';

enum EstadoMedicao { ociosa, medindo, finalizada }

class ControladorMedicao extends ChangeNotifier {
  ControladorMedicao({required this._fonte});

  static const _quedaReinicioSequencia = 1000;

  final FonteForca _fonte;
  EstadoMedicao _estado = EstadoMedicao.ociosa;
  SessaoMedicao? _sessao;
  StreamSubscription<AmostraForca>? _assinatura;
  int? _ultimaSequencia;
  int? _ultimoTimestampUs;
  int _amostrasPerdidas = 0;
  int _amostrasDescartadas = 0;
  int _amostrasSaturadas = 0;
  int _amostrasComErroAdc = 0;
  String? _motivoInterrupcao;
  bool _inverterSinal = false;
  bool _encerrado = false;

  EstadoMedicao get estado => _estado;
  SessaoMedicao? get sessao => _sessao;

  /// Amostras descartadas só pelo timestamp avançam a referência de sequência
  /// e não contam como perdidas.
  int get amostrasPerdidas => _amostrasPerdidas;
  int get amostrasDescartadas => _amostrasDescartadas;

  /// Contadas entre as amostras aceitas na sessão.
  int get amostrasSaturadas => _amostrasSaturadas;
  int get amostrasComErroAdc => _amostrasComErroAdc;

  /// Erro ou fim do fluxo da fonte, ou reinício da sequência, finaliza a
  /// sessão com as amostras já recebidas.
  bool get interrompida => _motivoInterrupcao != null;
  String? get motivoInterrupcao => _motivoInterrupcao;

  /// No salto a célula é comprimida e a fonte manda força negativa; a sessão
  /// recebe a força com o sinal invertido, sempre positiva no exercício.
  Future<void> iniciar(Exercicio exercicio, {DateTime? inicio}) async {
    if (_estado == EstadoMedicao.medindo) {
      throw StateError('Já existe uma medição em andamento.');
    }
    _sessao = SessaoMedicao(exercicio: exercicio, inicio: inicio);
    _inverterSinal = exercicio == Exercicio.salto;
    _ultimaSequencia = null;
    _ultimoTimestampUs = null;
    _amostrasPerdidas = 0;
    _amostrasDescartadas = 0;
    _amostrasSaturadas = 0;
    _amostrasComErroAdc = 0;
    _motivoInterrupcao = null;
    final assinatura = _fonte.amostras.listen(
      _receberAmostra,
      onError: (Object erro) => _interromper(_descrever(erro)),
      onDone: () => _interromper('A fonte de força encerrou o envio.'),
    );
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

  /// Continua recebendo amostras até a fonte concluir a parada e só então
  /// finaliza a sessão e passa a finalizada, mesmo que a parada falhe. Depois
  /// de uma interrupção, devolve a sessão já finalizada sem chamar a fonte.
  Future<SessaoMedicao> finalizar({DateTime? termino}) async {
    if (_estado == EstadoMedicao.finalizada && interrompida) return _sessao!;
    final assinatura = _assinatura;
    if (_estado != EstadoMedicao.medindo || assinatura == null) {
      throw StateError('Não há medição em andamento.');
    }
    final sessao = _sessao!;
    final instante = termino ?? DateTime.now();
    _assinatura = null;

    try {
      await _fonte.parar();
    } finally {
      await assinatura.cancel();
      sessao.finalizar(termino: instante);
      _alterarEstado(EstadoMedicao.finalizada);
    }
    return sessao;
  }

  Future<void> tarar() async {
    if (_estado == EstadoMedicao.medindo) {
      throw StateError('Não é possível tarar durante uma medição.');
    }
    await _fonte.tarar();
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
      if (amostra.sequencia < ultimaSequencia - _quedaReinicioSequencia) {
        _interromper('A sequência do equipamento recomeçou.');
        return;
      }
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
    if (amostra.status & BitsStatus.saturacao != 0) _amostrasSaturadas++;
    if (amostra.status & BitsStatus.erroAdc != 0) _amostrasComErroAdc++;
    _sessao!.adicionarAmostra(
      _inverterSinal
          ? AmostraForca(
              sequencia: amostra.sequencia,
              timestampUs: amostra.timestampUs,
              // Subtrair de 0.0 evita -0.0 quando a força é zero.
              forcaN: 0.0 - amostra.forcaN,
              status: amostra.status,
            )
          : amostra,
    );
  }

  /// Durante a finalização não interrompe: a sessão já está terminando.
  void _interromper(String motivo) {
    final assinatura = _assinatura;
    if (_estado != EstadoMedicao.medindo || assinatura == null) return;
    _assinatura = null;
    _motivoInterrupcao = motivo;
    unawaited(assinatura.cancel());
    _fonte.parar().ignore();
    _sessao!.finalizar();
    _alterarEstado(EstadoMedicao.finalizada);
  }

  String _descrever(Object erro) => switch (erro) {
    StateError(:final message) => message,
    FormatException(:final message) => message,
    TimeoutException(message: final mensagem?) => mensagem,
    _ => '$erro',
  };

  void _alterarEstado(EstadoMedicao estado) {
    _estado = estado;
    if (!_encerrado) notifyListeners();
  }
}
