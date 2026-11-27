import 'dart:io';
import 'dart:isolate';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Descomente após rodar: flutter pub add path_provider share_plus
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';

import '../../funcionalidades/medicao/aplicacao/csv_sessao.dart';
import '../../funcionalidades/medicao/aplicacao/curva_reduzida.dart';
import '../../funcionalidades/medicao/aplicacao/frequencia_media.dart';
import '../../funcionalidades/medicao/aplicacao/resumo_sessao.dart';

import '../../funcionalidades/medicao/dominio/exercicio.dart';
import '../../funcionalidades/medicao/dominio/sessao_medicao.dart';

import '../../nucleo/persistencia/banco_local.dart';

import '../core/app_colors.dart';
import '../core/widgets/cartoes_resumo.dart';
import '../core/widgets/grafico_forca_ao_vivo.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_pagina.dart';

class ResultadoView extends StatefulWidget {
  const ResultadoView({super.key});

  @override
  State<ResultadoView> createState() => _ResultadoViewState();
}

class _ResultadoViewState extends State<ResultadoView> {
  SessaoMedicao? _sessao;
  double? _forcaAlvoN;
  bool _somenteLeitura = false;
  List<FlSpot> _pontosCurva = const [];
  ResumoSessao _resumo = const ResumoNaoProcessado('Sem dados.');
  bool _inicializado = false;
  bool _salvando = false;
  bool _exportando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializado) return;
    _inicializado = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    SessaoMedicao? sessao;

    if (args is Map<String, dynamic>) {
      sessao = args['sessao'] as SessaoMedicao?;
      _forcaAlvoN = args['forcaAlvoN'] as double?;
      _somenteLeitura = args['somenteLeitura'] == true;
    } else if (args is SessaoMedicao) {
      sessao = args;
    }

    if (sessao == null) return;

    _sessao = sessao;
    _pontosCurva = [
      for (final ponto in reduzirCurva(sessao.amostras))
        FlSpot(ponto.tempoS, ponto.forcaN),
    ];
    _resumo = resumirSessao(sessao);
  }

  String _nomeExercicio(Exercicio exercicio) => switch (exercicio) {
        Exercicio.remada => 'Remada',
        Exercicio.extensora => 'Extensora',
        Exercicio.salto => 'Salto Vertical',
        Exercicio.terra => 'Levantamento Terra',
      };

  Future<void> _exportarCsv() async {
    final sessao = _sessao;
    if (sessao == null || _exportando) return;

    setState(() => _exportando = true);
    try {
      final csv = await Isolate.run(() => gerarCsvSessao(sessao));

      final pasta = Directory.systemTemp;
      // Se usar path_provider, prefira: final pasta = await getTemporaryDirectory();
      final timestamp = sessao.inicio.toIso8601String().replaceAll(':', '-');
      final arquivo = File(
        '${pasta.path}/samba_${sessao.exercicio.name}_$timestamp.csv',
      );
      await arquivo.writeAsString(csv);

      // Para compartilhar o arquivo nativamente, adicione share_plus no pubspec.yaml:
      // await Share.shareXFiles([XFile(arquivo.path)], text: 'Dados brutos - SAMBA');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arquivo CSV gerado (${sessao.quantidadeAmostras} amostras).'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar o CSV.')),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _salvar() async {
    final sessao = _sessao;
    if (sessao == null || _salvando) return;

    setState(() => _salvando = true);
    final amostras = sessao.amostras;
    try {
      await BancoLocal.salvarSessao(
        exercicio: sessao.exercicio.name,
        inicioUtc: sessao.inicio,
        frequenciaHz: frequenciaMediaHz(amostras),
        amostras: amostras,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o treino.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Treino salvo com sucesso!')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _confirmarDescarte() async {
    if (_salvando || _exportando) return;

    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.branco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.azulEscuro, width: 1.5),
        ),
        title: const Text(
          'Descartar treino?',
          style: TextStyle(
            color: AppColors.azulEscuro,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Os dados desta medição serão perdidos permanentemente.',
          style: TextStyle(color: AppColors.azulEscuro, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: AppColors.azulEscuro,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.erro,
              foregroundColor: AppColors.branco,
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Descartar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (descartar == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = _sessao;

    return PopScope(
      canPop: _somenteLeitura,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_somenteLeitura) _confirmarDescarte();
      },
      child: SambaPagina(
        cabecalho: SambaTopo(
          titulo: _somenteLeitura ? 'Detalhes do Treino' : 'Análise Pós-Treino',
          mostrarVoltar: _somenteLeitura,
        ),
        rolavel: false,
        child: sessao == null
            ? _buildSemDados()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoSessao(sessao),
                  const SizedBox(height: 12),
                  GraficoForcaResultado(
                    pontos: _pontosCurva,
                    alvoN: _forcaAlvoN,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: CartoesResumo(resumo: _resumo),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SambaBotaoContorno(
                    rotulo: _exportando ? 'Exportando CSV...' : 'Exportar CSV',
                    onPressed: (_salvando || _exportando) ? null : _exportarCsv,
                  ),
                  if (!_somenteLeitura) ...[
                    const SizedBox(height: 10),
                    SambaBotao(
                      rotulo: 'Salvar Treino',
                      rotuloCarregando: 'Salvando...',
                      carregando: _salvando,
                      onPressed: _exportando ? null : _salvar,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: (_salvando || _exportando)
                          ? null
                          : _confirmarDescarte,
                      child: const Text(
                        'Descartar treino',
                        style: TextStyle(
                          color: AppColors.cinza,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildInfoSessao(SessaoMedicao sessao) {
    final duracao = (sessao.duracaoDadosS?.toStringAsFixed(1) ?? '0,0')
        .replaceAll('.', ',');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _nomeExercicio(sessao.exercicio),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.azulEscuro,
          ),
        ),
        Text(
          '$duracao s · ${sessao.quantidadeAmostras} amostras',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.cinza,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSemDados() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Nenhuma sessão encontrada para exibir.',
          style: TextStyle(color: AppColors.cinza, fontSize: 16),
        ),
        const SizedBox(height: 20),
        SambaBotao(
          rotulo: 'Voltar',
          onPressed: () {
            if (_somenteLeitura && Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
            }
          },
        ),
      ],
    );
  }
}