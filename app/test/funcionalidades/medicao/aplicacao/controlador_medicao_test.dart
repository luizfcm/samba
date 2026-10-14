import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/controlador_medicao.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca criarAmostra(int sequencia, int timestampUs, double forcaN) =>
    AmostraForca(
      sequencia: sequencia,
      timestampUs: timestampUs,
      forcaN: forcaN,
      status: 0,
    );

class FonteForcaFalsa implements FonteForca {
  final _controlador = StreamController<AmostraForca>.broadcast(sync: true);
  int chamadasIniciar = 0;
  int chamadasParar = 0;
  Exception? erroAoIniciar;
  Exception? erroAoParar;
  Completer<void>? parada;

  bool get assinada => _controlador.hasListener;

  @override
  Stream<AmostraForca> get amostras => _controlador.stream;

  @override
  Future<void> iniciar() async {
    chamadasIniciar++;
    if (erroAoIniciar case final erro?) throw erro;
  }

  @override
  Future<void> parar() async {
    chamadasParar++;
    await parada?.future;
    if (erroAoParar case final erro?) throw erro;
  }

  void emitir(int sequencia, int timestampUs, [double forcaN = 0]) =>
      _controlador.add(criarAmostra(sequencia, timestampUs, forcaN));
}

void main() {
  group('ControladorMedicao', () {
    final inicio = DateTime.utc(2026, 10, 13, 9);
    final termino = inicio.add(const Duration(seconds: 30));
    late FonteForcaFalsa fonte;
    late ControladorMedicao controlador;
    late int notificacoes;

    Iterable<int> sequenciasNaSessao() =>
        controlador.sessao!.amostras.map((amostra) => amostra.sequencia);

    setUp(() {
      fonte = FonteForcaFalsa();
      controlador = ControladorMedicao(fonte: fonte);
      notificacoes = 0;
      controlador.addListener(() => notificacoes++);
    });

    test('começa ociosa, sem sessão e sem contagens', () {
      expect(controlador.estado, EstadoMedicao.ociosa);
      expect(controlador.sessao, isNull);
      expect(controlador.amostrasPerdidas, 0);
      expect(controlador.amostrasDescartadas, 0);
      expect(fonte.assinada, isFalse);
    });

    test('iniciar cria a sessão, assina e inicia a fonte', () async {
      await controlador.iniciar(Exercicio.remada, inicio: inicio);

      expect(controlador.estado, EstadoMedicao.medindo);
      expect(controlador.sessao!.exercicio, Exercicio.remada);
      expect(controlador.sessao!.inicio, inicio);
      expect(controlador.sessao!.ativa, isTrue);
      expect(fonte.assinada, isTrue);
      expect(fonte.chamadasIniciar, 1);
    });

    test('adiciona à sessão as amostras recebidas em ordem', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(0, 0, 10);
      fonte.emitir(1, 10000, 20);
      fonte.emitir(2, 20000, -5);

      expect(controlador.sessao!.amostras.map((amostra) => amostra.forcaN), [
        10,
        20,
        -5,
      ]);
      expect(controlador.amostrasPerdidas, 0);
      expect(controlador.amostrasDescartadas, 0);
    });

    test('soma lacunas de sequência a partir da primeira amostra', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(10, 0);
      fonte.emitir(11, 10000);
      fonte.emitir(14, 40000);
      fonte.emitir(20, 100000);

      // Faltam 12 e 13, depois de 15 a 19.
      expect(controlador.amostrasPerdidas, 7);
      expect(controlador.amostrasDescartadas, 0);
      expect(sequenciasNaSessao(), [10, 11, 14, 20]);
    });

    test('descarta amostras com sequência repetida ou anterior', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(5, 0);
      fonte.emitir(6, 10000);
      fonte.emitir(6, 20000);
      fonte.emitir(4, 30000);
      fonte.emitir(7, 40000);

      expect(controlador.amostrasDescartadas, 2);
      expect(controlador.amostrasPerdidas, 0);
      expect(sequenciasNaSessao(), [5, 6, 7]);
    });

    test('descarta amostras com timestamp repetido ou anterior', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(0, 10000);
      fonte.emitir(1, 10000);
      fonte.emitir(2, 5000);
      fonte.emitir(4, 20000);

      expect(controlador.amostrasDescartadas, 2);
      // 1 e 2 chegaram e foram descartadas; só a 3 falta.
      expect(controlador.amostrasPerdidas, 1);
      expect(sequenciasNaSessao(), [0, 4]);
    });

    test('notifica somente nas mudanças de estado', () async {
      await controlador.iniciar(Exercicio.terra, inicio: inicio);
      expect(notificacoes, 1);

      fonte.emitir(0, 0);
      fonte.emitir(3, 30000);
      fonte.emitir(3, 40000);
      expect(notificacoes, 1);

      await controlador.finalizar(termino: termino);
      expect(notificacoes, 2);
    });

    test('finalizar para a fonte e retorna a sessão finalizada', () async {
      await controlador.iniciar(Exercicio.extensora, inicio: inicio);
      fonte.emitir(0, 0, 50);
      final sessao = await controlador.finalizar(termino: termino);

      expect(sessao, same(controlador.sessao));
      expect(sessao.finalizada, isTrue);
      expect(sessao.termino, termino);
      expect(sessao.quantidadeAmostras, 1);
      expect(controlador.estado, EstadoMedicao.finalizada);
      expect(fonte.chamadasParar, 1);
      expect(fonte.assinada, isFalse);
    });

    test('preserva as contagens e ignora amostras após finalizar', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(0, 0);
      fonte.emitir(2, 20000);
      fonte.emitir(2, 30000);
      await controlador.finalizar(termino: termino);
      fonte.emitir(3, 40000);

      expect(controlador.sessao!.quantidadeAmostras, 2);
      expect(controlador.amostrasPerdidas, 1);
      expect(controlador.amostrasDescartadas, 1);
    });

    test('mantém a medição até a fonte concluir a parada', () async {
      fonte.parada = Completer<void>();
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(0, 0);
      final finalizacao = controlador.finalizar(termino: termino);
      fonte.emitir(1, 10000);

      expect(controlador.estado, EstadoMedicao.medindo);
      expect(controlador.sessao!.ativa, isTrue);
      await expectLater(controlador.finalizar(), throwsStateError);
      await expectLater(controlador.iniciar(Exercicio.terra), throwsStateError);

      fonte.parada!.complete();
      final sessao = await finalizacao;
      expect(sessao.termino, termino);
      expect(sessao.quantidadeAmostras, 1);
      expect(controlador.estado, EstadoMedicao.finalizada);
      expect(notificacoes, 2);
    });

    test('rejeita iniciar durante uma medição', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      final sessao = controlador.sessao;
      fonte.emitir(0, 0);

      await expectLater(controlador.iniciar(Exercicio.terra), throwsStateError);
      expect(controlador.sessao, same(sessao));
      expect(controlador.sessao!.quantidadeAmostras, 1);
      expect(controlador.estado, EstadoMedicao.medindo);
      expect(fonte.chamadasIniciar, 1);
      expect(notificacoes, 1);
    });

    test('rejeita finalizar sem medição em andamento', () async {
      await expectLater(controlador.finalizar(), throwsStateError);

      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      await controlador.finalizar(termino: termino);
      await expectLater(controlador.finalizar(), throwsStateError);

      expect(controlador.sessao!.termino, termino);
      expect(fonte.chamadasParar, 1);
      expect(notificacoes, 2);
    });

    test('nova medição cria outra sessão e zera as contagens', () async {
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      fonte.emitir(0, 0);
      fonte.emitir(2, 20000);
      fonte.emitir(2, 30000);
      final primeira = await controlador.finalizar(termino: termino);

      await controlador.iniciar(Exercicio.remada, inicio: termino);
      fonte.emitir(0, 0);

      expect(controlador.estado, EstadoMedicao.medindo);
      expect(controlador.sessao, isNot(same(primeira)));
      expect(controlador.sessao!.exercicio, Exercicio.remada);
      expect(controlador.sessao!.quantidadeAmostras, 1);
      expect(controlador.amostrasPerdidas, 0);
      expect(controlador.amostrasDescartadas, 0);
      expect(primeira.quantidadeAmostras, 2);
      expect(fonte.chamadasIniciar, 2);
      expect(notificacoes, 3);
    });

    test('volta a ociosa quando a fonte falha ao iniciar', () async {
      final erro = Exception('Fonte indisponível.');
      fonte.erroAoIniciar = erro;

      await expectLater(
        controlador.iniciar(Exercicio.salto, inicio: inicio),
        throwsA(same(erro)),
      );
      expect(controlador.estado, EstadoMedicao.ociosa);
      expect(controlador.sessao, isNull);
      expect(fonte.assinada, isFalse);
      expect(notificacoes, 2);
    });

    test('finaliza a sessão mesmo quando a fonte falha ao parar', () async {
      final erro = Exception('Falha ao parar.');
      fonte.erroAoParar = erro;
      await controlador.iniciar(Exercicio.salto, inicio: inicio);

      await expectLater(
        controlador.finalizar(termino: termino),
        throwsA(same(erro)),
      );
      expect(controlador.estado, EstadoMedicao.finalizada);
      expect(controlador.sessao!.termino, termino);
      expect(fonte.assinada, isFalse);
    });

    test(
      'encerrar durante a medição cancela a assinatura e para a fonte',
      () async {
        await controlador.iniciar(Exercicio.salto, inicio: inicio);
        controlador.dispose();

        expect(fonte.assinada, isFalse);
        expect(fonte.chamadasParar, 1);
      },
    );

    test('encerrar ignora a falha da fonte ao parar', () async {
      fonte.erroAoParar = Exception('Falha ao parar.');
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      controlador.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(fonte.chamadasParar, 1);
    });

    test('encerrar durante a parada não notifica depois', () async {
      fonte.parada = Completer<void>();
      await controlador.iniciar(Exercicio.salto, inicio: inicio);
      final finalizacao = controlador.finalizar(termino: termino);
      controlador.dispose();
      fonte.parada!.complete();

      final sessao = await finalizacao;
      expect(sessao.finalizada, isTrue);
      expect(notificacoes, 1);
    });
  });
}
