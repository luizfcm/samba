import 'dart:typed_data';

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

// Estado lido do mesmo firmware: versão 2, status 0x0004 (sem calibração),
// taxa 1200 Hz, fator 9.1331549 mN/contagem e deslocamento 9162 contagens.
const estadoFirmware = '02 04 00 b0 04 67 21 12 41 ca 23 00 00';

Uint8List estadoComStatus(int status) =>
    bytesHex(estadoFirmware)..setRange(1, 3, [status & 0xFF, status >> 8]);
