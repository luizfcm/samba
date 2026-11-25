import 'package:flutter/material.dart';

import '../../../funcionalidades/conexao/aplicacao/conexao_equipamento.dart';
import '../app_colors.dart';
import 'samba_botao.dart';
import 'barra_bateria.dart';

class PilulaConexao extends StatelessWidget {
  const PilulaConexao({super.key, this.conexao});
  final ConexaoEquipamento? conexao;

  @override
  Widget build(BuildContext context) {
    final c = conexao ?? ConexaoEquipamento.instancia;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final nivel = c.bateriaNivel;
        final bateriaBaixa = c.conectado && nivel != null && nivel <= 1;

        return Material(
          color: Colors.white12,
          shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => mostrarPainelConexao(context, conexao: c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _icone(c.estado),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _texto(c),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.branco,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (c.conectado) ...[
                    const SizedBox(width: 10),
                    BarraBateria(nivel: nivel),
                  ],
                  if (bateriaBaixa) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Bateria baixa',
                      style: TextStyle(
                        color: Color(0xFFFF8A80),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _texto(ConexaoEquipamento c) {
    if (c.estado == EstadoConexao.procurando) return 'Procurando...';
    if (c.conectado) return c.nomeDispositivo ?? 'Conectado';
    return 'Equipamento desconectado';
  }

  static Widget _icone(EstadoConexao estado) {
    if (estado == EstadoConexao.procurando) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.branco,
        ),
      );
    }
    if (estado == EstadoConexao.conectado) {
      return const Icon(
        Icons.bluetooth_connected,
        size: 18,
        color: AppColors.verdeLimao,
      );
    }
    return const Icon(Icons.bluetooth_disabled, size: 18, color: Colors.white70);
  }
}

/// Abre o painel de conexão com o equipamento.
Future<void> mostrarPainelConexao(
  BuildContext context, {
  ConexaoEquipamento? conexao,
}) {
  final c = conexao ?? ConexaoEquipamento.instancia;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.branco,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (contexto) => _PainelConexao(conexao: c),
  );
}

class _PainelConexao extends StatelessWidget {
  const _PainelConexao({required this.conexao});

  final ConexaoEquipamento conexao;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: conexao,
      builder: (contexto, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(contexto).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Equipamento',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.azulEscuro,
                ),
              ),
              const SizedBox(height: 16),
              _resumo(),
              const SizedBox(height: 24),
              ..._botoes(contexto),
            ],
          ),
        );
      },
    );
  }

  Widget _resumo() {
    final Widget conteudo;
    switch (conexao.estado) {
      case EstadoConexao.procurando:
        conteudo = const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.azulEscuro,
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Procurando equipamento SAMBA', style: _estilo)),
          ],
        );
      case EstadoConexao.conectado:
        final percentual = conexao.bateriaPercentual;
        conteudo = Row(
          children: [
            const Icon(
              Icons.bluetooth_connected,
              color: AppColors.azulEscuro,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(conexao.nomeDispositivo ?? 'Conectado', style: _estilo),
            ),
            BarraBateria(
              nivel: conexao.bateriaNivel,
              corCheia: AppColors.verdeAgua,
              corVazia: Colors.black12,
            ),
            if (percentual != null) ...[
              const SizedBox(width: 8),
              Text('$percentual%', style: _estilo),
            ],
          ],
        );
      case EstadoConexao.desconectado:
        conteudo = const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: AppColors.cinza),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhum equipamento. Ligue-o e toque em procurar.',
                style: TextStyle(fontSize: 14, color: AppColors.cinza),
              ),
            ),
          ],
        );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cinzaClaro,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.azulEscuro, width: 1.5),
      ),
      child: conteudo,
    );
  }

  List<Widget> _botoes(BuildContext contexto) {
    switch (conexao.estado) {
      case EstadoConexao.desconectado:
        return [
          SambaBotao(
            rotulo: 'Procurar equipamento',
            onPressed: conexao.conectar,
          ),
        ];
      case EstadoConexao.procurando:
        return [
          SambaBotaoContorno(rotulo: 'Cancelar', onPressed: conexao.desconectar),
        ];
      case EstadoConexao.conectado:
        return [
          SambaBotao(
            rotulo: 'Concluir',
            onPressed: () => Navigator.pop(contexto),
          ),
          const SizedBox(height: 10),
          SambaBotaoContorno(
            rotulo: 'Desconectar',
            onPressed: conexao.desconectar,
          ),
        ];
    }
  }

  static const _estilo = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.azulEscuro,
  );
}
