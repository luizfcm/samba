import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/ble/pacote_medicao.dart';

// Versão 2, status 0xABCD, sequência 0x12345678 e timestamp 4.295.967.296 us
// (maior que uint32).
List<int> cabecalho(int quantidade) => [
  ...[0x02, quantidade, 0xCD, 0xAB],
  ...[0x78, 0x56, 0x34, 0x12],
  ...[0x40, 0x42, 0x0F, 0x00, 0x01, 0x00, 0x00, 0x00],
];

List<int> bloco(int forcaMilinewtons, int deltaUs) => [
  forcaMilinewtons & 0xFF,
  (forcaMilinewtons >> 8) & 0xFF,
  (forcaMilinewtons >> 16) & 0xFF,
  (forcaMilinewtons >> 24) & 0xFF,
  deltaUs & 0xFF,
  (deltaUs >> 8) & 0xFF,
];

// Forças de 123.456, 1000 e 250 mN; deltas de 0, 1000 e 65.535 us.
Uint8List pacoteConhecido() => Uint8List.fromList([
  ...cabecalho(3),
  ...[0x40, 0xE2, 0x01, 0x00, 0x00, 0x00],
  ...[0xE8, 0x03, 0x00, 0x00, 0xE8, 0x03],
  ...[0xFA, 0x00, 0x00, 0x00, 0xFF, 0xFF],
]);

void main() {
  group('PacoteMedicao.decodificar', () {
    test('decodifica pacote conhecido com três amostras', () {
      final amostras = PacoteMedicao.decodificar(pacoteConhecido());

      expect(amostras, hasLength(3));
      expect(amostras.map((amostra) => amostra.sequencia), [
        0x12345678,
        0x12345679,
        0x1234567A,
      ]);
      // 4.295.967.296 + 1000 e depois + 65.535 us.
      expect(amostras.map((amostra) => amostra.timestampUs), [
        4295967296,
        4295968296,
        4296033831,
      ]);
      expect(amostras[0].forcaN, closeTo(123.456, 1e-9));
      expect(amostras[1].forcaN, 1);
      expect(amostras[2].forcaN, 0.25);
      expect(amostras.map((amostra) => amostra.status), everyElement(0xABCD));
    });

    test('decodifica pacote com vinte amostras', () {
      final pacote = Uint8List.fromList([
        ...cabecalho(20),
        for (var indice = 0; indice < 20; indice++)
          ...bloco(indice * 100, indice == 0 ? 0 : 1000),
      ]);
      final amostras = PacoteMedicao.decodificar(pacote);

      expect(pacote, hasLength(136));
      expect(amostras, hasLength(20));
      for (var indice = 0; indice < 20; indice++) {
        expect(amostras[indice].sequencia, 0x12345678 + indice);
        expect(amostras[indice].timestampUs, 4295967296 + indice * 1000);
        expect(amostras[indice].forcaN, closeTo(indice * 0.1, 1e-9));
        expect(amostras[indice].status, 0xABCD);
      }
    });

    test('preserva força negativa', () {
      final pacote = pacoteConhecido();
      // -1500 mN como int32 com sinal, em little-endian.
      pacote.setRange(22, 26, [0x24, 0xFA, 0xFF, 0xFF]);

      expect(PacoteMedicao.decodificar(pacote)[1].forcaN, -1.5);
    });

    test('decodifica uma seção do buffer com deslocamento não nulo', () {
      final buffer = Uint8List.fromList([0xFF, ...pacoteConhecido(), 0xFF]);
      final amostras = PacoteMedicao.decodificar(
        Uint8List.sublistView(buffer, 1, 35),
      );

      expect(amostras, hasLength(3));
      expect(amostras.first.sequencia, 0x12345678);
      expect(amostras.first.timestampUs, 4295967296);
      expect(amostras.first.forcaN, closeTo(123.456, 1e-9));
      expect(amostras.last.timestampUs, 4296033831);
    });

    for (final versao in [1, 3]) {
      test('rejeita versão $versao', () {
        final pacote = pacoteConhecido()..[0] = versao;

        expect(() => PacoteMedicao.decodificar(pacote), throwsFormatException);
      });
    }

    test('rejeita pacote sem amostras', () {
      expect(
        () => PacoteMedicao.decodificar(Uint8List.fromList(cabecalho(0))),
        throwsFormatException,
      );
    });

    for (final tamanho in [0, 15, 33, 35]) {
      test('rejeita pacote de $tamanho bytes para três amostras', () {
        final pacote = Uint8List.fromList(
          [...pacoteConhecido(), 0x00].take(tamanho).toList(),
        );

        expect(() => PacoteMedicao.decodificar(pacote), throwsFormatException);
      });
    }

    test('rejeita delta diferente de zero na primeira amostra', () {
      final pacote = pacoteConhecido()..[20] = 0x01;

      expect(() => PacoteMedicao.decodificar(pacote), throwsFormatException);
    });

    test('rejeita delta zero nas amostras seguintes', () {
      final pacote = pacoteConhecido()..setRange(32, 34, [0x00, 0x00]);

      expect(() => PacoteMedicao.decodificar(pacote), throwsFormatException);
    });
  });
}
