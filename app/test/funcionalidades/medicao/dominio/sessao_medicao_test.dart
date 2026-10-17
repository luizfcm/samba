import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/exercicio.dart';
import 'package:samba_app/funcionalidades/medicao/dominio/sessao_medicao.dart';
import 'package:samba_app/nucleo/modelos/amostra_forca.dart';

AmostraForca criarAmostra(int sequencia, int timestampUs, double forcaN) =>
    AmostraForca(
      sequencia: sequencia,
      timestampUs: timestampUs,
      forcaN: forcaN,
      status: 0,
    );

void main() {
  group('SessaoMedicao', () {
    final inicio = DateTime.utc(2026, 10, 4, 12);
    final termino = inicio.add(const Duration(seconds: 10));
    late SessaoMedicao sessao;

    setUp(() {
      sessao = SessaoMedicao(exercicio: Exercicio.salto, inicio: inicio);
    });

    test('cria uma sessão ativa, sem término e sem amostras', () {
      expect(sessao.inicio, inicio);
      expect(sessao.termino, isNull);
      expect(sessao.ativa, isTrue);
      expect(sessao.finalizada, isFalse);
      expect(sessao.amostras, isEmpty);
      expect(sessao.quantidadeAmostras, 0);
      expect(sessao.duracaoDadosS, isNull);
    });

    for (final exercicio in Exercicio.values) {
      test('armazena o exercício ${exercicio.name}', () {
        final sessao = SessaoMedicao(exercicio: exercicio, inicio: inicio);

        expect(sessao.exercicio, exercicio);
      });
    }

    test('registra o instante atual quando o início não é informado', () {
      final antes = DateTime.now();
      final sessao = SessaoMedicao(exercicio: Exercicio.terra);
      final depois = DateTime.now();

      expect(sessao.inicio.isBefore(antes), isFalse);
      expect(sessao.inicio.isAfter(depois), isFalse);
    });

    test('adiciona amostras em ordem e informa a quantidade', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1250000, -5);

      sessao.adicionarAmostra(primeira);
      expect(sessao.quantidadeAmostras, 1);
      sessao.adicionarAmostra(segunda);

      expect(sessao.quantidadeAmostras, 2);
      expect(sessao.amostras, orderedEquals([primeira, segunda]));
      expect(sessao.amostras.last.forcaN, -5);
      expect(sessao.ativa, isTrue);
    });

    test('não informa duração para uma única amostra', () {
      sessao.adicionarAmostra(criarAmostra(0, 1000000, 10));

      expect(sessao.duracaoDadosS, isNull);
    });

    test('calcula a duração pelos timestamps em microssegundos', () {
      sessao.adicionarAmostra(criarAmostra(0, 1000000, 10));
      sessao.adicionarAmostra(criarAmostra(1, 1250000, 20));
      expect(sessao.duracaoDadosS, 0.25);

      sessao.adicionarAmostra(criarAmostra(2, 2500000, 15));
      expect(sessao.duracaoDadosS, 1.5);
    });

    test('a duração dos dados independe dos instantes de calendário', () {
      sessao.adicionarAmostra(criarAmostra(0, 1000000, 10));
      sessao.adicionarAmostra(criarAmostra(1, 1500000, 20));
      sessao.finalizar(termino: termino);

      expect(sessao.termino!.difference(sessao.inicio).inSeconds, 10);
      expect(sessao.duracaoDadosS, 0.5);
    });

    test('finaliza e preserva o exercício, o início e as amostras', () {
      final amostra = criarAmostra(0, 1000000, 10);
      sessao.adicionarAmostra(amostra);
      sessao.finalizar(termino: termino);

      expect(sessao.ativa, isFalse);
      expect(sessao.finalizada, isTrue);
      expect(sessao.termino, termino);
      expect(sessao.inicio, inicio);
      expect(sessao.exercicio, Exercicio.salto);
      expect(sessao.quantidadeAmostras, 1);
      expect(sessao.amostras, [amostra]);
    });

    test('permite finalizar uma sessão sem amostras', () {
      sessao.finalizar(termino: termino);

      expect(sessao.finalizada, isTrue);
      expect(sessao.quantidadeAmostras, 0);
      expect(sessao.duracaoDadosS, isNull);
    });

    test('registra o instante atual quando o término não é informado', () {
      final antes = DateTime.now();
      sessao.finalizar();
      final depois = DateTime.now();

      expect(sessao.termino!.isBefore(antes), isFalse);
      expect(sessao.termino!.isAfter(depois), isFalse);
    });

    test('rejeita novas amostras após a finalização sem alterar os dados', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1500000, 20);
      sessao.adicionarAmostra(primeira);
      sessao.adicionarAmostra(segunda);
      sessao.finalizar(termino: termino);

      expect(
        () => sessao.adicionarAmostra(criarAmostra(2, 2000000, 30)),
        throwsStateError,
      );
      expect(sessao.amostras, [primeira, segunda]);
      expect(sessao.quantidadeAmostras, 2);
      expect(sessao.duracaoDadosS, 0.5);
      expect(sessao.termino, termino);
    });

    test('rejeita segunda finalização e preserva o término original', () {
      sessao.finalizar(termino: termino);

      expect(
        () =>
            sessao.finalizar(termino: termino.add(const Duration(seconds: 1))),
        throwsStateError,
      );
      expect(sessao.termino, termino);
      expect(sessao.finalizada, isTrue);
    });

    test('impede adição, remoção e substituição externas de amostras', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1500000, 20);
      sessao.adicionarAmostra(primeira);
      final amostras = sessao.amostras;

      expect(() => amostras.add(segunda), throwsUnsupportedError);
      expect(() => amostras.removeAt(0), throwsUnsupportedError);
      expect(() => amostras[0] = segunda, throwsUnsupportedError);
      expect(amostras.clear, throwsUnsupportedError);
      expect(sessao.amostras, [primeira]);
      expect(sessao.quantidadeAmostras, 1);
    });

    test('uma cópia externa não acompanha adições posteriores', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1500000, 20);
      sessao.adicionarAmostra(primeira);
      final anteriores = sessao.amostras;
      sessao.adicionarAmostra(segunda);

      expect(anteriores, [primeira]);
      expect(sessao.amostras, [primeira, segunda]);
    });

    test('mantém a coleção protegida depois da finalização', () {
      sessao.adicionarAmostra(criarAmostra(0, 1000000, 10));
      sessao.finalizar(termino: termino);

      expect(sessao.amostras.clear, throwsUnsupportedError);
      expect(sessao.quantidadeAmostras, 1);
    });

    test('lê apenas as amostras a partir do índice informado', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1500000, 20);
      final terceira = criarAmostra(2, 2000000, 30);
      sessao.adicionarAmostra(primeira);
      sessao.adicionarAmostra(segunda);
      sessao.adicionarAmostra(terceira);

      expect(sessao.amostrasDesde(0), [primeira, segunda, terceira]);
      expect(sessao.amostrasDesde(1), [segunda, terceira]);
      expect(sessao.amostrasDesde(2), [terceira]);
    });

    test('devolve lista vazia quando o índice é a quantidade de amostras', () {
      expect(sessao.amostrasDesde(0), isEmpty);

      sessao.adicionarAmostra(criarAmostra(0, 1000000, 10));
      sessao.adicionarAmostra(criarAmostra(1, 1500000, 20));

      expect(sessao.amostrasDesde(sessao.quantidadeAmostras), isEmpty);
    });

    test('rejeita índice negativo ou maior que a quantidade de amostras', () {
      sessao.adicionarAmostra(criarAmostra(0, 1000000, 10));
      sessao.adicionarAmostra(criarAmostra(1, 1500000, 20));

      expect(() => sessao.amostrasDesde(-1), throwsRangeError);
      expect(() => sessao.amostrasDesde(3), throwsRangeError);
      expect(
        () => SessaoMedicao(
          exercicio: Exercicio.remada,
          inicio: inicio,
        ).amostrasDesde(1),
        throwsRangeError,
      );
    });

    test('a leitura parcial não é modificável nem acompanha adições', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1500000, 20);
      sessao.adicionarAmostra(primeira);
      sessao.adicionarAmostra(segunda);
      final recentes = sessao.amostrasDesde(1);

      expect(() => recentes.add(primeira), throwsUnsupportedError);
      expect(() => recentes.removeAt(0), throwsUnsupportedError);
      expect(() => recentes[0] = primeira, throwsUnsupportedError);
      expect(recentes.clear, throwsUnsupportedError);

      sessao.adicionarAmostra(criarAmostra(2, 2000000, 30));
      expect(recentes, [segunda]);
      expect(sessao.amostras, hasLength(3));
    });

    test('permite a leitura parcial após a finalização', () {
      final primeira = criarAmostra(0, 1000000, 10);
      final segunda = criarAmostra(1, 1500000, 20);
      sessao.adicionarAmostra(primeira);
      sessao.adicionarAmostra(segunda);
      sessao.finalizar(termino: termino);

      expect(sessao.amostrasDesde(1), [segunda]);
      expect(sessao.amostrasDesde(2), isEmpty);
      expect(() => sessao.amostrasDesde(3), throwsRangeError);
    });
  });
}
