import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/interface/views/medicao_view.dart';

void main() {
  group('MedicaoView', () {
    testWidgets('mostra as amostras e entrega a sessão finalizada', (
      tester,
    ) async {
      Object? argumentoResultado;
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/medicao': (contexto) => const MedicaoView()},
          onGenerateRoute: (configuracao) {
            argumentoResultado = configuracao.arguments;
            return MaterialPageRoute(builder: (contexto) => const Text('fim'));
          },
          home: Builder(
            builder: (contexto) => TextButton(
              onPressed: () => Navigator.pushNamed(
                contexto,
                '/medicao',
                arguments: Exercicio.remada,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pump();
      for (var passo = 0; passo < 3; passo++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Em 1,5 s chegam 1,5 s de dados; a tela atualiza a cada 200 ms.
      expect(find.text('00:01'), findsOneWidget);
      expect(find.textContaining('amostras recebidas'), findsOneWidget);
      expect(find.text('0 amostras recebidas'), findsNothing);

      await tester.tap(find.text('FINALIZAR MEDIÇÃO'));
      // O cancelamento da assinatura conclui fora do tempo simulado do teste.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('fim'), findsOneWidget);
      final sessao = argumentoResultado as SessaoMedicao;
      expect(sessao.finalizada, isTrue);
      expect(sessao.exercicio, Exercicio.remada);
      expect(sessao.quantidadeAmostras, greaterThan(0));
    });
  });
}
