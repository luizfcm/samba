import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Botão do Samba, com fundo verde-limão, texto azul-escuro e cantos arredondados.
class SambaBotao extends StatelessWidget {
  const SambaBotao({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.carregando = false,
    this.rotuloCarregando,
    this.estilo = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final bool carregando;
  final String? rotuloCarregando;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: carregando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verdeLimao,
          foregroundColor: AppColors.azulEscuro,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: carregando
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.azulEscuro,
                    ),
                  ),
                  if (rotuloCarregando != null) ...[
                    const SizedBox(width: 12),
                    Text(rotuloCarregando!, style: estilo),
                  ],
                ],
              )
            : Text(rotulo, style: estilo),
      ),
    );
  }
}

/// Botão de contorno azul-escuro, com fundo transparente e cantos arredondados.
class SambaBotaoContorno extends StatelessWidget {
  const SambaBotaoContorno({
    super.key,
    required this.rotulo,
    required this.onPressed,
  });

  final String rotulo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azulEscuro,
          side: const BorderSide(color: AppColors.azulEscuro, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: Text(
          rotulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}


class BotaoAcao extends StatelessWidget {
  const BotaoAcao({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.onPressed,
    this.destaque = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onPressed;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final corTexto = destaque ? AppColors.branco : AppColors.azulEscuro;

    return Material(
      color: destaque ? AppColors.azulEscuro : AppColors.cinzaClaro,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: AppColors.azulEscuro, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: destaque ? 84 : 72,
          child: Row(
            children: [
              const SizedBox(width: 16),
              CircleAvatar(
                radius: destaque ? 26 : 22,
                backgroundColor: destaque
                    ? AppColors.verdeLimao
                    : AppColors.azulEscuro,
                child: Icon(
                  icone,
                  size: destaque ? 30 : 26,
                  color: destaque ? AppColors.azulEscuro : AppColors.verdeLimao,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: destaque ? 22 : 20,
                    fontWeight: destaque ? FontWeight.w700 : FontWeight.w500,
                    color: corTexto,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: corTexto),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
