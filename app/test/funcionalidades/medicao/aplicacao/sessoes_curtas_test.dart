import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/controlador_medicao.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/csv_sessao.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/curva_ao_vivo.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/curva_reduzida.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/frequencia_media.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/resumo_sessao.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/processador_isometria.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/processador_salto.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca.dart';
import 'package:samba_app/nucleo/aquisicao/series_simuladas.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

class FonteForcaFalsa implements FonteForca {
  final _controlador = StreamController<AmostraForca>.broadcast(sync: true);

  @override
  Stream<AmostraForca> get amostras => _controlador.stream;

  @override
  Future<void> iniciar() async {}

  @override
  Future<void> parar() async {}

  @override
  Future<void> tarar() async {}

  void emitir(List<double> forcasN) {
    for (var indice = 0; indice < forcasN.length; indice++) {
      _controlador.add(
        AmostraForca(
          sequencia: indice,
          timestampUs: indice * 1000,
          forcaN: forcasN[indice],
          status: 0,
        ),
      );
    }
  }

  void falhar() =>
      _controlador.addError(StateError('O equipamento desconectou.'));
}

/// Passa pelo controlador, como no app; no salto a fonte manda compressão
/// negativa e o controlador inverte o sinal.
Future<SessaoMedicao> criarSessao(
  Exercicio exercicio,
  List<double> forcasN, {
  required bool interromper,
}) async {
  final fonte = FonteForcaFalsa();
  final controlador = ControladorMedicao(fonte: fonte);
  await controlador.iniciar(exercicio, inicio: DateTime.utc(2026, 11, 22));
  fonte.emitir([
    for (final forcaN in forcasN)
      exercicio == Exercicio.salto ? 0.0 - forcaN : forcaN,
  ]);
  if (interromper) {
    fonte.falhar();
    expect(controlador.interrompida, isTrue);
  } else {
    await controlador.finalizar(termino: DateTime.utc(2026, 11, 22, 0, 1));
  }
  controlador.dispose();
  return controlador.sessao!;
}

void main() {
  const pesoN = 75 * 9.81;

  for (final exercicio in [
    Exercicio.remada,
    Exercicio.extensora,
    Exercicio.salto,
  ]) {
    final salto = exercicio == Exercicio.salto;
    final cargaN = salto ? pesoN : 100.0;
    final curtaDemais = isA<ResumoNaoProcessado>().having(
      (resumo) => resumo.motivo,
      'motivo',
      salto
          ? 'A medição terminou antes do primeiro segundo parado na plataforma.'
          : 'A medição terminou antes de registrar dados suficientes.',
    );
    final semRepeticoes = isA<ResumoIsometria>().having(
      (resumo) => resumo.repeticoes,
      'repeticoes',
      0,
    );
    final casos = <String, (List<double>, Matcher)>{
      for (final quantidade in [0, 1, 2, 3])
        '$quantidade amostras': (
          List.filled(quantidade, cargaN),
          salto || quantidade < 2 ? curtaDemais : semRepeticoes,
        ),
      if (salto)
        'série mais curta que o repouso': (
          gerarSerieSalto().sublist(0, 500),
          curtaDemais,
        ),
      'força constante': (
        List.filled(3000, cargaN),
        salto
            ? isA<ResumoSalto>().having((resumo) => resumo.saltos, 'saltos', 0)
            : semRepeticoes,
      ),
      'força toda em zero': (
        List.filled(3000, 0),
        salto
            ? isA<ResumoNaoProcessado>().having(
                (resumo) => resumo.motivo,
                'motivo',
                contains('parada na plataforma'),
              )
            : semRepeticoes,
      ),
    };

    group('sessão curta de ${exercicio.name}', () {
      for (final MapEntry(key: nome, value: (forcasN, esperado))
          in casos.entries) {
        for (final interromper in [false, true]) {
          final situacao = interromper ? 'interrompida' : 'finalizada';

          test('não falha com $nome, $situacao', () async {
            final sessao = await criarSessao(
              exercicio,
              forcasN,
              interromper: interromper,
            );
            final amostras = sessao.amostras;

            final resumo = resumirSessao(sessao);
            expect(resumo, esperado);
            expect(valorDestaque(resumo), isNotEmpty);
            expect(
              reduzirCurva(amostras).length,
              amostras.length <= 1500
                  ? amostras.length
                  : lessThanOrEqualTo(1500),
            );
            expect(
              CurvaAoVivo(sessao: sessao).atualizar().length,
              amostras.length <= 300 ? amostras.length : lessThanOrEqualTo(300),
            );
            expect(frequenciaMediaHz(amostras), greaterThanOrEqualTo(0));
            expect(
              gerarCsvSessao(sessao)
                  .split('\n')
                  .where((linha) => linha.isNotEmpty),
              hasLength(amostras.length + 1),
            );
            const ProcessadorIsometria().processar(
              amostras: amostras,
              parametros: const {},
            );
            const ProcessadorSalto().processar(
              amostras: amostras,
              parametros: const {},
            );
          });
        }
      }
    });
  }
}
