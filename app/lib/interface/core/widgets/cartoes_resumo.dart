import 'package:flutter/material.dart';

import '../../../funcionalidades/medicao/aplicacao/resumo_sessao.dart';
import '../app_colors.dart';
import '../formatacao.dart';
import 'samba_metrica.dart';

// Widget que exibe os cartões de resumo de uma sessão de medição.
class CartoesResumo extends StatelessWidget {
  const CartoesResumo({super.key, required this.resumo});

  final ResumoSessao resumo;

  @override
  Widget build(BuildContext context) {
    return switch (resumo) {
      ResumoIsometria r => SambaGradeMetricas(
        cartoes: [
          SambaMetrica(
            titulo: 'Força de Pico',
            valor: valorDestaque(r),
            subtitulo: 'repetição de maior pico',
          ),
          SambaMetrica(
            titulo: 'Média dos picos',
            valor: formatarValor(r.mediaPicosN, 0, 'N'),
            subtitulo: '${r.repeticoes} repetições',
          ),
          SambaMetrica(
            titulo: 'RFD máxima',
            valor: formatarValor(r.rfdMaximaNPorS, 0, 'N/s'),
            subtitulo: 'repetição de maior pico',
          ),
          SambaMetrica(
            titulo: 'RFD máxima relativa',
            valor: formatarValor(r.rfdMaximaPercentualPorS, 0, '%Fmáx/s'),
            subtitulo: 'repetição de maior pico',
          ),
          SambaMetrica(
            titulo: 'Força sustentada',
            valor: formatarValor(r.forcaSustentadaN, 0, 'N'),
            subtitulo: 'maior média em 1 s',
          ),
          SambaMetrica(
            titulo: 'Variabilidade',
            valor: formatarValor(r.coeficienteVariacaoPercentual, 1, '%'),
            subtitulo: 'nesse trecho de 1 s',
          ),
        ],
      ),
      ResumoSalto r => SambaGradeMetricas(
        cartoes: [
          SambaMetrica(
            titulo: 'Altura do salto',
            valor: valorDestaque(r),
            subtitulo: '${r.saltos} saltos · melhor',
          ),
          SambaMetrica(
            titulo: 'Índice de fadiga',
            valor: formatarValor(r.indiceFadigaPercentual, 1, '%'),
            subtitulo: 'queda na série',
          ),
          SambaMetrica(
            titulo: 'Potência média',
            valor: formatarValor(r.potenciaMediaConcentricaW, 0, 'W'),
            subtitulo: 'fase concêntrica · melhor salto',
          ),
          SambaMetrica(
            titulo: 'Impulso concêntrico',
            valor: formatarValor(r.impulsoConcentricoNs, 0, 'N·s'),
            subtitulo: 'melhor salto',
          ),
          SambaMetrica(
            titulo: 'Tempo de frenagem',
            valor: formatarValor(r.tempoFrenagemS, 2, 's'),
            subtitulo: 'melhor salto',
          ),
          SambaMetrica(
            titulo: 'RFD de frenagem',
            valor: formatarValor(r.rfdFrenagemNPorS, 0, 'N/s'),
            subtitulo: 'melhor salto',
          ),
        ],
      ),
      ResumoNaoProcessado(:final motivo) => Text(
        motivo,
        style: const TextStyle(color: AppColors.cinza, fontSize: 14),
      ),
    };
  }
}
