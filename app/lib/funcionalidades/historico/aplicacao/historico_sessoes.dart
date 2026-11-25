import '../../../nucleo/modelos/amostra_forca.dart';
import '../../../nucleo/persistencia/banco_local.dart';
import '../../medicao/dominio/exercicio.dart';
import '../../medicao/dominio/sessao_medicao.dart';

class ItemHistorico {
  const ItemHistorico({
    required this.id,
    required this.exercicio,
    required this.inicio,
    required this.picoN,
  });

  final String id;
  final Exercicio exercicio;
  final DateTime inicio;
  final double? picoN;

  factory ItemHistorico.deLinha(Map<String, Object?> linha) {
    final nome = linha['exercicio'] as String?;
    final exercicio = Exercicio.values.firstWhere(
      (e) => e.name == nome,
      orElse: () => Exercicio.remada,
    );
    final inicio =
        DateTime.tryParse(linha['inicio_utc'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return ItemHistorico(
      id: linha['id'] as String,
      exercicio: exercicio,
      inicio: inicio,
      picoN: (linha['pico'] as num?)?.toDouble(),
    );
  }
}

Future<List<ItemHistorico>> listarHistorico() async {
  final db = await BancoLocal.abrir();
  final linhas = await db.rawQuery('''
    SELECT s.id, s.exercicio, s.inicio_utc, MAX(a.forca_n) AS pico
    FROM sessoes s
    LEFT JOIN amostras a ON a.sessao_id = s.id
    GROUP BY s.id
    ORDER BY s.inicio_utc DESC
  ''');
  return [for (final linha in linhas) ItemHistorico.deLinha(linha)];
}

Future<SessaoMedicao> carregarSessao(String id) async {
  final db = await BancoLocal.abrir();
  final sessoes = await db.query(
    'sessoes',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (sessoes.isEmpty) throw StateError('Sessão não encontrada.');

  final item = ItemHistorico.deLinha(sessoes.first);
  final linhas = await BancoLocal.listarAmostrasDaSessao(id);

  final sessao = SessaoMedicao(
    exercicio: item.exercicio,
    inicio: item.inicio,
  );
  for (final linha in linhas) {
    sessao.adicionarAmostra(
      AmostraForca(
        sequencia: linha['sequencia'] as int,
        timestampUs: linha['timestamp_us'] as int,
        forcaN: (linha['forca_n'] as num).toDouble(),
        status: linha['status'] as int,
      ),
    );
  }

  final amostras = sessao.amostras;
  final duracaoUs = amostras.length < 2
      ? 0
      : amostras.last.timestampUs - amostras.first.timestampUs;
  sessao.finalizar(termino: item.inicio.add(Duration(microseconds: duracaoUs)));
  return sessao;
}
