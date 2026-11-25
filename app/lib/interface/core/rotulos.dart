import '../../funcionalidades/medicao/dominio/exercicio.dart';

String rotuloExercicio(Exercicio exercicio) => switch (exercicio) {
  Exercicio.salto => 'Salto Vertical',
  Exercicio.remada => 'Remada - Isometria',
  Exercicio.extensora => 'Extensora - Isometria',
  Exercicio.terra => 'Levantamento Terra',
};

const _meses = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

String formatarDataHistorico(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$dia ${_meses[data.month - 1]}, $hora:$minuto';
}
