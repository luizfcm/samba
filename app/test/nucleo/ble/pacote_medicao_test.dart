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

Uint8List bytesHex(String hex) => Uint8List.fromList([
  for (final par in hex.trim().split(RegExp(r'\s+'))) int.parse(par, radix: 16),
]);

// Pacotes gerados pelo firmware: completo, com 20 amostras e status 0x0024
// (sem calibração e aquisição em andamento), e parcial, o último após o STOP.
const pacoteCompletoFirmware =
    '02 14 24 00 00 00 00 00 00 00 00 00 00 00 00 00 '
    '78 00 00 00 00 00 a1 ff ff ff 5a 03 36 01 00 00 5a 03 2c 00 00 00 5b 03 '
    '2e ff ff ff 5a 03 57 00 00 00 5a 03 0f 00 00 00 5b 03 c4 ff ff ff 5a 03 '
    'f0 00 00 00 5a 03 7e ff ff ff 5b 03 05 00 00 00 5a 03 be 00 00 00 5a 03 '
    'b5 ff ff ff 5b 03 21 00 00 00 5a 03 e8 fe ff ff 5a 03 96 00 00 00 5b 03 '
    '3e 00 00 00 5a 03 ee ff ff ff 5a 03 0e 01 00 00 5b 03 d8 ff ff ff 5a 03';
const pacoteParcialFirmware =
    '02 06 24 00 14 00 00 00 0e 43 00 00 00 00 00 00 '
    '56 cc 00 00 00 00 1e cf 00 00 5a 03 82 d2 00 00 5b 03 '
    'ad d5 00 00 5a 03 ca d8 00 00 5a 03 92 db 00 00 5b 03';

// Característica Estado do mesmo firmware, para o futuro decodificador:
// 02 04 00 b0 04 67 21 12 41 ca 23 00 00 = versão 2, status 0x0004,
// taxa 1200 Hz, fator 9.1331549 mN/contagem e deslocamento 9162 contagens.

void main() {
  group('PacoteMedicao.decodificar', () {
    test('decodifica um pacote completo gerado pelo firmware', () {
      final pacote = bytesHex(pacoteCompletoFirmware);
      final amostras = PacoteMedicao.decodificar(pacote);

      expect(pacote, hasLength(136));
      expect(amostras.map((amostra) => amostra.sequencia), [
        for (var indice = 0; indice < 20; indice++) indice,
      ]);
      // Deltas alternando 858, 858 e 859 µs a partir de t0 = 0.
      expect(amostras.map((amostra) => amostra.timestampUs), [
        0,
        858,
        1716,
        2575,
        3433,
        4291,
        5150,
        6008,
        6866,
        7725,
        8583,
        9441,
        10300,
        11158,
        12016,
        12875,
        13733,
        14591,
        15450,
        16308,
      ]);
      expect(amostras.map((amostra) => amostra.forcaN), [
        0.12,
        -0.095,
        0.31,
        0.044,
        -0.21,
        0.087,
        0.015,
        -0.06,
        0.24,
        -0.13,
        0.005,
        0.19,
        -0.075,
        0.033,
        -0.28,
        0.15,
        0.062,
        -0.018,
        0.27,
        -0.04,
      ]);
      expect(amostras.map((amostra) => amostra.status), everyElement(0x0024));
    });

    test('decodifica o pacote parcial do fim da aquisição', () {
      final pacote = bytesHex(pacoteParcialFirmware);
      final amostras = PacoteMedicao.decodificar(pacote);

      expect(pacote, hasLength(52));
      expect(amostras.map((amostra) => amostra.sequencia), [
        20,
        21,
        22,
        23,
        24,
        25,
      ]);
      // Continua o pacote completo: 16 308 + 858 = 17 166 µs.
      expect(amostras.map((amostra) => amostra.timestampUs), [
        17166,
        18024,
        18883,
        19741,
        20599,
        21458,
      ]);
      expect(amostras.map((amostra) => amostra.forcaN), [
        52.31,
        53.022,
        53.89,
        54.701,
        55.498,
        56.21,
      ]);
      expect(amostras.map((amostra) => amostra.status), everyElement(0x0024));
    });

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
