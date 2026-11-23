import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Bateria em 4 divisões de 1/4. [nivel] vai de 0 a 4; nulo mostra a barra
/// vazia, para quando o nível ainda não é conhecido.
class BarraBateria extends StatelessWidget {
  const BarraBateria({
    super.key,
    required this.nivel,
    this.corCheia = AppColors.verdeLimao,
    this.corVazia = Colors.white24,
  });

  final int? nivel;
  final Color corCheia;
  final Color corVazia;

  @override
  Widget build(BuildContext context) {
    final preenchidos = (nivel ?? 0).clamp(0, 4);
    final cor = preenchidos == 1 ? AppColors.erro : corCheia;

    return Semantics(
      label: nivel == null
          ? 'Bateria desconhecida'
          : 'Bateria em $preenchidos de 4 divisões',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(
                width: 6,
                height: 12,
                decoration: BoxDecoration(
                  color: i < preenchidos ? cor : corVazia,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
            const SizedBox(width: 2),
            Container(
              width: 2,
              height: 6,
              decoration: BoxDecoration(
                color: corVazia,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
