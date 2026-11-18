import 'package:flutter/material.dart';
import '../app_colors.dart';

class SambaBotao extends StatelessWidget {
  const SambaBotao({
    super.key,
    required this.rotulo,
    required this.onPressed,
  });

  final String rotulo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verdeLimao,
          foregroundColor: AppColors.azulEscuro,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: Text(
          rotulo,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}