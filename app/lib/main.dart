import 'package:flutter/material.dart';

import 'interface/core/app_colors.dart';
import 'interface/views/historico_view.dart';
import 'interface/views/home_view.dart';
import 'interface/views/login_view.dart';
import 'interface/views/medicao_view.dart';
import 'interface/views/perfil_view.dart';
import 'interface/views/resultado_view.dart';
import 'interface/views/splash_view.dart';
import 'interface/views/teste_view.dart';

void main() {
  runApp(const AplicativoSamba());
}

class AplicativoSamba extends StatelessWidget {
  const AplicativoSamba({super.key});

  @override
  Widget build(BuildContext contexto) {
    return MaterialApp(
      title: 'SAMBA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.azulEscuro,
        primaryColor: AppColors.verdeLimao,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.verdeLimao,
          secondary: AppColors.verdeAgua,
          surface: AppColors.azul,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (contexto) => const SplashView(),
        '/login': (contexto) => const LoginView(),
        '/home': (contexto) => const HomeView(),
        '/teste': (contexto) => const TesteView(),
        '/medicao': (contexto) => const MedicaoView(),
        '/resultado': (contexto) => const ResultadoView(),
        '/historico': (contexto) => const HistoricoView(),
        '/perfil': (contexto) => const PerfilView(),
      },
    );
  }
}
