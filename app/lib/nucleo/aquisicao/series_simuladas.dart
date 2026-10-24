import 'dart:math';

const _gravidadeMs2 = 9.81;
const _amostrasPorSegundo = 1000;

int _amostras(double duracaoS) => (duracaoS * _amostrasPorSegundo).round();

/// Uma força por milissegundo. A repetição i, contada a partir de 0, tem pico
/// picoN × (1 − 0,02 × i).
List<double> gerarSerieIsometria({
  int repeticoes = 10,
  double picoN = 400,
  int semente = 1,
  double ruidoN = 2,
}) {
  final aleatorio = Random(semente);
  double ruido() => (aleatorio.nextDouble() * 2 - 1) * ruidoN;
  final forcasN = <double>[];

  void repouso(double duracaoS) {
    for (var indice = 0; indice < _amostras(duracaoS); indice++) {
      forcasN.add(ruido());
    }
  }

  repouso(2);
  for (var repeticao = 0; repeticao < repeticoes; repeticao++) {
    final picoRepeticaoN = picoN * (1 - 0.02 * repeticao);
    final rampa = _amostras(0.5);
    for (var indice = 0; indice < rampa; indice++) {
      forcasN.add(picoRepeticaoN * indice / rampa + ruido());
    }
    for (var indice = 0; indice < _amostras(3); indice++) {
      forcasN.add(picoRepeticaoN + ruido());
    }
    for (var indice = 0; indice < rampa; indice++) {
      forcasN.add(picoRepeticaoN * (rampa - indice) / rampa + ruido());
    }
    repouso(5);
  }
  return forcasN;
}

/// Uma força por milissegundo, calculada a partir da aceleração, para que a
/// velocidade na decolagem corresponda ao tempo de voo.
List<double> gerarSerieSalto({
  int saltos = 10,
  double massaKg = 75,
  double tempoVooS = 0.4,
  int semente = 1,
  double ruidoN = 2,
}) {
  const duracaoFaseS = 0.3;
  const amplitudeDescidaMs2 = 4.0;
  final velocidadeDecolagemMs = _gravidadeMs2 * tempoVooS / 2;
  final amplitudePropulsaoMs2 =
      (velocidadeDecolagemMs + 2 * amplitudeDescidaMs2 * duracaoFaseS / pi) *
      pi /
      (2 * duracaoFaseS);
  final amplitudeAterrissagemMs2 =
      velocidadeDecolagemMs * pi / (2 * duracaoFaseS);
  final pesoN = massaKg * _gravidadeMs2;

  final aleatorio = Random(semente);
  double ruido() => (aleatorio.nextDouble() * 2 - 1) * ruidoN;
  final forcasN = <double>[];

  void repouso(double duracaoS) {
    for (var indice = 0; indice < _amostras(duracaoS); indice++) {
      forcasN.add(pesoN + ruido());
    }
  }

  void fase(double amplitudeMs2) {
    for (var indice = 0; indice < _amostras(duracaoFaseS); indice++) {
      final tempoS = indice / _amostrasPorSegundo;
      final aceleracaoMs2 = amplitudeMs2 * sin(pi * tempoS / duracaoFaseS);
      forcasN.add(massaKg * (_gravidadeMs2 + aceleracaoMs2) + ruido());
    }
  }

  repouso(2);
  for (var salto = 0; salto < saltos; salto++) {
    fase(-amplitudeDescidaMs2);
    fase(amplitudePropulsaoMs2);
    forcasN.addAll(List.filled(_amostras(tempoVooS), 0.0));
    fase(amplitudeAterrissagemMs2);
    repouso(5);
  }
  return forcasN;
}
