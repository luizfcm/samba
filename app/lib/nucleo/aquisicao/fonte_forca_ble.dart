import 'dart:async';
import 'dart:typed_data';

import '../ble/conexao_equipamento.dart';
import '../ble/estado_equipamento.dart';
import '../ble/pacote_medicao.dart';
import '../modelos/amostra_forca.dart';
import 'fonte_forca.dart';

/// Fonte do equipamento pelo protocolo BLE v2. Pacotes inválidos são contados
/// e ignorados; erro ou fim do fluxo de medições vira erro em [amostras].
class FonteForcaBle implements FonteForca {
  FonteForcaBle({
    required this._conexao,
    this.tempoLimiteInicio = const Duration(seconds: 2),
    this.silencioParada = const Duration(milliseconds: 600),
    this.tempoLimiteParada = const Duration(seconds: 10),
    this.tempoLimiteTara = const Duration(seconds: 3),
  }) {
    _assinaturaMedicoes = _conexao.medicoes.listen(
      _receberPacote,
      onError: _amostras.addError,
      onDone: () => _amostras.addError(
        StateError('A conexão com o equipamento foi encerrada.'),
      ),
    );
    _assinaturaEstados = _conexao.estados.listen(
      _receberEstado,
      onError: (Object _) {},
    );
  }

  static const _start = [0x01];
  static const _stop = [0x02];
  static const _tare = [0x03];
  static const _desligarModoBruto = [0x04, 0x00];

  final ConexaoEquipamento _conexao;
  final Duration tempoLimiteInicio;
  final Duration silencioParada;
  final Duration tempoLimiteParada;
  final Duration tempoLimiteTara;
  final _amostras = StreamController<AmostraForca>.broadcast();
  final _estados = StreamController<EstadoEquipamento>.broadcast();
  late final StreamSubscription<Uint8List> _assinaturaMedicoes;
  late final StreamSubscription<Uint8List> _assinaturaEstados;
  EstadoEquipamento? _ultimoEstado;
  int _pacotesInvalidos = 0;
  bool _adquirindo = false;
  void Function()? _aoReceberPacote;

  EstadoEquipamento? get ultimoEstado => _ultimoEstado;
  int get pacotesInvalidos => _pacotesInvalidos;

  @override
  Stream<AmostraForca> get amostras => _amostras.stream;

  /// Desliga o modo bruto, se estiver ligado, e espera o bit de aquisição em
  /// andamento; sem confirmação, envia STOP e lança [TimeoutException]. Se o
  /// equipamento já estiver adquirindo, para a aquisição antes do START.
  @override
  Future<void> iniciar() async {
    if (_adquirindo) return;

    final estado = EstadoEquipamento.decodificar(await _conexao.lerEstado());
    _ultimoEstado = estado;
    if (estado.aquisicaoEmAndamento) await _pararAquisicaoAnterior();
    if (estado.modoBruto) await _enviar(_desligarModoBruto);

    try {
      await _enviarEAguardar(
        _start,
        (estado) => estado.aquisicaoEmAndamento,
        tempoLimiteInicio,
        'O equipamento não confirmou o início da aquisição.',
      );
    } on TimeoutException {
      _enviar(_stop).ignore();
      rethrow;
    }
    _adquirindo = true;
  }

  /// Conclui depois de [silencioParada] sem pacotes; lança [TimeoutException]
  /// se os pacotes não pararem em [tempoLimiteParada].
  @override
  Future<void> parar() async {
    if (!_adquirindo) return;
    _adquirindo = false;
    await _enviar(_stop);
    await _aguardarSilencio();
  }

  /// STOP, silêncio dos pacotes e bit de aquisição desligado, nessa ordem de
  /// espera; o bit pode ter desligado durante o silêncio.
  Future<void> _pararAquisicaoAnterior() async {
    final desligou = Completer<void>();
    final assinatura = _estados.stream.listen((estado) {
      if (!desligou.isCompleted && !estado.aquisicaoEmAndamento) {
        desligou.complete();
      }
    });
    try {
      await _enviar(_stop);
      await _aguardarSilencio();
      await desligou.future.timeout(
        tempoLimiteParada,
        onTimeout: () => throw TimeoutException(
          'O equipamento não parou a aquisição anterior.',
          tempoLimiteParada,
        ),
      );
    } finally {
      await assinatura.cancel();
    }
  }

  Future<void> _aguardarSilencio() async {
    final silencio = Completer<void>();
    Timer? temporizador;
    void reiniciar() {
      temporizador?.cancel();
      temporizador = Timer(silencioParada, () {
        if (!silencio.isCompleted) silencio.complete();
      });
    }

    _aoReceberPacote = reiniciar;
    reiniciar();
    try {
      await silencio.future.timeout(
        tempoLimiteParada,
        onTimeout: () => throw TimeoutException(
          'O equipamento não parou de enviar pacotes.',
          tempoLimiteParada,
        ),
      );
    } finally {
      temporizador?.cancel();
      _aoReceberPacote = null;
    }
  }

  /// Espera o bit de tara ligar e depois desligar.
  @override
  Future<void> tarar() async {
    var ligou = false;
    await _enviarEAguardar(
      _tare,
      (estado) {
        if (estado.taraEmAndamento) {
          ligou = true;
          return false;
        }
        return ligou;
      },
      tempoLimiteTara,
      'O equipamento não concluiu a tara.',
    );
  }

  /// Encerra os fluxos sem tratar o fim da conexão como erro.
  Future<void> desconectar() async {
    _adquirindo = false;
    await _assinaturaMedicoes.cancel();
    await _assinaturaEstados.cancel();
    await _conexao.desconectar();
    await _amostras.close();
    await _estados.close();
  }

  Future<void> _enviar(List<int> comando) =>
      _conexao.escreverControle(Uint8List.fromList(comando));

  Future<void> _enviarEAguardar(
    List<int> comando,
    bool Function(EstadoEquipamento estado) concluido,
    Duration tempoLimite,
    String mensagem,
  ) async {
    final conclusao = Completer<void>();
    final assinatura = _estados.stream.listen((estado) {
      if (!conclusao.isCompleted && concluido(estado)) conclusao.complete();
    });
    try {
      await _enviar(comando);
      await conclusao.future.timeout(
        tempoLimite,
        onTimeout: () => throw TimeoutException(mensagem, tempoLimite),
      );
    } finally {
      await assinatura.cancel();
    }
  }

  void _receberPacote(Uint8List pacote) {
    _aoReceberPacote?.call();
    final List<AmostraForca> amostras;
    try {
      amostras = PacoteMedicao.decodificar(pacote);
    } on FormatException {
      _pacotesInvalidos++;
      return;
    }
    amostras.forEach(_amostras.add);
  }

  void _receberEstado(Uint8List dados) {
    final EstadoEquipamento estado;
    try {
      estado = EstadoEquipamento.decodificar(dados);
    } on FormatException {
      return;
    }
    _ultimoEstado = estado;
    _estados.add(estado);
  }
}
