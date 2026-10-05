import 'dart:typed_data';

import '../modelos/amostra_forca.dart';

class PacoteMedicao {
  static const int tamanhoPacote = 20;
  static const int versaoSuportada = 1;

  /// Pacote de 20 bytes em little-endian; o campo flags não é interpretado.
  static AmostraForca decodificar(Uint8List dados) {
    if (dados.length != tamanhoPacote) {
      throw FormatException(
        'Tamanho de pacote inválido: ${dados.length}, esperado $tamanhoPacote',
      );
    }

    final leitura = ByteData.sublistView(dados);

    final versao = leitura.getUint8(0);
    if (versao != versaoSuportada) {
      throw FormatException('Versão de pacote não suportada: $versao');
    }

    final sequencia = leitura.getUint32(2, Endian.little);
    final timestampUs = leitura.getUint64(6, Endian.little);
    final forcaMilinewtons = leitura.getInt32(14, Endian.little);
    final status = leitura.getUint16(18, Endian.little);

    return AmostraForca(
      sequencia: sequencia,
      timestampUs: timestampUs,
      forcaN: forcaMilinewtons / 1000.0,
      status: status,
    );
  }
}
