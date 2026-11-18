import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

class PerfilView extends StatelessWidget {
  const PerfilView({super.key});

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
              'Perfil do Atleta',
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
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.azulEscuro,
            child: Icon(Icons.person, size: 48, color: AppColors.verdeLimao),
          ),
          const SizedBox(height: 12),
          const Text(
            'Atleta SAMBA',
            style: TextStyle(
              color: AppColors.azulEscuro,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 28),
          _buildCampoPerfil('E-mail', 'atleta@exemplo.com'),
          const SizedBox(height: 12),
          _buildCampoPerfil('Altura', '1.78 m'),
          const SizedBox(height: 12),
          _buildCampoPerfil('Massa Corporal', '75 kg'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Text(
                'Sair da Conta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoPerfil(String label, String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cinzaClaro,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.azulEscuro, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cinza,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              color: AppColors.azulEscuro,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
