import 'package:flutter/material.dart';

import '../../funcionalidades/conexao/aplicacao/conexao_equipamento.dart';
import '../../funcionalidades/medicao/dominio/exercicio.dart';
import '../core/app_colors.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_cartao.dart';
import '../core/widgets/samba_pagina.dart';
import '../core/widgets/status_conexao.dart';
import '../core/widgets/samba_campo.dart';
import '../core/widgets/barra_bateria.dart';

class TesteView extends StatefulWidget {
  const TesteView({super.key, this.conexao});

  final ConexaoEquipamento? conexao;

  @override
  State<TesteView> createState() => _TesteViewState();
}

class _TesteViewState extends State<TesteView> {
  String tipoExercicio = 'Remada - Isometria';
  bool _tentouIniciar = false; 
  
  ConexaoEquipamento get _conexao => widget.conexao ?? ConexaoEquipamento.instancia;

  Exercicio get _exercicio => switch (tipoExercicio) {
    'Salto Vertical' => Exercicio.salto,
    'Extensora - Isometria' => Exercicio.extensora,
    _ => Exercicio.remada,
  };

  void _iniciar() {
    if (!_conexao.conectado) {
      setState(() => _tentouIniciar = true);
      mostrarPainelConexao(context, conexao: _conexao);
      return;
    }
    Navigator.pushNamed(context, '/medicao', arguments: _exercicio);
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      rolavel: false,
      cabecalho: const SambaTopo(titulo: 'Novo Teste'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CartaoConexao(
            conexao: _conexao,
            onTap: () => mostrarPainelConexao(context, conexao: _conexao),
          ),
          const SizedBox(height: 28),
          const Text( 'Selecione a Modalidade',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.azulEscuro,
            ),
          ),
          const SizedBox(height: 14),
          _opcaoModalidade('Remada - Isometria'),
          const SizedBox(height: 10),
          _opcaoModalidade('Extensora - Isometria'),
          const SizedBox(height: 10),
          _opcaoModalidade('Salto Vertical'),
          const SizedBox(height: 10),
          _opcaoModalidade('Levantamento Terra'),
          const Spacer(),

          ListenableBuilder(
            listenable: _conexao,
            builder: (context, _) {
              final bloqueado = _tentouIniciar && !_conexao.conectado;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bloqueado)
                    const SambaErro('Conecte o equipamento para iniciar'),
                  SambaBotao(rotulo: 'Iniciar Medição', onPressed: _iniciar),
                ],
              );
            },
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

class _CartaoConexao extends StatelessWidget {
  const _CartaoConexao({required this.conexao, required this.onTap});

  final ConexaoEquipamento conexao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: conexao,
      builder: (context, _) {
        final conectado = conexao.conectado;
        final procurando = conexao.estado == EstadoConexao.procurando;

        final String subtitulo;
        if (conectado) {
          subtitulo = conexao.nomeDispositivo ?? 'Conectado';
        } else if (procurando) {
          subtitulo = 'Procurando equipamento...';
        } else {
          subtitulo = 'Toque para conectar';
        }

        return SambaCartao(
          cor: conectado ? AppColors.azulEscuro : AppColors.cinzaClaro,
          onTap: onTap,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    conectado ? AppColors.verdeLimao : AppColors.cinza,
                child: procurando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.branco,
                        ),
                      )
                    : Icon(
                        conectado
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color:
                            conectado ? AppColors.azulEscuro : AppColors.branco,
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
                        color:
                            conectado ? AppColors.cinzaClaro : AppColors.cinza,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      subtitulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            conectado ? AppColors.branco : AppColors.azulEscuro,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              if (conectado)
                BarraBateria(nivel: conexao.bateriaNivel)
              else
                const Icon(Icons.power_settings_new, color: AppColors.cinza),
            ],
          ),
        );
      },
    );
  }
}
