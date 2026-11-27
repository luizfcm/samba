import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Cartão do Samba, com borda azul-escura, fundo cinza-claro e cantos arredondados.
class SambaCartao extends StatelessWidget {
  const SambaCartao({
    super.key,
    required this.child,
    this.onTap,
    this.cor = AppColors.cinzaClaro,
    this.raio = 20,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color cor;
  final double raio;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final borda = BorderRadius.circular(raio);
    return Material(
      color: cor,
      borderRadius: borda,
      child: InkWell(
        borderRadius: borda,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borda,
            border: Border.all(color: AppColors.azulEscuro, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
