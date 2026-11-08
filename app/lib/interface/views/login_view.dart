import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.azulEscuro,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    const _CabecalhoLogo(),
                    Expanded(child: _folhaBranca(context)),
                  ],
                ),
              ),
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
      padding: EdgeInsets.fromLTRB(
        24,
        32,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
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

          // Campo E-mail
          _CampoPilula(
            controller: _emailController,
            hint: 'E-mail',
            icone: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 14),

          // Campo Senha, com botão para mostrar/ocultar
          _CampoPilula(
            controller: _senhaController,
            hint: 'Senha',
            icone: Icons.lock_outline,
            obscureText: _ocultarSenha,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _entrar(),
            sufixo: IconButton(
              tooltip: _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
              icon: Icon(
                _ocultarSenha
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.azulEscuro,
              ),
              onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
            ),
          ),

          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppColors.erro,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _erro!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.erro,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO: navegar para "Esqueci a senha".
              },
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

          // Botão Entrar
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _entrar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeLimao,
                foregroundColor: AppColors.azulEscuro,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Entrar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // Empurra "Criar conta" para o rodapé da folha.
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

          // Botão Criar conta
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                // TODO: navegar para a tela de criar conta.
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.azulEscuro,
                side: const BorderSide(color: AppColors.azulEscuro, width: 1.5),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Criar conta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Topo azul com a logo do SAMBA.
class _CabecalhoLogo extends StatelessWidget {
  const _CabecalhoLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 230,
      child: Center(
        child: Image(
          image: AssetImage('assets/logobranca.png'),
          width: 230,
          semanticLabel: 'Logotipo SAMBA',
        ),
      ),
    );
  }
}

/// Campo de texto em pílula, como nos componentes do Figma.
/// Quando for usado em outras telas, mova para `lib/core/widgets/`.
class _CampoPilula extends StatelessWidget {
  const _CampoPilula({
    required this.controller,
    required this.hint,
    required this.icone,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.sufixo,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icone;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? sufixo;

  OutlineInputBorder _borda(Color cor, double largura) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(30),
    borderSide: BorderSide(color: cor, width: largura),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      cursorColor: AppColors.azulEscuro,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.azulEscuro,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.cinza),
        prefixIcon: Icon(icone, color: AppColors.azulEscuro),
        suffixIcon: sufixo,
        filled: true,
        fillColor: AppColors.cinzaClaro,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: _borda(AppColors.azulEscuro, 1.5),
        enabledBorder: _borda(AppColors.azulEscuro, 1.5),
        focusedBorder: _borda(AppColors.azulEscuro, 2.5),
      ),
    );
  }
}
