import 'package:flutter/material.dart';

import '../app_colors.dart';

OutlineInputBorder _borda(Color cor, double largura) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(30),
  borderSide: BorderSide(color: cor, width: largura),
);

/// Campo de texto com ícone à esquerda, borda azul-escura e fundo cinza-claro.
class SambaCampo extends StatelessWidget {
  const SambaCampo({
    super.key,
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

/// Botão de alternar visibilidade da senha, com ícone de olho.
class SambaBotaoVerSenha extends StatelessWidget {
  const SambaBotaoVerSenha({
    super.key,
    required this.oculta,
    required this.onPressed,
  });

  final bool oculta;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: oculta ? 'Mostrar senha' : 'Ocultar senha',
      icon: Icon(
        oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.azulEscuro,
      ),
      onPressed: onPressed,
    );
  }
}

/// Mensagem de erro em vermelho, com ícone de alerta à esquerda.
class SambaErro extends StatelessWidget {
  const SambaErro(this.mensagem, {super.key});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.erro),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.erro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
