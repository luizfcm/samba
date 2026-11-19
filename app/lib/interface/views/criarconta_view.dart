import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/validacoes.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_campo.dart';
import '../core/widgets/samba_pagina.dart';

class CriarContaView extends StatefulWidget {
  const CriarContaView({super.key});

  @override
  State<CriarContaView> createState() => _CriarContaViewState();
}

class _CriarContaViewState extends State<CriarContaView> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _ocultarSenha = true;
  bool _criando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  String? _validar() {
    if (_nomeController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _senhaController.text.isEmpty ||
        _confirmarController.text.isEmpty) {
      return 'Preencha todos os campos';
    }
    if (!emailValido(_emailController.text)) return 'Informe um e-mail válido';
    if (_senhaController.text.length < tamanhoMinimoSenha) {
      return 'A senha deve ter pelo menos $tamanhoMinimoSenha caracteres';
    }
    if (_senhaController.text != _confirmarController.text) {
      return 'As senhas não são iguais';
    }
    return null;
  }

  Future<void> _criarConta() async {
    final erro = _validar();
    setState(() => _erro = erro);
    if (erro != null) return;

    setState(() => _criando = true);
    // TODO(autenticação): chamar o cadastro do serviço de autenticação.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() => _criando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conta criada. Entre com seu e-mail.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const SambaTopo(titulo: 'Cadastro'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Crie sua conta',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppColors.azulEscuro,
            ),
          ),
          const SizedBox(height: 24),
          SambaCampo(
            controller: _nomeController,
            hint: 'Nome',
            icone: Icons.person_outline,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 14),
          SambaCampo(
            controller: _emailController,
            hint: 'E-mail',
            icone: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 14),
          SambaCampo(
            controller: _senhaController,
            hint: 'Senha',
            icone: Icons.lock_outline,
            obscureText: _ocultarSenha,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            sufixo: SambaBotaoVerSenha(
              oculta: _ocultarSenha,
              onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
            ),
          ),
          const SizedBox(height: 14),
          SambaCampo(
            controller: _confirmarController,
            hint: 'Confirmar senha',
            icone: Icons.lock_outline,
            obscureText: _ocultarSenha,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _criarConta(),
          ),
          if (_erro != null) SambaErro(_erro!),
          const Spacer(),
          const SizedBox(height: 24),
          SambaBotao(
            rotulo: 'Criar conta',
            rotuloCarregando: 'Criando...',
            carregando: _criando,
            onPressed: _criarConta,
          ),
        ],
      ),
    );
  }
}

