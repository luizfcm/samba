import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../funcionalidades/medicao/aplicacao/controlador_medicao.dart';
import '../../funcionalidades/medicao/aplicacao/serie_simulada.dart';
import '../../funcionalidades/medicao/dominio/exercicio.dart';
import '../../nucleo/aquisicao/fonte_forca_simulada.dart';
import '../core/app_colors.dart';

class MedicaoView extends StatefulWidget {
  const MedicaoView({super.key});

  @override
  State<MedicaoView> createState() => _MedicaoViewState();
}

class _MedicaoViewState extends State<MedicaoView> {
  Timer? _timer;
  ControladorMedicao? _controlador;
  bool _finalizando = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      setState(() {});
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
    Navigator.pushReplacementNamed(context, '/resultado', arguments: sessao);
  }

  String _formatarTempo(int segundosTotal) {
    final minutos = (segundosTotal ~/ 60).toString().padLeft(2, '0');
    final segs = (segundosTotal % 60).toString().padLeft(2, '0');
    return '$minutos:$segs';
  }

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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Text(
                  'Medição em Andamento',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppColors.branco,
                  ),
                ),
              ),
              Expanded(child: _folhaBranca(context)),
            ],
          ),
        ),
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
        32,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 230,
                height: 230,
                child: CircularProgressIndicator(
                  value: null,
                  strokeWidth: 8,
                  color: AppColors.verdeLimao,
                ),
              ),
              Container(
                width: 210,
                height: 210,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.branco,
                ),
                child: Center(
                  child: Text(
                    _formatarTempo(
                      (_controlador?.sessao?.duracaoDadosS ?? 0).floor(),
                    ),
                    style: const TextStyle(
                      color: AppColors.azulEscuro,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Capturando dados...',
            style: TextStyle(
              color: AppColors.azulEscuro,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_controlador?.sessao?.quantidadeAmostras ?? 0} amostras recebidas',
            style: const TextStyle(color: AppColors.cinza, fontSize: 14),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeLimao,
                foregroundColor: AppColors.azulEscuro,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: _finalizar,
              child: const Text(
                'FINALIZAR MEDIÇÃO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
