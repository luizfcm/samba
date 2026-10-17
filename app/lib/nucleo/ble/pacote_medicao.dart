import 'dart:typed_data';

import '../modelos/amostra_forca.dart';

class PacoteMedicao {
  static const int tamanhoCabecalho = 16;
  static const int tamanhoBloco = 6;
  static const int versaoSuportada = 2;

  /// Cabeçalho de 16 bytes e N blocos de 6 bytes em little-endian; o status
  /// não é interpretado e se repete em todas as amostras.
  static List<AmostraForca> decodificar(Uint8List dados) {
    if (dados.length < tamanhoCabecalho) {
      throw FormatException(
        'Tamanho de pacote inválido: ${dados.length}, mínimo $tamanhoCabecalho',
      );
    }

    final leitura = ByteData.sublistView(dados);

    final versao = leitura.getUint8(0);
    if (versao != versaoSuportada) {
      throw FormatException('Versão de pacote não suportada: $versao');
    }

    final quantidade = leitura.getUint8(1);
    if (quantidade == 0) {
      throw const FormatException('Pacote sem amostras');
    }

    final tamanhoEsperado = tamanhoCabecalho + tamanhoBloco * quantidade;
    if (dados.length != tamanhoEsperado) {
      throw FormatException(
        'Tamanho de pacote inválido: ${dados.length}, esperado $tamanhoEsperado',
      );
    }

    final status = leitura.getUint16(2, Endian.little);
    final sequencia = leitura.getUint32(4, Endian.little);
    var timestampUs = leitura.getUint64(8, Endian.little);
    final amostras = <AmostraForca>[];

    for (var indice = 0; indice < quantidade; indice++) {
      final deslocamento = tamanhoCabecalho + tamanhoBloco * indice;
      final forcaMilinewtons = leitura.getInt32(deslocamento, Endian.little);
      final deltaUs = leitura.getUint16(deslocamento + 4, Endian.little);

      if (indice == 0 && deltaUs != 0) {
        throw FormatException(
          'Delta da primeira amostra deve ser zero: $deltaUs',
        );
      }
      if (indice > 0 && deltaUs == 0) {
        throw FormatException('Delta zero na amostra $indice');
      }

      timestampUs += deltaUs;
      amostras.add(
        AmostraForca(
          sequencia: sequencia + indice,
          timestampUs: timestampUs,
          forcaN: forcaMilinewtons / 1000.0,
          status: status,
        ),
      );
    }

    return List.unmodifiable(amostras);
  }
}
