import 'package:flutter/material.dart';

import '../../funcionalidades/conexao/aplicacao/conexao_equipamento.dart';
import '../core/app_colors.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_pagina.dart';
import '../core/widgets/status_conexao.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, this.conexao});

  /// Nulo usa [ConexaoEquipamento.instancia]. Existe para testes.
  final ConexaoEquipamento? conexao;

  @override
  Widget build(BuildContext context) {
    final c = conexao ?? ConexaoEquipamento.instancia;

    return SambaPagina(
      cabecalho: _CabecalhoHome(
        conexao: c,
        onPerfil: () => Navigator.pushNamed(context, '/perfil'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BotaoAcao(
            icone: Icons.play_arrow_rounded,
            rotulo: 'Novo teste',
            destaque: true,
            onPressed: () => Navigator.pushNamed(context, '/teste'),
          ),
          _DicaConexao(conexao: c),
          const SizedBox(height: 14),
          BotaoAcao(
            icone: Icons.folder_open,
            rotulo: 'Histórico',
            onPressed: () => Navigator.pushNamed(context, '/historico'),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoHome extends StatelessWidget {
  const _CabecalhoHome({required this.conexao, required this.onPerfil});

  final ConexaoEquipamento conexao;
  final VoidCallback onPerfil;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Image(
                image: AssetImage('assets/logobranca.png'),
                width: 110,
                semanticLabel: 'Logotipo SAMBA',
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Perfil',
                onPressed: onPerfil,
                icon: const Icon(Icons.person_outline),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.branco,
                  minimumSize: const Size(46, 46),
                  side: const BorderSide(color: Color(0x80FFFFFF), width: 1.5),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Olá, atleta',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.branco,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'O que vamos medir hoje?',
            style: TextStyle(fontSize: 14, color: AppColors.cinzaClaro),
          ),
          const SizedBox(height: 16),
          PilulaConexao(conexao: conexao),
        ],
      ),
    );
  }
}

class _DicaConexao extends StatelessWidget {
  const _DicaConexao({required this.conexao});

  final ConexaoEquipamento conexao;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: conexao,
      builder: (context, _) {
        final conectado = conexao.conectado;
        final cor = conectado ? AppColors.verdeAgua : AppColors.cinza;
        return Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Row(
            children: [
              Icon(
                conectado ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: cor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  conectado
                      ? 'Equipamento conectado'
                      : 'Conecte o equipamento antes de iniciar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
