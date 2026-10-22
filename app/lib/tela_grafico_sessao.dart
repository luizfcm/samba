
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'nucleo/persistencia/banco_local.dart';

class TelaGraficoSessao extends StatefulWidget {
  const TelaGraficoSessao({
    super.key,
    required this.sessaoId,
  });

  final String sessaoId;

  @override
  State<TelaGraficoSessao> createState() =>
      _TelaGraficoSessaoState();
}

class _TelaGraficoSessaoState
    extends State<TelaGraficoSessao> {

  late final Future<List<Map<String, Object?>>> _consulta;

  @override
  void initState() {
    super.initState();

    // Busca os dados da sessão no SQLite.
    _consulta = BancoLocal.listarAmostrasDaSessao(
      widget.sessaoId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráfico de força'),
      ),

      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _consulta,

        builder: (context, snapshot) {

          // Enquanto consulta o banco.
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Caso ocorra algum erro.
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar dados: ${snapshot.error}',
              ),
            );
          }

          final dados = snapshot.data ?? [];

          if (dados.isEmpty) {
            return const Center(
              child: Text('Nenhuma amostra encontrada.'),
            );
          }

          // Converte os registros do SQLite em pontos.
          final pontos = dados.map((amostra) {
            final tempoS =
                (amostra['timestamp_us'] as num)
                    .toDouble() / 1000000.0;

            final forcaN =
                (amostra['forca_n'] as num).toDouble();

            return FlSpot(tempoS, forcaN);
          }).toList();

          // Identifica a maior força registrada.
          final forcaMaxima = pontos.fold<double>(
            0,
            (maximo, ponto) =>
                ponto.y > maximo ? ponto.y : maximo,
          );

          final limiteY =
              forcaMaxima > 0 ? forcaMaxima * 1.1 : 1.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  'Força em função do tempo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Amostras carregadas: ${dados.length}',
                ),

                Text(
                  'Força máxima: '
                  '${forcaMaxima.toStringAsFixed(1)} N',
                ),

                const SizedBox(height: 30),

                const Center(
                  child: Text('Força (N)'),
                ),

                const SizedBox(height: 12),

                // Área do gráfico.
                SizedBox(
                  height: 320,

                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: pontos.last.x > 0
                          ? pontos.last.x
                          : 1,
                      minY: 0,
                      maxY: limiteY,

                      // Grade do gráfico.
                      gridData: const FlGridData(
                        show: true,
                      ),

                      // Borda do gráfico.
                      borderData: FlBorderData(
                        show: true,
                      ),

                      // Configuração dos eixos.
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false),
                        ),

                        rightTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false),
                        ),
                      ),

                      // Linha de força.
                      lineBarsData: [
                        LineChartBarData(
                          spots: pontos,
                          isCurved: false,
                          barWidth: 2,
                          color: Colors.deepPurple,

                          dotData: const FlDotData(
                            show: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text('Tempo (s)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
