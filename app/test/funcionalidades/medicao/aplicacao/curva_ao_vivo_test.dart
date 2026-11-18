import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/curva_ao_vivo.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/curva_reduzida.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

SessaoMedicao criarSessao() =>
    SessaoMedicao(exercicio: Exercicio.remada, inicio: DateTime.utc(2026, 11));

void adicionarAmostras(
  SessaoMedicao sessao,
  int quantidade, {
  int origemUs = 0,
}) {
  final inicial = sessao.quantidadeAmostras;
  for (var indice = inicial; indice < inicial + quantidade; indice++) {
    sessao.adicionarAmostra(
      AmostraForca(
        sequencia: indice,
        timestampUs: origemUs + indice * 1000,
        forcaN: indice.toDouble(),
        status: 0,
      ),
    );
  }
}

List<(double, double)> pares(List<PontoCurva> pontos) => [
  for (final ponto in pontos) (ponto.tempoS, ponto.forcaN),
];

void main() {
  group('CurvaAoVivo', () {
    test('mostra só os últimos 5 s da sessão', () {
      final sessao = criarSessao();
      adicionarAmostras(sessao, 8000);

      final pontos = CurvaAoVivo(sessao: sessao).atualizar();

      // A última amostra está em 7,999 s; a janela começa em 2,999 s.
      expect(pontos.length, lessThanOrEqualTo(300));
      expect(pontos.first.tempoS, greaterThanOrEqualTo(2.999));
      expect(pontos.last.tempoS, closeTo(7.999, 1e-9));
      expect(pontos.last.forcaN, 7999);
    });

    test('acompanha as amostras novas a cada atualização', () {
      final sessao = criarSessao();
      final curva = CurvaAoVivo(sessao: sessao);
      adicionarAmostras(sessao, 3000);
      expect(curva.atualizar().last.tempoS, closeTo(2.999, 1e-9));

      adicionarAmostras(sessao, 3000);
      final pontos = curva.atualizar();

      expect(pontos.last.tempoS, closeTo(5.999, 1e-9));
      expect(pares(pontos), pares(CurvaAoVivo(sessao: sessao).atualizar()));
    });

    test('mede o tempo desde a primeira amostra da sessão', () {
      final sessao = criarSessao();
      adicionarAmostras(sessao, 100, origemUs: 2000000);

      final pontos = CurvaAoVivo(sessao: sessao).atualizar();

      expect(pontos, hasLength(100));
      expect(pontos.first.tempoS, 0);
      expect(pontos.last.tempoS, closeTo(0.099, 1e-9));
    });

    test('devolve lista vazia sem amostras', () {
      expect(CurvaAoVivo(sessao: criarSessao()).atualizar(), isEmpty);
    });

    test('rejeita duração ou limite de pontos inválidos', () {
      expect(
        () => CurvaAoVivo(sessao: criarSessao(), duracaoUs: 0),
        throwsArgumentError,
      );
      expect(
        () => CurvaAoVivo(sessao: criarSessao(), maximoPontos: 0),
        throwsArgumentError,
      );
    });
  });
}
