import '../../../nucleo/modelos/amostra_forca.dart';
import 'validar_timestamps.dart';

class MetricasForca {
  const MetricasForca({
    required this.forcaMaximaN,
    required this.forcaMediaN,
    required this.duracaoS,
    required this.impulsoNs,
  });

  final double forcaMaximaN;

  /// Média aritmética das amostras, sem ponderação pelo tempo.
  final double forcaMediaN;
  final double duracaoS;
  final double impulsoNs;
}

/// Exige timestamps estritamente crescentes.
///
/// O impulso usa integração trapezoidal com os intervalos medidos.
MetricasForca calcularMetricasForca(List<AmostraForca> amostras) {
  if (amostras.length < 2) {
    throw ArgumentError('São necessárias pelo menos duas amostras.');
  }

  validarTimestamps(amostras);

  var maxima = amostras.first.forcaN;
  var soma = 0.0;
  var impulso = 0.0;

  for (var indice = 0; indice < amostras.length; indice++) {
    final forca = amostras[indice].forcaN;
    if (forca > maxima) maxima = forca;
    soma += forca;

    if (indice > 0) {
      final dt =
          (amostras[indice].timestampUs - amostras[indice - 1].timestampUs) /
          1e6;
      impulso += 0.5 * (amostras[indice - 1].forcaN + forca) * dt;
    }
  }

  final duracao =
      (amostras.last.timestampUs - amostras.first.timestampUs) / 1e6;

  return MetricasForca(
    forcaMaximaN: maxima,
    forcaMediaN: soma / amostras.length,
    duracaoS: duracao,
    impulsoNs: impulso,
  );
}
