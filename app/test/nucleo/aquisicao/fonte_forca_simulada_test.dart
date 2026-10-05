import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca.dart';
import 'package:samba_app/nucleo/aquisicao/fonte_forca_simulada.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

Future<List<AmostraForca>> coletarAmostras(FonteForca fonte, int quantidade) =>
    fonte.amostras
        .take(quantidade)
        .toList()
        .timeout(const Duration(seconds: 5));

void main() {
  late FonteForca fonte;

  setUp(() {
    fonte = FonteForcaSimulada();
  });

  tearDown(() async {
    await fonte.parar();
  });

  test('nao emite antes de iniciar', () async {
    final recebidas = <AmostraForca>[];
    final assinatura = fonte.amostras.listen(recebidas.add);
    addTearDown(assinatura.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(recebidas, isEmpty);
  });

  test('emite a 100 Hz com sequencia e tempo desde zero', () async {
    final coleta = coletarAmostras(fonte, 100);
    final relogio = Stopwatch()..start();
    await fonte.iniciar();
    final recebidas = await coleta;
    relogio.stop();
    await fonte.parar();

    // São 99 intervalos entre a amostra inicial e a centésima (990 ms).
    // A margem de 40 ms considera a precisão do agendamento do sistema.
    expect(relogio.elapsedMilliseconds, greaterThanOrEqualTo(950));
    expect(recebidas, hasLength(100));
    expect(recebidas.first.timestampUs, 0);
    expect(recebidas.last.timestampUs, greaterThanOrEqualTo(950000));
    expect(
      recebidas.last.timestampUs,
      lessThanOrEqualTo(relogio.elapsedMicroseconds),
    );
    for (var indice = 0; indice < recebidas.length; indice++) {
      expect(recebidas[indice].sequencia, indice);
      if (indice > 0) {
        expect(
          recebidas[indice].timestampUs,
          greaterThan(recebidas[indice - 1].timestampUs),
        );
      }
      expect(recebidas[indice].status, 0);
    }
  });

  test('reproduz os valores conhecidos do sinal triangular', () async {
    final coleta = coletarAmostras(fonte, 101);
    await fonte.iniciar();
    final recebidas = await coleta;

    expect(recebidas[0].forcaN, 0);
    expect(recebidas[1].forcaN, 2);
    expect(recebidas[25].forcaN, 50);
    expect(recebidas[50].forcaN, 100);
    expect(recebidas[75].forcaN, 50);
    expect(recebidas[99].forcaN, 2);
    expect(recebidas[100].forcaN, 0);
  });

  test('iniciar novamente nao duplica nem reinicia o gerador', () async {
    final recebidas = <AmostraForca>[];
    final assinatura = fonte.amostras.listen(recebidas.add);
    addTearDown(assinatura.cancel);
    final primeiraColeta = coletarAmostras(fonte, 3);

    await Future.wait([fonte.iniciar(), fonte.iniciar()]);
    await primeiraColeta;
    final segundaColeta = coletarAmostras(fonte, 3);
    await fonte.iniciar();
    await segundaColeta;
    await fonte.parar();

    expect(recebidas.map((amostra) => amostra.sequencia), [0, 1, 2, 3, 4, 5]);
    expect(recebidas.last.timestampUs, greaterThanOrEqualTo(45000));
  });

  test('parar cancela a emissao e pode ser chamado repetidamente', () async {
    final recebidas = <AmostraForca>[];
    final assinatura = fonte.amostras.listen(recebidas.add);
    addTearDown(assinatura.cancel);
    await fonte.parar();
    final coleta = coletarAmostras(fonte, 3);
    await fonte.iniciar();
    await coleta;
    await fonte.parar();
    final quantidade = recebidas.length;
    expect(quantidade, 3);

    await fonte.parar();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recebidas, hasLength(quantidade));
  });

  test('parar imediatamente nao deixa um gerador ativo', () async {
    final recebidas = <AmostraForca>[];
    final assinatura = fonte.amostras.listen(recebidas.add);
    addTearDown(assinatura.cancel);

    await fonte.iniciar();
    await fonte.parar();
    expect(recebidas, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recebidas, hasLength(1));
  });

  test('reiniciar reproduz o sinal e zera sequencia e timestamp', () async {
    final primeiraColeta = coletarAmostras(fonte, 4);
    await fonte.iniciar();
    final primeiras = await primeiraColeta;
    await fonte.parar();
    final segundaColeta = coletarAmostras(fonte, 4);
    await fonte.iniciar();
    final segundas = await segundaColeta;
    await fonte.parar();

    expect(primeiras.first.timestampUs, 0);
    expect(segundas.first.timestampUs, 0);
    for (var indice = 0; indice < segundas.length; indice++) {
      expect(segundas[indice].sequencia, primeiras[indice].sequencia);
      if (indice > 0) {
        expect(
          segundas[indice].timestampUs,
          greaterThan(segundas[indice - 1].timestampUs),
        );
      }
      expect(segundas[indice].forcaN, primeiras[indice].forcaN);
      expect(segundas[indice].status, primeiras[indice].status);
    }
  });

  test('compartilha as mesmas amostras entre assinantes', () async {
    final primeiraColeta = coletarAmostras(fonte, 3);
    final segundaColeta = coletarAmostras(fonte, 3);
    await fonte.iniciar();
    final recebidas = await Future.wait([primeiraColeta, segundaColeta]);

    expect(recebidas[0], hasLength(3));
    expect(recebidas[1], orderedEquals(recebidas[0]));
  });
}
