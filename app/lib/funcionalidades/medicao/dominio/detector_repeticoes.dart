import '../../../nucleo/modelos/amostra_forca.dart';
import 'validar_timestamps.dart';

class Repeticao {
  const Repeticao({required this.indiceInicio, required this.indiceFim});

  final int indiceInicio;

  /// Exclusivo: aponta para a amostra que encerrou a repetição ou para o fim
  /// da lista.
  final int indiceFim;
}

/// Exige timestamps estritamente crescentes. Os limiares são frações da
/// amplitude acima da linha de base, o percentil [percentilLinhaBase] da força
/// da série, com histerese entre o início e o fim.
List<Repeticao> detectarRepeticoes(
  List<AmostraForca> amostras, {
  double fracaoInicio = 0.2,
  double fracaoFim = 0.1,
  int duracaoMinimaUs = 300000,
  double percentilLinhaBase = 0.1,
}) {
  if (!(fracaoInicio > 0 && fracaoInicio <= 1) ||
      !(fracaoFim > 0 && fracaoFim <= 1)) {
    throw ArgumentError('As frações devem estar no intervalo (0, 1].');
  }
  if (fracaoFim >= fracaoInicio) {
    throw ArgumentError('A fração de fim deve ser menor que a de início.');
  }
  if (!(percentilLinhaBase >= 0 && percentilLinhaBase < 1)) {
    throw ArgumentError('O percentil da linha de base deve estar em [0, 1).');
  }
  validarTimestamps(amostras);
  if (amostras.isEmpty) return const [];

  final forcasN = [for (final amostra in amostras) amostra.forcaN]..sort();
  final pico = forcasN.last;
  final linhaBaseN =
      forcasN[(percentilLinhaBase * (forcasN.length - 1)).floor()];
  if (pico <= 0 || pico <= linhaBaseN) return const [];

  final amplitudeN = pico - linhaBaseN;
  final limiarInicioN = linhaBaseN + fracaoInicio * amplitudeN;
  final limiarFimN = linhaBaseN + fracaoFim * amplitudeN;
  final repeticoes = <Repeticao>[];

  void registrar(int inicio, int fim) {
    if (fim - inicio < 2) return;
    final duracaoUs =
        amostras[fim - 1].timestampUs - amostras[inicio].timestampUs;
    if (duracaoUs < duracaoMinimaUs) return;
    repeticoes.add(Repeticao(indiceInicio: inicio, indiceFim: fim));
  }

  int? inicio;
  for (var indice = 0; indice < amostras.length; indice++) {
    final forcaN = amostras[indice].forcaN;
    if (inicio == null) {
      if (forcaN >= limiarInicioN) inicio = indice;
    } else if (forcaN < limiarFimN) {
      registrar(inicio, indice);
      inicio = null;
    }
  }
  if (inicio != null) registrar(inicio, amostras.length);

  return List.unmodifiable(repeticoes);
}
