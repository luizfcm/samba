import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/ble/pacote_medicao.dart';

// Bytes literais independentes do decodificador: versão 1, flags 0,
// sequência 0x12345678, timestamp 4.295.967.296 us (maior que uint32),
// força 123.456 mN e status 0xABCD.
Uint8List pacoteConhecido() => Uint8List.fromList([
  0x01,
  0x00,
  0x78,
  0x56,
  0x34,
  0x12,
  0x40,
  0x42,
  0x0F,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x40,
  0xE2,
  0x01,
  0x00,
  0xCD,
  0xAB,
]);

void main() {
  group('PacoteMedicao.decodificar', () {
    test('decodifica pacote BLE conhecido e converte mN para N', () {
      final amostra = PacoteMedicao.decodificar(pacoteConhecido());

      expect(amostra.sequencia, 0x12345678);
      expect(amostra.timestampUs, 4295967296);
      expect(amostra.timestampSegundos, closeTo(4295.967296, 1e-9));
      expect(amostra.forcaN, closeTo(123.456, 1e-9));
      expect(amostra.status, 0xABCD);
    });

    test('preserva força negativa', () {
      final pacote = pacoteConhecido();
      // -1500 mN como int32 com sinal, em little-endian.
      pacote.setRange(14, 18, [0x24, 0xFA, 0xFF, 0xFF]);

      expect(PacoteMedicao.decodificar(pacote).forcaN, -1.5);
    });

    test('decodifica uma seção do buffer com deslocamento não nulo', () {
      final buffer = Uint8List.fromList([0xFF, ...pacoteConhecido(), 0xFF]);
      final amostra = PacoteMedicao.decodificar(
        Uint8List.sublistView(buffer, 1, 21),
      );

      expect(amostra.sequencia, 0x12345678);
      expect(amostra.timestampUs, 4295967296);
      expect(amostra.forcaN, closeTo(123.456, 1e-9));
      expect(amostra.status, 0xABCD);
    });

    for (final tamanho in [0, 19, 21]) {
      test('rejeita um pacote de $tamanho bytes', () {
        expect(
          () => PacoteMedicao.decodificar(Uint8List(tamanho)),
          throwsFormatException,
        );
      });
    }

    test('rejeita versão não suportada', () {
      final pacote = pacoteConhecido()..[0] = 2;

      expect(() => PacoteMedicao.decodificar(pacote), throwsFormatException);
    });
  });
}
