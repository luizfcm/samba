import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/historico/aplicacao/historico_sessoes.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/interface/views/historico_view.dart';

final _itens = [
  ItemHistorico(
    id: 'a',
    exercicio: Exercicio.salto,
    inicio: DateTime(2026, 10, 14, 18, 35),
    picoN: 4756.4,
  ),
  ItemHistorico(
    id: 'b',
    exercicio: Exercicio.remada,
    inicio: DateTime(2026, 10, 12, 10, 15),
    picoN: null,
  ),
  ItemHistorico(
    id: 'c',
    exercicio: Exercicio.extensora,
    inicio: DateTime(2026, 10, 9, 16, 40),
    picoN: 3100,
  ),
  ItemHistorico(
    id: 'd',
    exercicio: Exercicio.terra,
    inicio: DateTime(2026, 10, 8, 9, 0),
    picoN: 2500,
  ),
];

Widget app({
  required Future<List<ItemHistorico>> Function() carregar,
  Future<SessaoMedicao> Function(String id)? abrirSessao,
  void Function(Object? argumentos)? aoAbrirResultado,
}) {
  return MaterialApp(
    routes: {
      '/resultado': (contexto) {
        aoAbrirResultado?.call(ModalRoute.of(contexto)!.settings.arguments);
        return const Scaffold(body: Text('TELA RESULTADO'));
      },
    },
    home: HistoricoView(
      carregar: carregar,
      abrirSessao: abrirSessao ?? (id) async => SessaoMedicao(exercicio: Exercicio.salto),
    ),
  );
}

void main() {
  group('HistoricoView', () {
    testWidgets('lista os treinos com data e pico em N', (tester) async {
      await tester.pumpWidget(app(carregar: () async => _itens));
      await tester.pumpAndSettle();

      expect(find.text('Salto Vertical'), findsOneWidget);
      expect(find.text('14 Out, 18:35'), findsOneWidget);
      expect(find.text('Remada'), findsOneWidget);
      expect(find.text('Extensora'), findsOneWidget);
      expect(find.text('Levantamento Terra'), findsOneWidget);
    });

    testWidgets('mostra estado vazio', (tester) async {
      await tester.pumpWidget(app(carregar: () async => const []));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum treino salvo ainda'), findsOneWidget);
    });

    testWidgets('mostra erro e tenta de novo', (tester) async {
      var chamadas = 0;
      await tester.pumpWidget(
        app(
          carregar: () async {
            chamadas++;
            if (chamadas == 1) throw StateError('falha');
            return _itens;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível carregar os treinos'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Salto Vertical'), findsOneWidget);
    });

    testWidgets('tocar no card abre o resultado somente leitura', (
      tester,
    ) async {
      Object? argumentos;
      String? idAberto;
      final sessao = SessaoMedicao(exercicio: Exercicio.salto);
      await tester.pumpWidget(
        app(
          carregar: () async => _itens,
          abrirSessao: (id) async {
            idAberto = id;
            return sessao;
          },
          aoAbrirResultado: (a) => argumentos = a,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salto Vertical'));
      await tester.pumpAndSettle();

      expect(find.text('TELA RESULTADO'), findsOneWidget);
      expect(idAberto, 'a');
      final mapa = argumentos as Map;
      expect(mapa['sessao'], same(sessao));
      expect(mapa['somenteLeitura'], true);
    });

    testWidgets('avisa quando não consegue abrir o treino', (tester) async {
      await tester.pumpWidget(
        app(
          carregar: () async => _itens,
          abrirSessao: (id) async => throw StateError('falha'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salto Vertical'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível abrir este treino.'), findsOneWidget);
      expect(find.text('TELA RESULTADO'), findsNothing);
    });
  });
}
