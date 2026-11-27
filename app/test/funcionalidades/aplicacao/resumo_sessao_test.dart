import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/resumo_sessao.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
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

void main() {
  group('resumirSessao', () {
    test('resume a isometria pelo maior pico e pelas repetições', () {
      for (final exercicio in [Exercicio.remada, Exercicio.extensora]) {
        final resumo = resumirSessao(
          criarSessao(exercicio, gerarSerieIsometria(ruidoN: 0)),
        );

        expect(resumo, isA<ResumoIsometria>());
        final isometria = resumo as ResumoIsometria;
        expect(isometria.maiorPicoN, 400);
        expect(isometria.repeticoes, 10);
        // Média de 400 × (1 − 0,02 × i) para i de 0 a 9 = 400 × 0,91.
        expect(isometria.mediaPicosN, closeTo(364, 1e-9));
      }
    });

    test('resume o salto pela altura, pelos saltos e pela massa', () {
      final resumo = resumirSessao(
        criarSessao(Exercicio.salto, gerarSerieSalto(ruidoN: 0)),
      );

      expect(resumo, isA<ResumoSalto>());
      final salto = resumo as ResumoSalto;
      // h = g × tempoVooS² / 8 = 9,81 × 0,4² / 8.
      const alturaM = 9.81 * 0.4 * 0.4 / 8;
      expect(salto.melhorAlturaM, closeTo(alturaM, 1e-9));
      expect(salto.alturaMediaM, closeTo(alturaM, 1e-9));
      expect(salto.saltos, 10);
      expect(salto.massaKg, closeTo(75, 1e-9));
    });

    test('traz a rfd e a força sustentada da repetição de maior pico', () {
      final resumo = resumirSessao(
        criarSessao(Exercicio.remada, gerarSerieIsometria(ruidoN: 0)),
      ) as ResumoIsometria;

      // Rampa de 400 N em 0,5 s: 800 N/s, ou 200 %Fmáx/s.
      expect(resumo.rfdMaximaNPorS, closeTo(800, 1e-6));
      expect(resumo.rfdMaximaPercentualPorS, closeTo(200, 1e-6));
      expect(resumo.forcaSustentadaN, closeTo(400, 1e-9));
      expect(resumo.coeficienteVariacaoPercentual, closeTo(0, 1e-9));
    });

    test('traz a fadiga e as fases do melhor salto', () {
      final resumo = resumirSessao(
        criarSessao(Exercicio.salto, gerarSerieSalto(ruidoN: 0)),
      ) as ResumoSalto;

      // Mesmos valores físicos da série: m × v decolagem = 75 × 1,962.
      expect(resumo.indiceFadigaPercentual, closeTo(0, 1e-9));
      expect(resumo.impulsoConcentricoNs, closeTo(147.15, 147.15 * 0.01));
      expect(resumo.potenciaMediaConcentricaW, closeTo(1632, 1632 * 0.01));
      expect(resumo.tempoFrenagemS, closeTo(0.1065, 0.001));
      expect(resumo.rfdFrenagemNPorS, closeTo(9025, 9025 * 0.01));
    });

    test('deixa nulas as métricas sem repetição ou salto', () {
      final isometria = resumirSessao(
        criarSessao(Exercicio.remada, List.filled(2000, 0)),
      ) as ResumoIsometria;
      final salto = resumirSessao(
        criarSessao(Exercicio.salto, List.filled(3000, 735.75)),
      ) as ResumoSalto;

      expect(isometria.repeticoes, 0);
      expect(isometria.rfdMaximaNPorS, isNull);
      expect(isometria.forcaSustentadaN, isNull);
      expect(salto.saltos, 0);
      expect(salto.indiceFadigaPercentual, isNull);
      expect(salto.potenciaMediaConcentricaW, isNull);
    });

    test('indica quando o processador rejeita a série', () {
      final semRepouso = resumirSessao(
        criarSessao(Exercicio.salto, List.filled(3000, 0)),
      );
      final curta = resumirSessao(criarSessao(Exercicio.remada, [10]));

      expect(semRepouso, isA<ResumoNaoProcessado>());
      expect((semRepouso as ResumoNaoProcessado).motivo, isNotEmpty);
      expect(curta, isA<ResumoNaoProcessado>());
    });

    test('não processa o terra', () {
      final resumo = resumirSessao(
        criarSessao(Exercicio.terra, gerarSerieIsometria(repeticoes: 1)),
      );

      expect(resumo, isA<ResumoNaoProcessado>());
    });
  });

  group('valorDestaque', () {
    test('mostra o maior pico em N na isometria', () {
      expect(
        valorDestaque(
          const ResumoIsometria(
            maiorPicoN: 485.4,
            mediaPicosN: 470,
            repeticoes: 10,
          ),
        ),
        '485 N',
      );
    });

    test('mostra a melhor altura em cm no salto', () {
      expect(
        valorDestaque(
          const ResumoSalto(
            melhorAlturaM: 0.4237,
            alturaMediaM: 0.4,
            saltos: 10,
            massaKg: 75,
          ),
        ),
        '42,4 cm',
      );
    });

    test('mostra travessão sem valor a destacar', () {
      expect(
        valorDestaque(
          const ResumoSalto(
            melhorAlturaM: null,
            alturaMediaM: null,
            saltos: 0,
            massaKg: 75,
          ),
        ),
        '—',
      );
      expect(valorDestaque(const ResumoNaoProcessado('motivo')), '—');
    });
  });
}
