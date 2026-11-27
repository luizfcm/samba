import 'dart:typed_data';

import 'bits_status.dart';

class EstadoEquipamento {
  const EstadoEquipamento({
    required this.versao,
    required this.status,
    required this.taxaNominalHz,
    required this.fatorMnPorContagem,
    required this.deslocamentoContagens,
  });

  static const int tamanho = 13;
  static const int versaoSuportada = 2;

  final int versao;
  final int status;

  /// Taxa nominal do ADC; o tempo das amostras vem dos timestamps.
  final int taxaNominalHz;
  final double fatorMnPorContagem;
  final int deslocamentoContagens;

  bool get saturacao => status & BitsStatus.saturacao != 0;
  bool get taraEmAndamento => status & BitsStatus.taraEmAndamento != 0;
  bool get semCalibracao => status & BitsStatus.semCalibracao != 0;
  bool get erroAdc => status & BitsStatus.erroAdc != 0;
  bool get modoBruto => status & BitsStatus.modoBruto != 0;
  bool get aquisicaoEmAndamento =>
      status & BitsStatus.aquisicaoEmAndamento != 0;

  /// Característica Estado de 13 bytes em little-endian.
  static EstadoEquipamento decodificar(Uint8List dados) {
    if (dados.length != tamanho) {
      throw FormatException(
        'Tamanho de estado inválido: ${dados.length}, esperado $tamanho',
      );
    }

    final leitura = ByteData.sublistView(dados);

    final versao = leitura.getUint8(0);
    if (versao != versaoSuportada) {
      throw FormatException('Versão de estado não suportada: $versao');
    }

    return EstadoEquipamento(
      versao: versao,
      status: leitura.getUint16(1, Endian.little),
      taxaNominalHz: leitura.getUint16(3, Endian.little),
      fatorMnPorContagem: leitura.getFloat32(5, Endian.little),
      deslocamentoContagens: leitura.getInt32(9, Endian.little),
    );
  }
}
