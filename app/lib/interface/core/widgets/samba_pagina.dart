import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';

/// Página com cabeçalho azul e folha branca arredondada, que ocupa o resto da
class SambaPagina extends StatelessWidget {
  const SambaPagina({
    super.key,
    required this.cabecalho,
    required this.child,
    this.espacamentoSuperior = 28,
    this.redimensionarComTeclado = true,
    this.rolavel = true,
  });

  final Widget cabecalho;
  final Widget child;
  final double espacamentoSuperior;
  final bool redimensionarComTeclado;
  final bool rolavel;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: redimensionarComTeclado,
        backgroundColor: AppColors.azulEscuro,
        body: SafeArea(
          bottom: false,
          child: rolavel
              ? CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _estrutura(context),
                    ),
                  ],
                )
              : _estrutura(context),
        ),
      ),
    );
  }

  Widget _estrutura(BuildContext context) {
    return Column(
      children: [
        cabecalho,
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.branco,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              espacamentoSuperior,
              24,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Topo com botão de voltar (sem círculo) e título centralizado.
class SambaTopo extends StatelessWidget {
  const SambaTopo({
    super.key,
    required this.titulo,
    this.mostrarVoltar = true,
  });

  final String titulo;

  /// Com falso, o botão de voltar some e o título continua centralizado.
  final bool mostrarVoltar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          if (mostrarVoltar)
            IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back, color: AppColors.branco),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.branco,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Topo azul com a logo do SAMBA.
class SambaCabecalhoLogo extends StatelessWidget {
  const SambaCabecalhoLogo({super.key, this.altura = 230});

  final double altura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      child: const Center(
        child: Image(
          image: AssetImage('assets/logobranca.png'),
          width: 230,
          semanticLabel: 'Logotipo SAMBA',
        ),
      ),
    );
  }
}
