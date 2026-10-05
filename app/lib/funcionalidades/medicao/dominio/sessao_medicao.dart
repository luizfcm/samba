import '../../../nucleo/modelos/amostra_forca.dart';
import 'exercicio.dart';

class SessaoMedicao {
  SessaoMedicao({required this.exercicio, DateTime? inicio})
    : inicio = inicio ?? DateTime.now();

  final Exercicio exercicio;
  final DateTime inicio;
  DateTime? _termino;
  final List<AmostraForca> _amostras = [];

  DateTime? get termino => _termino;
  bool get ativa => _termino == null;
  bool get finalizada => !ativa;
  int get quantidadeAmostras => _amostras.length;

  /// Cópia não modificável; não acompanha adições posteriores à sessão.
  List<AmostraForca> get amostras => List.unmodifiable(_amostras);

  /// Duração dos dados em segundos, independente dos instantes de calendário.
  /// Não há intervalo de aquisição definido com menos de duas amostras.
  double? get duracaoDadosS {
    if (_amostras.length < 2) return null;
    return (_amostras.last.timestampUs - _amostras.first.timestampUs) / 1e6;
  }

  void adicionarAmostra(AmostraForca amostra) {
    if (finalizada) {
      throw StateError(
        'Não é possível adicionar amostras à sessão finalizada.',
      );
    }
    _amostras.add(amostra);
  }

  void finalizar({DateTime? termino}) {
    if (finalizada) {
      throw StateError('A sessão já foi finalizada.');
    }
    _termino = termino ?? DateTime.now();
  }
}
