import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';

class MedicaoView extends StatefulWidget {
  const MedicaoView({super.key});

  @override
  State<MedicaoView> createState() => _MedicaoViewState();
}

class _MedicaoViewState extends State<MedicaoView> {
  int _segundos = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _segundos++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                    _formatarTempo(_segundos),
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
              onPressed: () {
                _timer?.cancel();
                Navigator.pushReplacementNamed(context, '/resultado');
              },
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