import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../nucleo/aquisicao/fonte_forca.dart';
import '../../../nucleo/aquisicao/fonte_forca_ble.dart';
import '../../../nucleo/aquisicao/fonte_forca_simulada.dart';
import '../../../nucleo/ble/conexao_equipamento.dart';
import '../../../nucleo/ble/estado_equipamento.dart';
import '../dominio/exercicio.dart';
import 'serie_simulada.dart';

/// No modo simulado cada medição usa uma série gerada; nunca é usado como
/// substituto silencioso do Bluetooth.
enum ModoAquisicao { bluetooth, simulado }

/// O equipamento que desconecta sozinho leva de volta a [desconectado].
enum EstadoConexao { desconectado, procurando, conectando, conectado }

/// Conexão com o equipamento e criação da fonte de cada medição. Notifica as
/// mudanças de [estado], de [modo] e de [ultimoEstado]; só ele fecha a conexão.
class GerenciadorEquipamento extends ChangeNotifier {
  GerenciadorEquipamento({
    required this._conector,
    this._modo = ModoAquisicao.bluetooth,
  });

  final ConectorEquipamento _conector;
  ModoAquisicao _modo;
  EstadoConexao _estado = EstadoConexao.desconectado;
  List<EquipamentoEncontrado> _encontrados = const [];
  EquipamentoEncontrado? _equipamento;
  ConexaoEquipamento? _conexao;
  FonteForcaBle? _fonte;
  StreamSubscription<EstadoEquipamento>? _assinaturaEstados;
  EstadoEquipamento? _ultimoEstado;
  bool _encerrado = false;

  /// Pode ser trocado a qualquer momento; vale para a próxima [criarFonte].
  ModoAquisicao get modo => _modo;
  EstadoConexao get estado => _estado;

  /// Resultado da última busca.
  List<EquipamentoEncontrado> get encontrados => _encontrados;
  EquipamentoEncontrado? get equipamento => _equipamento;

  /// Nula quando não há equipamento conectado.
  ConexaoEquipamento? get conexao => _conexao;

  /// Lido ao conectar e atualizado a cada notificação; nulo sem conexão.
  EstadoEquipamento? get ultimoEstado => _ultimoEstado;
  int get pacotesInvalidos => _fonte?.pacotesInvalidos ?? 0;

  set modo(ModoAquisicao modo) {
    if (_modo == modo) return;
    _modo = modo;
    _notificar();
  }

  /// Só com o estado [EstadoConexao.desconectado]; senão lança [StateError].
  Future<List<EquipamentoEncontrado>> procurar({
    Duration tempoLimite = const Duration(seconds: 5),
  }) async {
    _exigirDesconectado();
    _alterarEstado(EstadoConexao.procurando);
    try {
      _encontrados = List.unmodifiable(
        await _conector.procurar(tempoLimite: tempoLimite),
      );
      return _encontrados;
    } finally {
      _alterarEstado(EstadoConexao.desconectado);
    }
  }

  /// Em caso de falha, volta a [EstadoConexao.desconectado] e repassa o erro.
  Future<void> conectar(EquipamentoEncontrado equipamento) async {
    _exigirDesconectado();
    _alterarEstado(EstadoConexao.conectando);
    ConexaoEquipamento? conexao;
    try {
      conexao = await _conector.conectar(equipamento);
      final estado = EstadoEquipamento.decodificar(await conexao.lerEstado());
      final fonte = FonteForcaBle(conexao: conexao);
      _conexao = conexao;
      _fonte = fonte;
      _equipamento = equipamento;
      _ultimoEstado = estado;
      _assinaturaEstados = fonte.estados.listen((estado) {
        _ultimoEstado = estado;
        _notificar();
      });
      final aberta = conexao;
      unawaited(aberta.encerrada.then((_) => _aoEncerrar(aberta)));
      _alterarEstado(EstadoConexao.conectado);
    } catch (_) {
      _limpar();
      _alterarEstado(EstadoConexao.desconectado);
      await conexao?.desconectar();
      rethrow;
    }
  }

  /// Encerra a fonte, o que interrompe uma medição em andamento; sem conexão,
  /// não faz nada.
  Future<void> desconectar() async {
    final conexao = _conexao;
    final fonte = _fonte;
    if (conexao == null) return;
    _limpar();
    _alterarEstado(EstadoConexao.desconectado);
    await fonte?.encerrar();
    await conexao.desconectar();
  }

  /// Lança [StateError] sem conexão ou durante uma medição; no modo simulado,
  /// não faz nada.
  Future<void> tarar() async {
    if (_modo == ModoAquisicao.simulado) return;
    final fonte = _fonte;
    if (fonte == null) {
      throw StateError('Conecte o equipamento antes de tarar.');
    }
    if (_ultimoEstado?.aquisicaoEmAndamento ?? false) {
      throw StateError('Não é possível tarar durante uma medição.');
    }
    await fonte.tarar();
  }

  /// No Bluetooth devolve a fonte da conexão, a mesma em todas as medições, ou
  /// lança [StateError] sem conexão; no simulado, uma fonte nova.
  FonteForca criarFonte(Exercicio exercicio) => switch (_modo) {
    ModoAquisicao.simulado => FonteForcaSimulada(
      forcasN: serieSimulada(exercicio),
    ),
    ModoAquisicao.bluetooth =>
      _fonte ??
          (throw StateError(
            'Nenhum equipamento conectado: conecte o equipamento antes de '
            'medir.',
          )),
  };

  @override
  void dispose() {
    _encerrado = true;
    final conexao = _conexao;
    final fonte = _fonte;
    _limpar();
    fonte?.encerrar().ignore();
    conexao?.desconectar().ignore();
    super.dispose();
  }

  void _exigirDesconectado() {
    switch (_estado) {
      case EstadoConexao.desconectado:
        return;
      case EstadoConexao.procurando:
        throw StateError('Já existe uma busca em andamento.');
      case EstadoConexao.conectando:
        throw StateError('Já existe uma conexão em andamento.');
      case EstadoConexao.conectado:
        throw StateError('Desconecte o equipamento atual antes.');
    }
  }

  void _aoEncerrar(ConexaoEquipamento conexao) {
    if (!identical(_conexao, conexao)) return;
    _limpar();
    _alterarEstado(EstadoConexao.desconectado);
  }

  void _limpar() {
    _assinaturaEstados?.cancel().ignore();
    _assinaturaEstados = null;
    _conexao = null;
    _fonte = null;
    _equipamento = null;
    _ultimoEstado = null;
  }

  void _alterarEstado(EstadoConexao estado) {
    _estado = estado;
    _notificar();
  }

  void _notificar() {
    if (!_encerrado) notifyListeners();
  }
}
