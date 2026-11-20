import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'conexao_equipamento.dart';

/// Equipamento achado na busca; esconde o tipo do pacote de Bluetooth.
class EquipamentoEncontrado {
  const EquipamentoEncontrado._(
    this._dispositivo, {
    required this.nome,
    required this.rssiDbm,
  });

  final BluetoothDevice _dispositivo;
  final String nome;
  final int rssiDbm;

  String get identificador => _dispositivo.remoteId.str;
}

/// Único ponto do app que depende do flutter_blue_plus. A desconexão pelo
/// equipamento vira erro e fim do fluxo de medições.
class ConexaoEquipamentoBluetooth implements ConexaoEquipamento {
  ConexaoEquipamentoBluetooth._(
    this._dispositivo,
    this._medicao,
    this._estado,
    this._controle,
    this.mtu,
  );

  static final _uuidServico = Guid('1d770001-fc8b-4e8e-aa34-c86e1b9eeaf5');
  static final _uuidMedicao = Guid('1d770002-fc8b-4e8e-aa34-c86e1b9eeaf5');
  static final _uuidControle = Guid('1d770003-fc8b-4e8e-aa34-c86e1b9eeaf5');
  static final _uuidEstado = Guid('1d770004-fc8b-4e8e-aa34-c86e1b9eeaf5');
  static const mtuDesejado = 247;

  final BluetoothDevice _dispositivo;
  final BluetoothCharacteristic _medicao;
  final BluetoothCharacteristic _estado;
  final BluetoothCharacteristic _controle;

  /// MTU obtido na negociação da conexão.
  final int mtu;
  final _medicoes = StreamController<Uint8List>.broadcast();
  final _estados = StreamController<Uint8List>.broadcast();
  final _assinaturas = <StreamSubscription<Object?>>[];
  bool _encerrada = false;

  static Future<List<EquipamentoEncontrado>> procurar({
    Duration tempoLimite = const Duration(seconds: 5),
  }) async {
    final encontrados = <String, EquipamentoEncontrado>{};
    final assinatura = FlutterBluePlus.onScanResults.listen((resultados) {
      for (final resultado in resultados) {
        final dispositivo = resultado.device;
        encontrados[dispositivo.remoteId.str] = EquipamentoEncontrado._(
          dispositivo,
          nome: resultado.advertisementData.advName,
          rssiDbm: resultado.rssi,
        );
      }
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [_uuidServico],
        timeout: tempoLimite,
      );
      await FlutterBluePlus.isScanning.where((buscando) => !buscando).first;
    } finally {
      await assinatura.cancel();
      await FlutterBluePlus.stopScan();
    }
    return List.unmodifiable(encontrados.values);
  }

  /// Para a busca, conecta, descobre os serviços, negocia MTU e prioridade e
  /// ativa as notificações antes de qualquer escrita em Controle.
  static Future<ConexaoEquipamentoBluetooth> conectar(
    EquipamentoEncontrado equipamento, {
    Duration tempoLimite = const Duration(seconds: 15),
  }) async {
    final dispositivo = equipamento._dispositivo;
    await FlutterBluePlus.stopScan();
    await dispositivo.connect(timeout: tempoLimite, mtu: null);

    try {
      final servico = (await dispositivo.discoverServices())
          .where((servico) => servico.uuid == _uuidServico)
          .firstOrNull;
      if (servico == null) {
        throw StateError('O equipamento não oferece o serviço SAMBA.');
      }
      BluetoothCharacteristic caracteristica(Guid uuid) {
        final encontrada = servico.characteristics
            .where((caracteristica) => caracteristica.uuid == uuid)
            .firstOrNull;
        if (encontrada == null) {
          throw StateError('Característica ausente no equipamento: $uuid');
        }
        return encontrada;
      }

      var mtu = dispositivo.mtuNow;
      if (Platform.isAndroid) {
        mtu = await dispositivo.requestMtu(mtuDesejado);
        await dispositivo.requestConnectionPriority(
          connectionPriorityRequest: ConnectionPriority.high,
        );
      }

      final conexao = ConexaoEquipamentoBluetooth._(
        dispositivo,
        caracteristica(_uuidMedicao),
        caracteristica(_uuidEstado),
        caracteristica(_uuidControle),
        mtu,
      );
      await conexao._ativarNotificacoes();
      return conexao;
    } catch (_) {
      await dispositivo.disconnect();
      rethrow;
    }
  }

  @override
  Stream<Uint8List> get medicoes => _medicoes.stream;

  @override
  Stream<Uint8List> get estados => _estados.stream;

  @override
  Future<Uint8List> lerEstado() async =>
      Uint8List.fromList(await _estado.read());

  @override
  Future<void> escreverControle(Uint8List comando) =>
      _controle.write(comando, withoutResponse: false);

  /// Pode ser chamado mais de uma vez.
  @override
  Future<void> desconectar() async {
    if (_encerrada) return;
    await _encerrar();
    await _dispositivo.disconnect();
  }

  Future<void> _ativarNotificacoes() async {
    _assinaturas
      ..add(
        _medicao.onValueReceived.listen(
          (valor) => _medicoes.add(Uint8List.fromList(valor)),
        ),
      )
      ..add(
        _estado.onValueReceived.listen(
          (valor) => _estados.add(Uint8List.fromList(valor)),
        ),
      )
      ..add(
        _dispositivo.connectionState.listen((estado) {
          if (estado == BluetoothConnectionState.disconnected && !_encerrada) {
            _medicoes.addError(StateError('O equipamento desconectou.'));
            _encerrar().ignore();
          }
        }),
      );
    await _medicao.setNotifyValue(true);
    await _estado.setNotifyValue(true);
  }

  Future<void> _encerrar() async {
    _encerrada = true;
    for (final assinatura in _assinaturas) {
      await assinatura.cancel();
    }
    _assinaturas.clear();
    await _medicoes.close();
    await _estados.close();
  }
}
