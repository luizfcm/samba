import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/historico/aplicacao/historico_sessoes.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/interface/core/rotulos.dart';

void main() {
  group('ItemHistorico.deLinha', () {
    test('lê exercício, data local e pico', () {
      final inicio = DateTime(2026, 10, 14, 18, 35);
      final item = ItemHistorico.deLinha({
        'id': 'abc',
        'exercicio': 'salto',
        'inicio_utc': inicio.toUtc().toIso8601String(),
        'pico': 4756.4,
      });

      expect(item.id, 'abc');
      expect(item.exercicio, Exercicio.salto);
      expect(item.inicio, inicio);
      expect(item.picoN, 4756.4);
    });

    test('aceita pico nulo e exercício desconhecido', () {
      final item = ItemHistorico.deLinha({
        'id': 'x',
        'exercicio': 'inexistente',
        'inicio_utc': 'lixo',
        'pico': null,
      });

      expect(item.exercicio, Exercicio.remada);
      expect(item.picoN, isNull);
    });
  });

  group('formatação', () {
    test('formatarDataHistorico', () {
      expect(
        formatarDataHistorico(DateTime(2026, 10, 9, 16, 40)),
        '09 Out, 16:40',
      );
    });

    test('rotuloExercicio cobre todos os exercícios', () {
      for (final e in Exercicio.values) {
        expect(rotuloExercicio(e), isNotEmpty);
      }
    });
  });
}
