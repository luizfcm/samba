import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../funcionalidades/medicao/aplicacao/controlador_medicao.dart';
import '../../funcionalidades/medicao/aplicacao/curva_ao_vivo.dart';
import '../../funcionalidades/medicao/aplicacao/serie_simulada.dart';
import '../../funcionalidades/medicao/dominio/exercicio.dart';

import '../../nucleo/aquisicao/fonte_forca_simulada.dart';

import '../core/app_colors.dart';

import '../core/widgets/dialogo_alvo.dart';
import '../core/widgets/grafico_forca_ao_vivo.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_cartao.dart';
import '../core/widgets/samba_metrica.dart';
import '../core/widgets/samba_pagina.dart';

class MedicaoView extends StatefulWidget {
  const MedicaoView({super.key});

  @override
  State<MedicaoView> createState() => _MedicaoViewState();
}

class _MedicaoViewState extends State<MedicaoView> {
  Timer? _timer;
  ControladorMedicao? _controlador;
  CurvaAoVivo? _curva;
  List<FlSpot> _pontos = const [];
  double? _alvoN;
  bool _finalizando = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final curva = _curva;
      setState(() {
        if (curva != null) {
          _pontos = [
            for (final ponto in curva.atualizar())
              FlSpot(ponto.tempoS, ponto.forcaN),
          ];
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controlador != null) return;

    final exercicio = ModalRoute.of(context)!.settings.arguments as Exercicio;
    final controlador = ControladorMedicao(
      fonte: FonteForcaSimulada(forcasN: serieSimulada(exercicio)),
    );
    _controlador = controlador;
    controlador.iniciar(exercicio);
    _curva = CurvaAoVivo(sessao: controlador.sessao!);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controlador?.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    if (_finalizando) return;
    _finalizando = true;
    _timer?.cancel();
    final sessao = await _controlador!.finalizar();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/resultado',
      arguments: {'sessao': sessao, 'forcaAlvoN': _alvoN},
    );
  }

  Future<void> _definirAlvo() async {
    final resposta = await showDialog<RespostaAlvo>(
      context: context,
      builder: (dialogContext) => Theme(
        data: Theme.of(dialogContext).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.azulEscuro,
            onPrimary: AppColors.branco,
            surface: AppColors.branco,
            onSurface: AppColors.azulEscuro,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: AppColors.branco,
            titleTextStyle: const TextStyle(
              color: AppColors.azulEscuro,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.azulEscuro, width: 1.5),
            ),
          ),
        ),
        child: Builder(
          builder: (themedContext) {
            // Dispara o diálogo original já herdando o tema claro de alto contraste
            Future.microtask(() async {
              if (!themedContext.mounted) return;
              final res = await mostrarDialogoAlvo(
                themedContext,
                alvoAtual: _alvoN,
              );
              if (themedContext.mounted) Navigator.pop(themedContext, res);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    if (resposta == null || !mounted) return;
    setState(() => _alvoN = resposta.valorN);
  }

  String _formatarTempo(int segundosTotal) {
    final minutos = (segundosTotal ~/ 60).toString().padLeft(2, '0');
    final segs = (segundosTotal % 60).toString().padLeft(2, '0');
    return '$minutos:$segs';
  }

  @override
  Widget build(BuildContext context) {
    final forcaAtual = _pontos.isEmpty ? null : _pontos.last.y;
    final alvo = _alvoN;
    final atingiu = forcaAtual != null && alvo != null && forcaAtual >= alvo;
    final percentual = (forcaAtual != null && alvo != null)
        ? '${(forcaAtual / alvo * 100).round()}%'
        : '—';
    final temAlvo = alvo != null;

    return SambaPagina(
      cabecalho: const SambaTopo(
        titulo: 'Medição em Andamento',
        mostrarVoltar: false,
      ),
      espacamentoSuperior: 24,
      redimensionarComTeclado: false,
      rolavel: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GraficoForcaAoVivo(
              pontos: _pontos,
              alvoN: alvo,
              destacar: atingiu,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SambaMetrica(
                  titulo: 'Tempo',
                  valor: _formatarTempo(
                    (_controlador?.sessao?.duracaoDadosS ?? 0).floor(),
                  ),
                  compacto: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SambaMetrica(
                  titulo: 'Força atual',
                  valor: forcaAtual == null ? '—' : '${forcaAtual.round()} N',
                  destaque: atingiu,
                  compacto: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SambaMetrica(
                  titulo: '% do alvo',
                  valor: percentual,
                  destaque: atingiu,
                  compacto: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SambaCartao(
            raio: 30,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            cor: temAlvo ? AppColors.azulEscuro : AppColors.cinzaClaro,
            onTap: _definirAlvo,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flag,
                  size: 20,
                  color: temAlvo
                      ? (atingiu ? AppColors.verdeLimao : AppColors.verdeAgua)
                      : AppColors.azulEscuro,
                ),
                const SizedBox(width: 8),
                Text(
                  temAlvo ? 'Alvo: ${alvo.round()} N' : 'Definir força-alvo',
                  style: TextStyle(
                    color: temAlvo ? AppColors.branco : AppColors.azulEscuro,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_controlador?.sessao?.quantidadeAmostras ?? 0} amostras recebidas',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.cinza, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SambaBotao(rotulo: 'Finalizar Medição', onPressed: _finalizar),
        ],
      ),
    );
  }
}
