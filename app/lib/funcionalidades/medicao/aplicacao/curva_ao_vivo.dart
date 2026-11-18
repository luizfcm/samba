import '../../../nucleo/modelos/amostra_forca.dart';
import '../dominio/sessao_medicao.dart';
import 'curva_reduzida.dart';

/// Lê a sessão aos poucos com [SessaoMedicao.amostrasDesde]: cada atualização
/// copia só as amostras novas e descarta as que saíram da janela.
class CurvaAoVivo {
  CurvaAoVivo({
    required this.sessao,
    this.duracaoUs = 5000000,
    this.maximoPontos = 300,
  }) {
    if (duracaoUs <= 0 || maximoPontos < 1) {
      throw ArgumentError(
        'A duração e o número de pontos devem ser positivos.',
      );
    }
  }

  final SessaoMedicao sessao;
  final int duracaoUs;
  final int maximoPontos;
  final List<AmostraForca> _janela = [];
  int _lidas = 0;
  int? _origemUs;

  /// Pontos dos últimos [duracaoUs], com o tempo desde a primeira amostra da
  /// sessão.
  List<PontoCurva> atualizar() {
    final novas = sessao.amostrasDesde(_lidas);
    _lidas += novas.length;
    _janela.addAll(novas);
    if (_janela.isEmpty) return const [];
    _origemUs ??= _janela.first.timestampUs;

    final limiteUs = _janela.last.timestampUs - duracaoUs;
    final primeiraNaJanela = _janela.indexWhere(
      (amostra) => amostra.timestampUs >= limiteUs,
    );
    _janela.removeRange(0, primeiraNaJanela);

    return reduzirCurva(
      _janela,
      maximoPontos: maximoPontos,
      origemUs: _origemUs,
    );
  }
}
