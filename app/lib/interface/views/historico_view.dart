import 'package:flutter/material.dart';

import '../../funcionalidades/historico/aplicacao/historico_sessoes.dart';
import '../../funcionalidades/medicao/dominio/sessao_medicao.dart';
import '../core/app_colors.dart';
import '../core/rotulos.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_cartao.dart';
import '../core/widgets/samba_pagina.dart';

class HistoricoView extends StatefulWidget {
  const HistoricoView({
    super.key,
    this.carregar = listarHistorico,
    this.abrirSessao = carregarSessao,
  });

  final Future<List<ItemHistorico>> Function() carregar;
  final Future<SessaoMedicao> Function(String id) abrirSessao;

  @override
  State<HistoricoView> createState() => _HistoricoViewState();
}

class _HistoricoViewState extends State<HistoricoView> {
  late Future<List<ItemHistorico>> _itens;
  bool _abrindo = false;

  @override
  void initState() {
    super.initState();
    _itens = widget.carregar();
  }

  void _recarregar() {
    setState(() => _itens = widget.carregar());
  }

  Future<void> _abrir(ItemHistorico item) async {
    if (_abrindo) return;
    _abrindo = true;
    try {
      final sessao = await widget.abrirSessao(item.id);
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/resultado',
        arguments: {'sessao': sessao, 'somenteLeitura': true},
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir este treino.')),
      );
    } finally {
      _abrindo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const SambaTopo(titulo: 'Histórico de Treinos'),
      rolavel: false,
      child: FutureBuilder<List<ItemHistorico>>(
        future: _itens,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.azulEscuro),
            );
          }
          if (snapshot.hasError) {
            return _MensagemCentral(
              icone: Icons.error_outline,
              titulo: 'Não foi possível carregar os treinos',
              acao: SambaBotaoContorno(
                rotulo: 'Tentar novamente',
                onPressed: _recarregar,
              ),
            );
          }
          final itens = snapshot.data ?? const <ItemHistorico>[];
          if (itens.isEmpty) {
            return const _MensagemCentral(
              icone: Icons.folder_open,
              titulo: 'Nenhum treino salvo ainda',
              descricao: 'Os treinos salvos aparecem aqui.',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: itens.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _CartaoTreino(
              item: itens[index],
              onTap: () => _abrir(itens[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CartaoTreino extends StatelessWidget {
  const _CartaoTreino({required this.item, required this.onTap});

  final ItemHistorico item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pico = item.picoN;
    return SambaCartao(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotuloExercicio(item.exercicio),
                  style: const TextStyle(
                    color: AppColors.azulEscuro,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatarDataHistorico(item.inicio),
                  style: const TextStyle(color: AppColors.cinza, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            pico == null ? '—' : '${pico.round()} N',
            style: const TextStyle(
              color: AppColors.azulEscuro,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MensagemCentral extends StatelessWidget {
  const _MensagemCentral({
    required this.icone,
    required this.titulo,
    this.descricao,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String? descricao;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: AppColors.cinza),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.azulEscuro,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (descricao != null) ...[
            const SizedBox(height: 6),
            Text(
              descricao!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cinza, fontSize: 14),
            ),
          ],
          if (acao != null) ...[const SizedBox(height: 20), acao!],
        ],
      ),
    );
  }
}
