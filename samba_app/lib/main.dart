import 'package:flutter/material.dart';
import 'core/app_colors.dart';
import 'views/splash_view.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/teste_view.dart';
import 'views/medicao_view.dart';
import 'views/resultado_view.dart';
import 'views/historico_view.dart';
import 'views/perfil_view.dart';

void main() {
  runApp(const SambaApp());
}

class SambaApp extends StatelessWidget {
  const SambaApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        '/': (context) => const SplashView(),
        '/login': (context) => const LoginView(),
        '/home': (context) => const HomeView(),
        '/teste': (context) => const TesteView(),
        '/medicao': (context) => const MedicaoView(),
        '/resultado': (context) => const ResultadoView(),
        '/historico': (context) => const HistoricoView(),
        '/perfil': (context) => const PerfilView(),
      },
    );
  }
} 