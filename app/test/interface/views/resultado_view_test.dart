import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/interface/views/resultado_view.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

SessaoMedicao criarSessao(Exercicio exercicio, List<double> forcasN) {
  final sessao = SessaoMedicao(
    exercicio: exercicio,
    inicio: DateTime.utc(2026, 11, 8, 10),
  );
  for (var indice = 0; indice < forcasN.length; indice++) {
    sessao.adicionarAmostra(
      AmostraForca(
        sequencia: indice,
        timestampUs: indice * 1000,
        forcaN: forcasN[indice],
        status: 0,
      ),
    );
  }
  sessao.finalizar(termino: DateTime.utc(2026, 11, 8, 10, 2));
  return sessao;
}

Future<void> abrirResultado(WidgetTester tester, SessaoMedicao sessao) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {'/resultado': (contexto) => const ResultadoView()},
      home: Builder(
        builder: (contexto) => TextButton(
          onPressed: () =>
              Navigator.pushNamed(contexto, '/resultado', arguments: sessao),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('ResultadoView', () {
    testWidgets('mostra a curva da sessão e o maior pico da isometria', (
      tester,
    ) async {
      await abrirResultado(
        tester,
        criarSessao(Exercicio.remada, gerarSerieIsometria(ruidoN: 0)),
      );

      final grafico = tester.widget<LineChart>(find.byType(LineChart));
      final pontos = grafico.data.lineBarsData.single.spots;
      expect(pontos.length, lessThanOrEqualTo(1500));
      expect(
        pontos.map((ponto) => ponto.y).reduce((a, b) => a > b ? a : b),
        400,
      );
      expect(find.text('Força de Pico'), findsOneWidget);
      expect(find.text('400 N'), findsOneWidget);
      expect(find.text('5200 kgf/s'), findsOneWidget);
    });

    testWidgets('mostra a melhor altura do salto em cm', (tester) async {
      await abrirResultado(
        tester,
        criarSessao(Exercicio.salto, gerarSerieSalto(ruidoN: 0)),
      );

      // h = 9,81 × 0,4² / 8 = 0,1962 m.
      expect(find.text('19,6 cm'), findsOneWidget);
    });
  });
}
