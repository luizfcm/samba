
import 'package:supabase_flutter/supabase_flutter.dart';

import '../persistencia/banco_local.dart';

class TesteSupabase {
  static Future<String> enviarUltimaSessao() async {
    final supabase = Supabase.instance.client;

    // Autentica um usuário de teste, se necessário.
    var usuario = supabase.auth.currentUser;

    if (usuario == null) {
      final resposta =
          await supabase.auth.signInAnonymously();
      usuario = resposta.user;
    }

    if (usuario == null) {
      throw StateError('Falha na autenticação.');
    }

    // Recupera as sessões do SQLite.
    final sessoes = await BancoLocal.listarSessoes();

    if (sessoes.isEmpty) {
      throw StateError('Nenhuma sessão local encontrada.');
    }

    final sessao = sessoes.first;
    final id = sessao['id'] as String;

    // Envia somente os metadados da sessão.
    await supabase.from('sessoes_teste').upsert({
      'id': id,
      'usuario_id': usuario.id,
      'exercicio': sessao['exercicio'],
      'inicio_utc': sessao['inicio_utc'],
      'frequencia_hz': sessao['frequencia_hz'],
      'total_amostras': sessao['total_amostras'],
    }, onConflict: 'id');

    // Confirma consultando o registro na nuvem.
    final resultado = await supabase
        .from('sessoes_teste')
        .select('id, exercicio, total_amostras')
        .eq('id', id)
        .single();

    return 'Sessão confirmada no Supabase!\n'
        'Exercício: ${resultado['exercicio']}\n'
        'Amostras informadas: ${resultado['total_amostras']}';
  }
}
