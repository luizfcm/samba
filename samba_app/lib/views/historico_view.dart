import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';

class HistoricoView extends StatelessWidget {
  const HistoricoView({super.key});

  @override
  Widget build(BuildContext context) {
    // Declaração idêntica ao seu código inicial que funcionava perfeitamente
    final treinos = [
      {'data': '14 Out, 18:35', 'tipo': 'Treino de Salto', 'pico': '485 kgf'},
      {'data': '12 Out, 10:15', 'tipo': 'Isometria de Coxa', 'pico': '460 kgf'},
      {'data': '09 Out, 16:40', 'tipo': 'Treino de Salto', 'pico': '472 kgf'},
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.azulEscuro,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopo(context),
              Expanded(child: _folhaBranca(context, treinos)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.branco),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Histórico de Treinos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.branco,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // Método ajustado usando dynamic para a lista, eliminando o erro de tipo da linha 59
  Widget _folhaBranca(BuildContext context, List<dynamic> listaTreinos) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.branco,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          24,
          28,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: listaTreinos.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = listaTreinos[index] as Map<String, String>;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cinzaClaro,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.azulEscuro, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['tipo']!,
                      style: const TextStyle(
                        color: AppColors.azulEscuro,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['data']!,
                      style: const TextStyle(
                        color: AppColors.cinza,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  item['pico']!,
                  style: const TextStyle(
                    color: AppColors.azulEscuro,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}