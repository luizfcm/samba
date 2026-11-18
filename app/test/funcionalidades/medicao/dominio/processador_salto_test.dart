import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/processador_salto.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

List<AmostraForca> amostras(List<double> forcasN) => [
  for (var indice = 0; indice < forcasN.length; indice++)
    AmostraForca(
      sequencia: indice,
      timestampUs: indice * 1000,
      forcaN: forcasN[indice],
      status: 0,
    ),
];

ResultadoSalto processar(List<double> forcasN) => const ProcessadorSalto()
    .processar(amostras: amostras(forcasN), parametros: {});

List<double> serieSemContramovimento() {
  const massaKg = 75.0;
  const pesoN = massaKg * 9.81;
  // Propulsão de 0,3 s a partir do repouso até v = g × 0,4 / 2.
  const amplitudeMs2 = 9.81 * 0.4 / 2 * pi / (2 * 0.3);
  final propulsao = [
    for (var indice = 0; indice < 300; indice++)
      massaKg * (9.81 + amplitudeMs2 * sin(pi * indice / 300)),
  ];
  return [
    ...List.filled(2000, pesoN),
    ...propulsao,
    ...List.filled(400, 0.0),
    ...propulsao,
    ...List.filled(2000, pesoN),
  ];
}

void main() {
  group('ProcessadorSalto', () {
    // v = g × tempoVooS / 2 e h = g × tempoVooS² / 8, com tempoVooS = 0,4 s.
    const decolagemMs = 9.81 * 0.4 / 2;
    const alturaM = 9.81 * 0.4 * 0.4 / 8;

    void verificarSaltos(
      ResultadoSalto resultado, {
      required double toleranciaMassa,
      required double toleranciaVelocidade,
      required double toleranciaAltura,
    }) {
      expect(resultado.massaKg, closeTo(75, 75 * toleranciaMassa));
      expect(resultado.saltos, hasLength(10));
      for (final salto in resultado.saltos) {
        expect(salto.tempoVooS, closeTo(0.4, 0.002));
        expect(
          salto.velocidadeDecolagemMs,
          closeTo(decolagemMs, decolagemMs * toleranciaVelocidade),
        );
        expect(salto.alturaVooM, closeTo(alturaM, alturaM * toleranciaAltura));
        expect(
          salto.alturaVelocidadeM,
          closeTo(alturaM, alturaM * toleranciaAltura),
        );
      }
    }

    test('mede massa, voo, velocidade e altura sem ruído', () {
      final resultado = processar(gerarSerieSalto(ruidoN: 0));

      verificarSaltos(
        resultado,
        toleranciaMassa: 0.005,
        toleranciaVelocidade: 0.02,
        toleranciaAltura: 0.03,
      );
    });

    test('mede massa, voo, velocidade e altura com ruído', () {
      final resultado = processar(gerarSerieSalto());

      verificarSaltos(
        resultado,
        toleranciaMassa: 0.01,
        toleranciaVelocidade: 0.03,
        toleranciaAltura: 0.04,
      );
    });

    test('descreve o primeiro salto da decolagem à aterrissagem', () {
      final salto = processar(gerarSerieSalto(ruidoN: 0)).saltos.first;

      // Repouso de 2 s, descida e propulsão de 0,3 s cada e voo de 0,4 s.
      expect(salto.inicioS, greaterThanOrEqualTo(2));
      expect(salto.inicioS, lessThan(2.1));
      expect(salto.decolagemS, 2.6);
      expect(salto.aterrissagemS, 3.0);
      expect(salto.pontos.first.tempoS, salto.inicioS);
      expect(salto.pontos.first.velocidadeMs, 0);
      expect(salto.pontos.last.velocidadeMs, salto.velocidadeDecolagemMs);
      expect(salto.potenciaMaximaW, greaterThan(0));
      expect(salto.forcaMaximaN, greaterThan(75 * 9.81));
      expect(salto.pontos.clear, throwsUnsupportedError);
    });

    test('a altura acompanha o tempo de voo e define o melhor salto', () {
      final resultado = processar([
        ...gerarSerieSalto(saltos: 1, ruidoN: 0),
        ...gerarSerieSalto(saltos: 1, tempoVooS: 0.5, ruidoN: 0),
      ]);
      // h = g × tempoVooS² / 8 com 0,4 s e 0,5 s.
      const alturaMaiorM = 9.81 * 0.5 * 0.5 / 8;

      final [primeiro, segundo] = resultado.saltos;
      expect(primeiro.alturaVooM, closeTo(alturaM, alturaM * 0.03));
      expect(segundo.tempoVooS, closeTo(0.5, 0.002));
      expect(segundo.alturaVooM, closeTo(alturaMaiorM, alturaMaiorM * 0.03));
      expect(
        segundo.alturaVelocidadeM,
        closeTo(alturaMaiorM, alturaMaiorM * 0.03),
      );
      expect(resultado.melhorSalto, same(segundo));
      expect(
        resultado.alturaMediaM,
        closeTo((primeiro.alturaVooM + segundo.alturaVooM) / 2, 1e-12),
      );
    });

    test('rejeita série sem repouso inicial estável', () {
      expect(
        () => processar(gerarSerieSalto().sublist(2000)),
        throwsArgumentError,
      );
      expect(
        () => processar(gerarSerieSalto().sublist(0, 500)),
        throwsArgumentError,
      );
      expect(() => processar([]), throwsArgumentError);
    });

    test('não encontra saltos numa série sem voo', () {
      final resultado = processar(List.filled(3000, 75 * 9.81));

      expect(resultado.massaKg, closeTo(75, 1e-9));
      expect(resultado.saltos, isEmpty);
      expect(resultado.alturaMediaM, isNull);
      expect(resultado.melhorSalto, isNull);
    });

    test('separa a frenagem e a propulsão pela velocidade', () {
      final salto = processar(gerarSerieSalto(ruidoN: 0)).saltos.first;

      // Fim da descida: v = −2 × 4 × 0,3 / π. A integração começa 11 ms
      // depois do início da descida, por isso a tolerância de 5 mm/s.
      expect(salto.velocidadeMinimaMs, closeTo(-0.764, 0.005));
      // Retorno a v = 0 após 0,1065 s de propulsão, com amostras de 1 ms.
      expect(salto.tempoFrenagemS, closeTo(0.1065, 0.001));
      // m × |v mín| = 75 × 0,764 e m × v decolagem = 75 × 1,962.
      expect(salto.impulsoExcentricoNs, closeTo(57.30, 57.30 * 0.01));
      expect(salto.impulsoConcentricoNs, closeTo(147.15, 147.15 * 0.01));
      // m × (g + A2), com A2 = (1,962 + 0,764) × π / 0,6.
      expect(salto.forcaMaximaConcentricaN, closeTo(1806, 1));
      // m × (g × Δh + v²/2) / Δt na propulsão.
      expect(salto.potenciaMediaConcentricaW, closeTo(1632, 1632 * 0.01));
      // (1697 N − m × g) / 0,1065 s.
      expect(salto.rfdFrenagemNPorS, closeTo(9025, 9025 * 0.01));
      expect(salto.pontos.first.forcaN, closeTo(75 * 9.81, 75 * 9.81 * 0.05));
    });

    test('começa a propulsão no início do salto sem contramovimento', () {
      final resultado = processar(serieSemContramovimento());
      final salto = resultado.saltos.single;

      expect(salto.velocidadeMinimaMs, isNull);
      expect(salto.tempoFrenagemS, isNull);
      expect(salto.impulsoExcentricoNs, isNull);
      expect(salto.rfdFrenagemNPorS, isNull);
      // Sem frenagem, o impulso concêntrico vai de v = 0 até a decolagem.
      expect(
        salto.impulsoConcentricoNs,
        closeTo(resultado.massaKg * salto.velocidadeDecolagemMs, 1e-9),
      );
      expect(salto.forcaMaximaConcentricaN, salto.forcaMaximaN);
      expect(salto.potenciaMediaConcentricaW, greaterThan(0));
    });

    test('rejeita timestamps fora de ordem', () {
      final serie = amostras(gerarSerieSalto(saltos: 1));
      serie[100] = AmostraForca(
        sequencia: 100,
        timestampUs: serie[99].timestampUs - 500,
        forcaN: serie[100].forcaN,
        status: 0,
      );

      expect(
        () =>
            const ProcessadorSalto().processar(amostras: serie, parametros: {}),
        throwsArgumentError,
      );
    });
  });
}
