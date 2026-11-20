import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/nucleo/ble/estado_equipamento.dart';

import 'pacotes_firmware.dart';

void main() {
  group('EstadoEquipamento.decodificar', () {
    test('decodifica o estado lido do firmware', () {
      final estado = EstadoEquipamento.decodificar(bytesHex(estadoFirmware));

      expect(estado.versao, 2);
      expect(estado.status, 0x0004);
      expect(estado.taxaNominalHz, 1200);
      expect(estado.fatorMnPorContagem, closeTo(9.1331549, 1e-6));
      expect(estado.deslocamentoContagens, 9162);
      expect(estado.semCalibracao, isTrue);
      expect(estado.aquisicaoEmAndamento, isFalse);
    });

    test('decodifica uma seção do buffer com deslocamento não nulo', () {
      final buffer = Uint8List.fromList([
        0xFF,
        ...bytesHex(estadoFirmware),
        0xFF,
      ]);
      final estado = EstadoEquipamento.decodificar(
        Uint8List.sublistView(buffer, 1, 14),
      );

      expect(estado.taxaNominalHz, 1200);
      expect(estado.deslocamentoContagens, 9162);
    });

    test('preserva deslocamento negativo', () {
      // -9162 como int32 com sinal, em little-endian.
      final dados = bytesHex(estadoFirmware)
        ..setRange(9, 13, [0x36, 0xdc, 0xff, 0xff]);

      expect(EstadoEquipamento.decodificar(dados).deslocamentoContagens, -9162);
    });

    test('lê cada bit de status e ignora os reservados', () {
      final leitores = <bool Function(EstadoEquipamento)>[
        (estado) => estado.saturacao,
        (estado) => estado.taraEmAndamento,
        (estado) => estado.semCalibracao,
        (estado) => estado.erroAdc,
        (estado) => estado.modoBruto,
        (estado) => estado.aquisicaoEmAndamento,
      ];
      List<bool> bits(int status) => [
        for (final ler in leitores)
          ler(EstadoEquipamento.decodificar(estadoComStatus(status))),
      ];

      for (var bit = 0; bit < leitores.length; bit++) {
        expect(bits(1 << bit), [
          for (var outro = 0; outro < leitores.length; outro++) outro == bit,
        ], reason: 'bit $bit');
      }
      expect(bits(0xFFC0), everyElement(isFalse));
    });

    for (final tamanho in [0, 12, 14]) {
      test('rejeita um estado de $tamanho bytes', () {
        final dados = Uint8List.fromList(
          [...bytesHex(estadoFirmware), 0x00].take(tamanho).toList(),
        );

        expect(
          () => EstadoEquipamento.decodificar(dados),
          throwsFormatException,
        );
      });
    }

    for (final versao in [1, 3]) {
      test('rejeita a versão $versao', () {
        final dados = bytesHex(estadoFirmware)..[0] = versao;

        expect(
          () => EstadoEquipamento.decodificar(dados),
          throwsFormatException,
        );
      });
    }
  });
}
