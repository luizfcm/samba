import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/widgets/samba_cartao.dart';
import '../core/widgets/samba_pagina.dart';

class PerfilView extends StatelessWidget {
  const PerfilView({
    super.key,
    this.nome = 'Atleta SAMBA',
    this.email = 'atleta@exemplo.com',
    this.alturaCm = 178,
    this.pesoKg = 75,
  });

  final String nome;
  final String email;
  final double alturaCm;
  final double pesoKg;

  String _numero(double valor) {
    final texto = valor == valor.roundToDouble()
        ? valor.round().toString()
        : valor.toStringAsFixed(1).replaceAll('.', ',');
    return texto;
  }

  void _sair(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const SambaTopo(titulo: 'Perfil do Atleta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.azulEscuro,
              child: Icon(Icons.person, size: 48, color: AppColors.verdeLimao),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nome,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.azulEscuro,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 28),
          _CampoPerfil(rotulo: 'E-mail', valor: email),
          const SizedBox(height: 12),
          _CampoPerfil(rotulo: 'Altura', valor: '${_numero(alturaCm)} cm'),
          const SizedBox(height: 12),
          _CampoPerfil(rotulo: 'Massa Corporal', valor: '${_numero(pesoKg)} kg'),
          const Spacer(),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.erro,
                side: const BorderSide(color: AppColors.erro, width: 1.5),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _sair(context),
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
}

class _CampoPerfil extends StatelessWidget {
  const _CampoPerfil({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return SambaCartao(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo,
            style: const TextStyle(
              color: AppColors.cinza,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              valor,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.azulEscuro,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
