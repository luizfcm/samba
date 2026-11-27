import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Gráfico de força ao vivo, com eixo x em segundos e eixo y em newtons. 
class GraficoForcaAoVivo extends StatelessWidget {
  const GraficoForcaAoVivo({
    super.key,
    required this.pontos,
    this.janelaS = 5,
    this.alvoN,
    this.destacar = false,
  });

  final List<FlSpot> pontos;
  final double janelaS;
  final double? alvoN;
  final bool destacar;

  @override
  Widget build(BuildContext context) {
    final xFim = pontos.isEmpty ? 0.0 : pontos.last.x;
    final minX = xFim > janelaS ? xFim - janelaS : 0.0;
    final maxX = xFim > janelaS ? xFim : janelaS;

    var maiorForca = 0.0;
    for (final ponto in pontos) {
      maiorForca = math.max(maiorForca, ponto.y);
    }
    final topo = math.max(maiorForca, alvoN ?? 0);
    final maxY = topo <= 0 ? 100.0 : (topo * 1.15 / 100).ceil() * 100.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.azulEscuro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Força × tempo (N) · últimos ${janelaS.round()} s',
            style: const TextStyle(
              color: AppColors.branco,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white12, strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      const FlLine(color: Colors.white12, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (alvoN != null)
                      HorizontalLine(
                        y: alvoN!,
                        color: AppColors.verdeAgua,
                        strokeWidth: 2,
                        dashArray: [8, 4],
                      ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: pontos,
                    isCurved: false,
                    color: destacar ? AppColors.verdeLimao : AppColors.branco,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class GraficoForcaResultado extends StatelessWidget {
  const GraficoForcaResultado({
    super.key,
    required this.pontos,
    this.alvoN,
    this.altura = 230,
  });

  final List<FlSpot> pontos;
  final double? alvoN;
  final double altura;

  static const _estiloRotulo = TextStyle(color: Colors.white70, fontSize: 11);

  Widget _rotulo(double valor, TitleMeta meta) {
    final passos = valor / meta.appliedInterval;
    if ((passos - passos.round()).abs() > 0.001) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(valor.round().toString(), style: _estiloRotulo),
    );
  }

  @override
  Widget build(BuildContext context) {
    var maiorForca = 0.0;
    for (final ponto in pontos) {
      if (ponto.y > maiorForca) maiorForca = ponto.y;
    }
    final topo = alvoN != null && alvoN! > maiorForca ? alvoN! : maiorForca;
    final maxY = topo <= 0 ? 100.0 : (topo * 1.1 / 100).ceil() * 100.0;
    final maxX = pontos.isEmpty || pontos.last.x <= 0 ? 1.0 : pontos.last.x;

    return Container(
      height: altura,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.azulEscuro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Força × tempo (N)',
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
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.branco,
                    getTooltipItems: (pontosTocados) => [
                      for (final ponto in pontosTocados)
                        LineTooltipItem(
                          '${ponto.y.toStringAsFixed(1)} N\n'
                          '${ponto.x.toStringAsFixed(1)} s',
                          const TextStyle(
                            color: AppColors.azulEscuro,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white12, strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      const FlLine(color: Colors.white12, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: _rotulo,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: _rotulo,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (alvoN != null)
                      HorizontalLine(
                        y: alvoN!,
                        color: AppColors.verdeAgua,
                        strokeWidth: 2,
                        dashArray: [8, 4],
                      ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: pontos,
                    isCurved: false,
                    color: AppColors.verdeLimao,
                    barWidth: 3,
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
    );
  }
}