import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/interface/views/perfil_view.dart';

void main() {
  group('PerfilView', () {
    testWidgets('mostra os dados do atleta com unidades', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerfilView(
            nome: 'Ana',
            email: 'ana@exemplo.com',
            alturaCm: 175,
            pesoKg: 70.5,
          ),
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('ana@exemplo.com'), findsOneWidget);
      expect(find.text('175 cm'), findsOneWidget);
      expect(find.text('70,5 kg'), findsOneWidget);
    });

    testWidgets('sair volta ao login e limpa a pilha', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/login': (contexto) => const Scaffold(body: Text('TELA LOGIN')),
          },
          home: const PerfilView(),
        ),
      );

      await tester.tap(find.text('Sair da Conta'));
      await tester.pumpAndSettle();

      expect(find.text('TELA LOGIN'), findsOneWidget);
    });
  });
}
