import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/widgets/samba_botao.dart';
import '../core/widgets/samba_campo.dart';
import '../core/widgets/samba_pagina.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _entrar() {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Informe seu e-mail e sua senha');
      return;
    }

    setState(() => _erro = null);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return SambaPagina(
      cabecalho: const SambaCabecalhoLogo(),
      espacamentoSuperior: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Entre na sua conta',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppColors.azulEscuro,
            ),
          ),
          const SizedBox(height: 28),
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _entrar(),
            sufixo: SambaBotaoVerSenha(
              oculta: _ocultarSenha,
              onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
            ),
          ),
          if (_erro != null) SambaErro(_erro!),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/esquecisenha'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.azulEscuro,
                minimumSize: const Size(48, 48),
              ),
              child: const Text(
                'Esqueci a senha',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SambaBotao(
            rotulo: 'Entrar',
            onPressed: _entrar,
          ),
          const Spacer(),
          const SizedBox(height: 24),
          const Text(
            'Ainda não tem uma conta?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.cinza,
            ),
          ),
          const SizedBox(height: 10),
          SambaBotaoContorno(
            rotulo: 'Criar conta',
            onPressed: () => Navigator.pushNamed(context, '/criarconta'),
          ),
        ],
      ),
    );
  }
}
