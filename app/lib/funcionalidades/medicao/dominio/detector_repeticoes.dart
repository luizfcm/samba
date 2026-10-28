import '../../../nucleo/modelos/amostra_forca.dart';
import 'validar_timestamps.dart';

class Repeticao {
  const Repeticao({required this.indiceInicio, required this.indiceFim});

  final int indiceInicio;

  /// Exclusivo: aponta para a amostra que encerrou a repetição ou para o fim
  /// da lista.
  final int indiceFim;
}

/// Exige timestamps estritamente crescentes. Os limiares são frações do pico
/// da série, com histerese entre o início e o fim.
List<Repeticao> detectarRepeticoes(
  List<AmostraForca> amostras, {
  double fracaoInicio = 0.2,
  double fracaoFim = 0.1,
  int duracaoMinimaUs = 300000,
}) {
  if (!(fracaoInicio > 0 && fracaoInicio <= 1) ||
      !(fracaoFim > 0 && fracaoFim <= 1)) {
    throw ArgumentError('As frações devem estar no intervalo (0, 1].');
  }
  if (fracaoFim >= fracaoInicio) {
    throw ArgumentError('A fração de fim deve ser menor que a de início.');
  }
  validarTimestamps(amostras);
  if (amostras.isEmpty) return const [];

  var pico = amostras.first.forcaN;
  for (final amostra in amostras) {
    if (amostra.forcaN > pico) pico = amostra.forcaN;
  }
  if (pico <= 0) return const [];

  final limiarInicioN = fracaoInicio * pico;
  final limiarFimN = fracaoFim * pico;
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
