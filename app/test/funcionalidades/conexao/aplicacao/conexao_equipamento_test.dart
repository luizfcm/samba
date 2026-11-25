import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/conexao/aplicacao/conexao_equipamento.dart';

void main() {
  group('ConexaoEquipamento', () {
    test('começa desconectada e sem bateria', () {
      final conexao = ConexaoEquipamento();
      expect(conexao.estado, EstadoConexao.desconectado);
      expect(conexao.bateriaNivel, isNull);
      conexao.dispose();
    });

    test('procura e depois conecta', () async {
      final conexao = ConexaoEquipamento(
        duracaoBusca: const Duration(milliseconds: 10),
      );
      final estados = <EstadoConexao>[];
      conexao.addListener(() => estados.add(conexao.estado));

      conexao.conectar();
      expect(conexao.estado, EstadoConexao.procurando);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(estados, [EstadoConexao.procurando, EstadoConexao.conectado]);
      expect(conexao.conectado, isTrue);
      expect(conexao.nomeDispositivo, isNotNull);
      conexao.dispose();
    });

    test('desconectar durante a busca cancela a conexão', () async {
      final conexao = ConexaoEquipamento(
        duracaoBusca: const Duration(milliseconds: 10),
      );
      conexao.conectar();
      conexao.desconectar();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(conexao.estado, EstadoConexao.desconectado);
      expect(conexao.nomeDispositivo, isNull);
      conexao.dispose();
    });

    test('divide a bateria em 4 níveis', () {
      expect(nivelBateria(100), 4);
      expect(nivelBateria(76), 4);
      expect(nivelBateria(75), 3);
      expect(nivelBateria(26), 2);
      expect(nivelBateria(25), 1);
      expect(nivelBateria(1), 1);
      expect(nivelBateria(0), 0);
    });
  });
}
