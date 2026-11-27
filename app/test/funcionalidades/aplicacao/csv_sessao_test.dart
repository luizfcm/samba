import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/aplicacao/csv_sessao.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca criarAmostra(
  int sequencia,
  int timestampUs,
  double forcaN,
  int status,
) => AmostraForca(
  sequencia: sequencia,
  timestampUs: timestampUs,
  forcaN: forcaN,
  status: status,
);

SessaoMedicao criarSessao(List<AmostraForca> amostras) {
  final sessao = SessaoMedicao(
    exercicio: Exercicio.salto,
    inicio: DateTime.utc(2026, 11),
  );
  amostras.forEach(sessao.adicionarAmostra);
  return sessao;
}

void main() {
  group('gerarCsvSessao', () {
    test('gera o cabeçalho e uma linha por amostra', () {
      final csv = gerarCsvSessao(
        criarSessao([
          criarAmostra(0, 0, 735.75, 0),
          criarAmostra(1, 1000, 1806.225, 0),
          criarAmostra(2, 4295968296, 0, 0x21),
        ]),
      );

      expect(
        csv,
        'sequencia,timestamp_us,forca_n,status\n'
        '0,0,735.75,0\n'
        '1,1000,1806.225,0\n'
        '2,4295968296,0.0,33\n',
      );
    });

    test('preserva força negativa com ponto decimal', () {
      final linhas = gerarCsvSessao(
        criarSessao([criarAmostra(7, 2500, -1.5, 0)]),
      ).split('\n');

      expect(linhas[1], '7,2500,-1.5,0');
    });

    test('gera só o cabeçalho para uma sessão sem amostras', () {
      expect(
        gerarCsvSessao(criarSessao([])),
        'sequencia,timestamp_us,forca_n,status\n',
      );
    });
  });
}
