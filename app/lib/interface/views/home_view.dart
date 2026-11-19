import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_pagina.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const _CabecalhoSaudacao(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BotaoAcao(
            icone: Icons.play_arrow_rounded,
            rotulo: 'Novo teste',
            destaque: true,
            onPressed: () => Navigator.pushNamed(context, '/teste'),
          ),
          const SizedBox(height: 14),
          BotaoAcao(
            icone: Icons.folder_open,
            rotulo: 'Histórico',
            onPressed: () => Navigator.pushNamed(context, '/historico'),
          ),
          const SizedBox(height: 14),
          BotaoAcao(
            icone: Icons.person_outline,
            rotulo: 'Perfil',
            onPressed: () => Navigator.pushNamed(context, '/perfil'),
          ),
        ],
      ),
    );
  }
} 

class _CabecalhoSaudacao extends StatelessWidget {
  const _CabecalhoSaudacao();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, atleta',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.branco,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'O que vamos medir hoje?',
                style: TextStyle(fontSize: 14, color: AppColors.cinzaClaro),
              ),
            ],
          ),
          Image(
            image: AssetImage('assets/logobranca.png'),
            width: 110,
            semanticLabel: 'Logotipo SAMBA',
          ),
        ],
      ),
    );
  }
}