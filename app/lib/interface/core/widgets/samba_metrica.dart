import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'samba_cartao.dart';

/// Widget que mostra uma métrica com título, valor e subtítulo.
class SambaMetrica extends StatelessWidget {
  const SambaMetrica({
    super.key,
    required this.titulo,
    required this.valor,
    this.subtitulo,
    this.destaque = false,
    this.compacto = false,
  });

  final String titulo;
  final String valor;
  final String? subtitulo;
  final bool destaque;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return SambaCartao(
      cor: destaque ? AppColors.verdeLimao : AppColors.cinzaClaro,
      padding: compacto
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.cinza,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compacto ? 4 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                color: AppColors.azulEscuro,
                fontSize: compacto ? 20 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              style: const TextStyle(
                color: AppColors.verdeAgua,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
