import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/validacoes.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_campo.dart';
import '../core/widgets/samba_pagina.dart';

class EsqueciSenhaView extends StatefulWidget {
  const EsqueciSenhaView({super.key});

  @override
  State<EsqueciSenhaView> createState() => _EsqueciSenhaViewState();
}

class _EsqueciSenhaViewState extends State<EsqueciSenhaView> {
  final _emailController = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    if (!emailValido(email)) {
      setState(() => _erro = 'Informe um e-mail válido');
      return;
    }

    setState(() {
      _erro = null;
      _enviando = true;
    });
    // TODO(autenticação): pedir ao serviço de autenticação o link de recuperação de senha para este e-mail.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _enviando = false;
      _enviado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const SambaTopo(titulo: 'Recuperar senha'),
      child: _enviado ? _confirmacao(context) : _formulario(),
    );
  }

  Widget _formulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Informe o e-mail da sua conta. Enviaremos um link para você criar '
          'uma nova senha.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.cinza),
        ),
        const SizedBox(height: 24),
        SambaCampo(
          controller: _emailController,
          hint: 'E-mail',
          icone: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _enviar(),
        ),
        if (_erro != null) SambaErro(_erro!),
        const Spacer(),
        const SizedBox(height: 24),
        SambaBotao(
          rotulo: 'Enviar link',
          rotuloCarregando: 'Enviando...',
          carregando: _enviando,
          onPressed: _enviar,
        ),
      ],
    );
  }

  Widget _confirmacao(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: AppColors.azulEscuro,
        ),
        const SizedBox(height: 20),
        const Text(
          'Verifique seu e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: AppColors.azulEscuro,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Se existir uma conta para ${_emailController.text.trim()}, você '
          'receberá um link para redefinir a senha.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: AppColors.cinza),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        SambaBotao(
          rotulo: 'Voltar ao login',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

