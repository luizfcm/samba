import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

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
              const _CabecalhoSaudacao(),
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
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          28,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _BotaoAcao(
            icone: Icons.play_arrow_rounded,
            rotulo: 'Novo teste',
            destaque: true,
            onPressed: () => Navigator.pushNamed(context, '/teste'),
          ),
          const SizedBox(height: 14),
          _BotaoAcao(
            icone: Icons.folder_open,
            rotulo: 'Histórico',
            onPressed: () => Navigator.pushNamed(context, '/historico'),
          ),
          const SizedBox(height: 14),
          _BotaoAcao(
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

class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.icone,
    required this.rotulo,
    required this.onPressed,
    this.destaque = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onPressed;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final corTexto = destaque ? AppColors.branco : AppColors.azulEscuro;

    return Material(
      color: destaque ? AppColors.azulEscuro : AppColors.cinzaClaro,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: AppColors.azulEscuro, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: destaque ? 84 : 72,
          child: Row(
            children: [
              const SizedBox(width: 16),
              CircleAvatar(
                radius: destaque ? 26 : 22,
                backgroundColor: destaque
                    ? AppColors.verdeLimao
                    : AppColors.azulEscuro,
                child: Icon(
                  icone,
                  size: destaque ? 30 : 26,
                  color: destaque ? AppColors.azulEscuro : AppColors.verdeLimao,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: destaque ? 22 : 20,
                    fontWeight: destaque ? FontWeight.w700 : FontWeight.w500,
                    color: corTexto,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: corTexto),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
