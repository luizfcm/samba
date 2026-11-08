import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

class TesteView extends StatefulWidget {
  const TesteView({super.key});

  @override
  State<TesteView> createState() => _TesteViewState();
}

class _TesteViewState extends State<TesteView> {
  String tipoExercicio = 'Isometria';
  bool bluetoothConectado = false; // Estado do botão Bluetooth

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.azulEscuro,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopo(context),
              Expanded(child: _folhaBranca(context)),
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
              'Novo Teste',
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

  Widget _folhaBranca(BuildContext context) {
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
          // Botão Interativo de Conexão Bluetooth
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Material(
              color: bluetoothConectado
                  ? AppColors.azulEscuro
                  : AppColors.cinzaClaro,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  setState(() {
                    bluetoothConectado = !bluetoothConectado;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.azulEscuro, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: bluetoothConectado
                            ? AppColors.verdeLimao
                            : AppColors.cinza,
                        child: Icon(
                          bluetoothConectado
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: bluetoothConectado
                              ? AppColors.azulEscuro
                              : AppColors.branco,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status do Dispositivo',
                              style: TextStyle(
                                color: bluetoothConectado
                                    ? AppColors.cinzaClaro
                                    : AppColors.cinza,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              bluetoothConectado
                                  ? 'Bluetooth Conectado'
                                  : 'Toque para conectar',
                              style: TextStyle(
                                color: bluetoothConectado
                                    ? AppColors.branco
                                    : AppColors.azulEscuro,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        bluetoothConectado
                            ? Icons.check_circle
                            : Icons.power_settings_new,
                        color: bluetoothConectado
                            ? AppColors.verdeLimao
                            : AppColors.cinza,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Selecione a Modalidade',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.azulEscuro,
            ),
          ),
          const SizedBox(height: 14),
          _opcaoModalidade('Isometria'),
          const SizedBox(height: 10),
          _opcaoModalidade('Salto Vertical'),
          const Spacer(),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/medicao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeLimao,
                foregroundColor: AppColors.azulEscuro,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'INICIAR MEDIÇÃO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcaoModalidade(String valor) {
    final selecionado = tipoExercicio == valor;
    return InkWell(
      onTap: () => setState(() => tipoExercicio = valor),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.azulEscuro : AppColors.cinzaClaro,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.azulEscuro, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selecionado ? AppColors.branco : AppColors.azulEscuro,
              ),
            ),
            Icon(
              selecionado ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selecionado ? AppColors.verdeLimao : AppColors.azulEscuro,
            ),
          ],
        ),
      ),
    );
  }
}
