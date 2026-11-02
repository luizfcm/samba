import 'package:flutter/material.dart';

import 'nucleo/aquisicao/fonte_forca_simulada.dart';
import 'nucleo/persistencia/banco_local.dart';
import 'tela_grafico_sessao.dart';
import 'nucleo/aquisicao/series_simuladas.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaTesteBanco(),
    ),
  );
}

class TelaTesteBanco extends StatefulWidget {
  const TelaTesteBanco({super.key});

  @override
  State<TelaTesteBanco> createState() => _TelaTesteBancoState();
}

class _TelaTesteBancoState extends State<TelaTesteBanco> {
  bool _ocupado = false;
  String _mensagem = 'Pronto para iniciar a simulação.';

  List<Map<String, Object?>> _sessoes = [];

  @override
  void initState() {
    super.initState();
    _carregarSessoes();
  }

  Future<void> _carregarSessoes() async {
    final registros = await BancoLocal.listarSessoes();

    if (!mounted) return;

    setState(() {
      _sessoes = registros;
    });
  }

  Future<void> _executarTeste() async {
    if (_ocupado) return;

    setState(() {
      _ocupado = true;
      _mensagem = 'Coletando simulação completa a 1.000 Hz...';
    });

    // Gera a série completa de 10 repetições.
    final serieCompleta = gerarSerieIsometria();

    // Identifica automaticamente a quantidade de amostras.
    final quantidadeEsperada = serieCompleta.length;

    // Utiliza a fonte simulada original do SAMBA.
    final fonte = FonteForcaSimulada(forcasN: serieCompleta);

    try {
      // Prepara a escuta antes de iniciar o simulador.
      final coleta = fonte.amostras
          .take(quantidadeEsperada)
          .toList()
          .timeout(const Duration(minutes: 3));

      final inicioUtc = DateTime.now().toUtc();

      final cronometroColeta = Stopwatch()..start();

      await fonte.iniciar();

      // Aguarda o recebimento das 1.000 amostras.
      final amostras = await coleta;

      cronometroColeta.stop();

      await fonte.parar();

      // Mede o tempo da gravação no SQLite.
      final cronometro = Stopwatch()..start();

      final sessaoId = await BancoLocal.salvarSessao(
        exercicio: 'remada',
        inicioUtc: inicioUtc,
        frequenciaHz: 1000,
        amostras: amostras,
      );

      cronometro.stop();

      // Verifica quantas amostras foram realmente salvas.
      final quantidadeSalva = await BancoLocal.contarAmostras(sessaoId);

      await _carregarSessoes();

      if (!mounted) return;

      setState(() {
        _mensagem =
            'Recebidas: ${amostras.length}\n'
            'Salvas no SQLite: $quantidadeSalva\n'
            'Tempo de coleta: '
            '${cronometroColeta.elapsedMilliseconds} ms\n'
            'Tempo de gravação: '
            '${cronometro.elapsedMilliseconds} ms';
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _mensagem = 'Erro durante o teste: $erro';
      });
    } finally {
      await fonte.parar();

      if (mounted) {
        setState(() {
          _ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SAMBA - Teste SQLite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simulação de força - 1000 Hz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            FilledButton(
              onPressed: _ocupado ? null : _executarTeste,
              child: Text(
                _ocupado ? 'Executando teste...' : 'Iniciar simulação',
              ),
            ),

            const SizedBox(height: 16),

            Text(_mensagem),

            const Divider(height: 32),

            Text(
              'Sessões salvas: ${_sessoes.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _sessoes.length,
                itemBuilder: (context, index) {
                  final sessao = _sessoes[index];

                  return Card(
                    child: ListTile(
                      title: Text('Exercício: ${sessao['exercicio']}'),
                      subtitle: Text(
                        'Amostras: ${sessao['total_amostras']}\n'
                        'Frequência: ${sessao['frequencia_hz']} Hz',
                      ),
                      isThreeLine: true,

                      onTap: () {
                        final id = sessao['id'] as String;

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                TelaGraficoSessao(sessaoId: id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
