import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';

class ResultadoView extends StatelessWidget {
  const ResultadoView({super.key});

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> pontosCurva = const [
      FlSpot(0.0, 0),
      FlSpot(0.1, 80),
      FlSpot(0.3, 210),
      FlSpot(0.55, 485),
      FlSpot(0.8, 180),
      FlSpot(1.0, 120),
      FlSpot(1.2, 0),
    ];

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
                        getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
                        getDrawingVerticalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
                      ),
                      titlesData: const FlTitlesData(
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                child: _buildMetricaCard('Força de Pico', '485 kgf', '+2.3% vs média'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricaCard('RFD Máximo', '5200 kgf/s', 'Impulso rápido'),
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
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              },
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
          Text(titulo, style: const TextStyle(color: AppColors.cinza, fontSize: 12, fontWeight: FontWeight.w500)),
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
            style: const TextStyle(color: AppColors.verdeAgua, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}