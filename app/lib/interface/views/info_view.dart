import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_campo.dart';
import '../core/widgets/samba_pagina.dart';

class InfoView extends StatefulWidget {
  const InfoView({super.key});

  @override
  State<InfoView> createState() => _InfoViewState();
}

class _InfoViewState extends State<InfoView> {
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _nascimentoController = TextEditingController();

  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _pesoController.dispose();
    _alturaController.dispose();
    _nascimentoController.dispose();
    super.dispose();
  }

  String? _validar() {
    final pesoTexto = _pesoController.text.trim().replaceAll(',', '.');
    final alturaTexto = _alturaController.text.trim().replaceAll(',', '.');

    if (pesoTexto.isEmpty || alturaTexto.isEmpty) {
      return 'Preencha seu peso e altura para continuar';
    }

    final peso = double.tryParse(pesoTexto);
    if (peso == null || peso < 20 || peso > 300) {
      return 'Informe um peso válido em kg (ex: 70,5)';
    }

    final altura = double.tryParse(alturaTexto);
    if (altura == null || altura < 100 || altura > 250) {
      return 'Informe uma altura válida em cm (ex: 175)';
    }

    return null;
  }

  Future<void> _concluirCadastro() async {
    final erro = _validar();
    setState(() => _erro = erro);
    if (erro != null) return;

    setState(() => _salvando = true);

    // Dados recebidos da tela CriarContaView (caso queira salvar tudo junto com o Lucas)
    //final dadosConta =
    //    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    //final pesoKg = double.parse(_pesoController.text.trim().replaceAll(',', '.'));
    //final alturaCm = double.parse(_alturaController.text.trim().replaceAll(',', '.'));

    // TODO(persistência): salvar perfil do atleta (dadosConta, pesoKg, alturaCm) com o Lucas.
    //await Future<void>.delayed(const Duration(milliseconds: 600));
    //if (!mounted) return;

    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastro concluído! Entre com seu e-mail.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const SambaTopo(titulo: 'Cadastro'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dados do Atleta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.azulEscuro,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.azulEscuro,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Passo 2 de 2',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.verdeLimao,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Essas informações são essenciais para calcular a potência e os parâmetros dos seus saltos..',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.cinza,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 24),
          SambaCampo(
            controller: _pesoController,
            hint: 'Peso (kg) — ex: 72,5',
            icone: Icons.monitor_weight_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          SambaCampo(
            controller: _alturaController,
            hint: 'Altura (cm) — ex: 175',
            icone: Icons.height_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          SambaCampo(
            controller: _nascimentoController,
            hint: 'Data de nascimento (opcional)',
            icone: Icons.cake_outlined,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _concluirCadastro(),
          ),
          if (_erro != null) SambaErro(_erro!),
          const Spacer(),
          const SizedBox(height: 24),
          SambaBotao(
            rotulo: 'Concluir Cadastro',
            rotuloCarregando: 'Salvando...',
            carregando: _salvando,
            onPressed: _concluirCadastro,
          ),
        ],
      ),
    );
  }
}