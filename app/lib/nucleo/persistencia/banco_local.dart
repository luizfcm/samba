
import 'dart:math' as math;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../modelos/amostra_forca.dart';

class BancoLocal {
  static Database? _banco;

  // Abre ou cria o banco de dados do SAMBA.
  static Future<Database> abrir() async {
    if (_banco != null) return _banco!;

    final caminho = join(
      await getDatabasesPath(),
      'samba_local.db',
    );

    _banco = await openDatabase(
      caminho,
      version: 1,

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        // Cada registro representa uma sessão de exercício.
        await db.execute('''
          CREATE TABLE sessoes (
            id TEXT PRIMARY KEY,
            exercicio TEXT NOT NULL,
            inicio_utc TEXT NOT NULL,
            frequencia_hz INTEGER NOT NULL,
            total_amostras INTEGER NOT NULL,
            sincronizado INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Cada registro representa uma amostra de força.
        await db.execute('''
          CREATE TABLE amostras (
            sessao_id TEXT NOT NULL,
            sequencia INTEGER NOT NULL,
            timestamp_us INTEGER NOT NULL,
            forca_n REAL NOT NULL,
            status INTEGER NOT NULL,

            PRIMARY KEY (sessao_id, sequencia),

            FOREIGN KEY (sessao_id)
              REFERENCES sessoes(id)
              ON DELETE CASCADE
          )
        ''');
      },
    );

    return _banco!;
  }

  // Salva uma sessão e todas as suas amostras.
  static Future<String> salvarSessao({
    required String exercicio,
    required DateTime inicioUtc,
    required int frequenciaHz,
    required List<AmostraForca> amostras,
  }) async {
    if (amostras.isEmpty) {
      throw ArgumentError('A sessão não possui amostras.');
    }

    final db = await abrir();
    final sessaoId = const Uuid().v4();

    await db.transaction((txn) async {
      // Primeiro, salva os dados gerais da sessão.
      await txn.insert('sessoes', {
        'id': sessaoId,
        'exercicio': exercicio,
        'inicio_utc': inicioUtc.toUtc().toIso8601String(),
        'frequencia_hz': frequenciaHz,
        'total_amostras': amostras.length,
        'sincronizado': 0,
      });

      // Salva as amostras em lotes de até 500.
      const tamanhoLote = 500;

      for (var inicio = 0;
          inicio < amostras.length;
          inicio += tamanhoLote) {
        final fim = math.min(
          inicio + tamanhoLote,
          amostras.length,
        );

        final lote = txn.batch();

        for (var i = inicio; i < fim; i++) {
          final amostra = amostras[i];

          lote.insert('amostras', {
            'sessao_id': sessaoId,
            'sequencia': amostra.sequencia,
            'timestamp_us': amostra.timestampUs,
            'forca_n': amostra.forcaN,
            'status': amostra.status,
          });
        }

        await lote.commit(noResult: true);
      }
    });

    return sessaoId;
  }

  // Lista as sessões salvas.
  static Future<List<Map<String, Object?>>>
      listarSessoes() async {
    final db = await abrir();

    return db.query(
      'sessoes',
      orderBy: 'inicio_utc DESC',
    );
  }

  // Confere quantas amostras foram realmente armazenadas.
  static Future<int> contarAmostras(
    String sessaoId,
  ) async {
    final db = await abrir();

    final resultado = await db.rawQuery(
      'SELECT COUNT(*) FROM amostras WHERE sessao_id = ?',
      [sessaoId],
    );

    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  // Consulta todas as amostras de uma sessão.
  static Future<List<Map<String, Object?>>> listarAmostrasDaSessao(
    String sessaoId,
  ) async {
    final db = await abrir();

    return db.query(
      'amostras',
      where: 'sessao_id = ?',
      whereArgs: [sessaoId],
      orderBy: 'sequencia ASC',
    );
  }
}
