import 'dart:async';

import 'package:flutter/material.dart';

import 'funcionalidades/medicao/aplicacao/controlador_medicao.dart';
import 'funcionalidades/medicao/dominio/exercicio.dart';
import 'nucleo/aquisicao/fonte_forca_ble.dart';
import 'nucleo/ble/conexao_equipamento_bluetooth.dart';
import 'nucleo/ble/estado_equipamento.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: TelaTesteBle()),
  );
}

class TelaTesteBle extends StatefulWidget {
  const TelaTesteBle({super.key});

  @override
  State<TelaTesteBle> createState() => _TelaTesteBleState();
}

class _TelaTesteBleState extends State<TelaTesteBle> {
  List<EquipamentoEncontrado> _encontrados = const [];
  EquipamentoEncontrado? _selecionado;
  ConexaoEquipamentoBluetooth? _conexao;
  FonteForcaBle? _fonte;
  ControladorMedicao? _controlador;
  EstadoEquipamento? _estadoLido;
  int? _primeiroTimestampUs;
  bool _ocupado = false;
  String _mensagem = 'Procure o equipamento.';
  late final Timer _atualizacao;

  @override
  void initState() {
    super.initState();
    _atualizacao = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _atualizacao.cancel();
    _controlador?.dispose();
    _fonte?.desconectar().ignore();
    super.dispose();
  }

  Future<void> _executar(String descricao, Future<void> Function() acao) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _mensagem = '$descricao...';
    });
    try {
      await acao();
      if (mounted) setState(() => _mensagem = '$descricao: concluído.');
    } catch (erro) {
      if (mounted) setState(() => _mensagem = '$descricao: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _procurar() => _executar('Procurando', () async {
    final encontrados = await ConexaoEquipamentoBluetooth.procurar();
    setState(() {
      _encontrados = encontrados;
      _selecionado = encontrados.firstOrNull;
    });
  });

  Future<void> _conectar() => _executar('Conectando', () async {
    final conexao = await ConexaoEquipamentoBluetooth.conectar(_selecionado!);
    final fonte = FonteForcaBle(conexao: conexao);
    _estadoLido = EstadoEquipamento.decodificar(await conexao.lerEstado());
    setState(() {
      _conexao = conexao;
      _fonte = fonte;
      _controlador = ControladorMedicao(fonte: fonte);
    });
  });

  Future<void> _tarar() => _executar('Tarando', () => _controlador!.tarar());

  Future<void> _iniciar() => _executar('Iniciando', () async {
    _primeiroTimestampUs = null;
    await _controlador!.iniciar(Exercicio.remada);
  });

  Future<void> _parar() => _executar('Parando', () async {
    await _controlador!.finalizar();
  });

  Future<void> _desconectar() => _executar('Desconectando', () async {
    _controlador?.dispose();
    await _fonte?.desconectar();
    setState(() {
      _controlador = null;
      _fonte = null;
      _conexao = null;
      _estadoLido = null;
    });
  });

  @override
  Widget build(BuildContext contexto) {
    final controlador = _controlador;
    final conectado = _conexao != null;
    final medindo = controlador?.estado == EstadoMedicao.medindo;

    return Scaffold(
      appBar: AppBar(title: const Text('SAMBA - Teste Bluetooth')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _ocupado || conectado ? null : _procurar,
                child: const Text('Procurar'),
              ),
              FilledButton(
                onPressed: _ocupado || conectado || _selecionado == null
                    ? null
                    : _conectar,
                child: const Text('Conectar'),
              ),
              FilledButton(
                onPressed: _ocupado || !conectado || medindo ? null : _tarar,
                child: const Text('Tarar'),
              ),
              FilledButton(
                onPressed: _ocupado || !conectado || medindo ? null : _iniciar,
                child: const Text('Iniciar'),
              ),
              FilledButton(
                onPressed: _ocupado || !medindo ? null : _parar,
                child: const Text('Parar'),
              ),
              FilledButton(
                onPressed: _ocupado || !conectado ? null : _desconectar,
                child: const Text('Desconectar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_mensagem),
          if (!conectado)
            for (final equipamento in _encontrados)
              ListTile(
                selected: identical(equipamento, _selecionado),
                title: Text(
                  equipamento.nome.isEmpty ? 'Sem nome' : equipamento.nome,
                ),
                subtitle: Text(
                  '${equipamento.identificador} · ${equipamento.rssiDbm} dBm',
                ),
                onTap: () => setState(() => _selecionado = equipamento),
              ),
          if (conectado) ...[
            const Divider(height: 32),
            Text('MTU: ${_conexao!.mtu}'),
            const SizedBox(height: 8),
            ..._linhasEstado(_fonte!.ultimoEstado ?? _estadoLido),
            const Divider(height: 32),
            ..._linhasMedicao(controlador!, _fonte!),
          ],
        ],
      ),
    );
  }

  List<Widget> _linhasEstado(EstadoEquipamento? estado) {
    if (estado == null) return const [Text('Estado: sem leitura')];
    String marca(bool ligado) => ligado ? 'sim' : 'não';
    return [
      Text(
        'Estado: versão ${estado.versao}, status 0x'
        '${estado.status.toRadixString(16).padLeft(4, '0')}',
      ),
      Text('Saturação: ${marca(estado.saturacao)}'),
      Text('Tara em andamento: ${marca(estado.taraEmAndamento)}'),
      Text('Sem calibração: ${marca(estado.semCalibracao)}'),
      Text('Erro no ADC: ${marca(estado.erroAdc)}'),
      Text('Modo bruto: ${marca(estado.modoBruto)}'),
      Text('Aquisição em andamento: ${marca(estado.aquisicaoEmAndamento)}'),
      Text('Taxa nominal: ${estado.taxaNominalHz} Hz'),
      Text('Fator: ${estado.fatorMnPorContagem} mN/contagem'),
      Text('Deslocamento: ${estado.deslocamentoContagens} contagens'),
    ];
  }

  List<Widget> _linhasMedicao(
    ControladorMedicao controlador,
    FonteForcaBle fonte,
  ) {
    final sessao = controlador.sessao;
    final quantidade = sessao?.quantidadeAmostras ?? 0;
    String frequencia = '—';
    String ultimaForca = '—';
    if (sessao != null && quantidade > 0) {
      final ultima = sessao.amostrasDesde(quantidade - 1).single;
      _primeiroTimestampUs ??= sessao.amostrasDesde(0).first.timestampUs;
      final duracaoUs = ultima.timestampUs - _primeiroTimestampUs!;
      if (duracaoUs > 0) {
        frequencia =
            '${((quantidade - 1) * 1e6 / duracaoUs).toStringAsFixed(1)} Hz';
      }
      ultimaForca = '${ultima.forcaN.toStringAsFixed(3)} N';
    }

    return [
      Text('Medição: ${controlador.estado.name}'),
      if (controlador.interrompida)
        Text('Interrompida: ${controlador.motivoInterrupcao}'),
      Text('Amostras recebidas: $quantidade'),
      Text('Amostras perdidas: ${controlador.amostrasPerdidas}'),
      Text('Amostras descartadas: ${controlador.amostrasDescartadas}'),
      Text('Amostras saturadas: ${controlador.amostrasSaturadas}'),
      Text('Amostras com erro no ADC: ${controlador.amostrasComErroAdc}'),
      Text('Frequência média: $frequencia'),
      Text('Pacotes inválidos: ${fonte.pacotesInvalidos}'),
      Text('Última força: $ultimaForca'),
    ];
  }
}
