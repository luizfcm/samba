import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../funcionalidades/medicao/aplicacao/curva_reduzida.dart';
import '../../funcionalidades/medicao/aplicacao/frequencia_media.dart';
import '../../funcionalidades/medicao/aplicacao/resumo_sessao.dart';
import '../../funcionalidades/medicao/dominio/sessao_medicao.dart';
import '../../nucleo/persistencia/banco_local.dart';
import '../core/app_colors.dart';

class ResultadoView extends StatefulWidget {
  const ResultadoView({super.key});

  @override
  State<ResultadoView> createState() => _ResultadoViewState();
}

class _ResultadoViewState extends State<ResultadoView> {
  SessaoMedicao? _sessao;
  List<FlSpot> _pontosCurva = const [];
  String _valorPico = '—';
  bool _salvando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessao != null) return;

    final sessao = ModalRoute.of(context)!.settings.arguments as SessaoMedicao;
    _sessao = sessao;
    _pontosCurva = [
      for (final ponto in reduzirCurva(sessao.amostras))
        FlSpot(ponto.tempoS, ponto.forcaN),
    ];
    _valorPico = valorDestaque(resumirSessao(sessao));
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    _salvando = true;
    final sessao = _sessao!;
    final amostras = sessao.amostras;
    try {
      await BancoLocal.salvarSessao(
        exercicio: sessao.exercicio.name,
        inicioUtc: sessao.inicio,
        frequenciaHz: frequenciaMediaHz(amostras),
        amostras: amostras,
      );
    } catch (_) {
      _salvando = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o treino.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pontosCurva = _pontosCurva;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.azulEscuro,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Text(
                  'Análise Pós-Treino',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppColors.branco,
                  ),
                ),
              ),
              Expanded(child: _folhaBranca(context, pontosCurva)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folhaBranca(BuildContext context, List<FlSpot> pontosCurva) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.branco,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 230,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.azulEscuro,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Força Estática vs Tempo (kgf/s)',
                  style: TextStyle(
                    color: AppColors.branco,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        getDrawingHorizontalLine: (value) =>
                            const FlLine(color: Colors.white12, strokeWidth: 1),
                        getDrawingVerticalLine: (value) =>
                            const FlLine(color: Colors.white12, strokeWidth: 1),
                      ),
                      titlesData: const FlTitlesData(
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: pontosCurva,
                          isCurved: true,
                          color: AppColors.verdeLimao,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.verdeLimao.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricaCard(
                  'Força de Pico',
                  _valorPico,
                  '+2.3% vs média',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricaCard(
                  'RFD Máximo',
                  '5200 kgf/s',
                  'Impulso rápido',
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeLimao,
                foregroundColor: AppColors.azulEscuro,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: _salvar,
              child: const Text(
                'SALVAR TREINO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaCard(String titulo, String valor, String subtitulo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cinzaClaro,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.azulEscuro, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.cinza,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              color: AppColors.azulEscuro,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: const TextStyle(
              color: AppColors.verdeAgua,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
