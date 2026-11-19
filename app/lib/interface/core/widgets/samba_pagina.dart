import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';

/// Página do Samba, com cabeçalho azul-escuro e corpo branco arredondado.
class SambaPagina extends StatelessWidget {
  const SambaPagina({
    super.key,
    required this.cabecalho,
    required this.child,
    this.espacamentoSuperior = 28,
  });

  final Widget cabecalho;
  final Widget child;
  final double espacamentoSuperior;

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
                    cabecalho,
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppColors.branco,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Topo azul com título centralizado e botão de voltar à esquerda.
class SambaTopo extends StatelessWidget {
  const SambaTopo({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back, color: AppColors.branco),
            onPressed: () => Navigator.pop(context),
          ),
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

/// Cabeçalho com logotipo do Samba, centralizado e com altura ajustável.
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
