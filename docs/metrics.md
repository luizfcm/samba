# Métricas de força

As forças estão em newtons e os timestamps em microssegundos.

## Métricas gerais

`calcularMetricasForca` recebe uma lista de `AmostraForca` e retorna `MetricasForca`:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `forcaMaximaN` | Força máxima | N | Maior valor da lista, sem valor absoluto |
| `forcaMediaN` | Força média | N | Média aritmética das amostras, sem ponderação pelo tempo |
| `duracaoS` | Duração | s | Diferença entre o último e o primeiro timestamp, dividida por 10⁶ |
| `impulsoNs` | Impulso | N·s | Integração trapezoidal da força com os intervalos medidos |

A contribuição de cada par de amostras consecutivas ao impulso é:

```text
Δt = (timestampUs[i] − timestampUs[i−1]) / 10⁶
impulso = (forcaN[i−1] + forcaN[i]) × Δt / 2
```

Forças e impulsos negativos são preservados.

## Isometria

`ProcessadorIsometria`, usado em remada e extensora, retorna `ResultadoIsometria`:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `metricas` | Métricas de força | — | `calcularMetricasForca` sobre a série; o pico é `metricas.forcaMaximaN` |
| `instantePicoS` | Instante do pico | s | Primeira amostra com força igual ao pico |
| `repeticoes` | Repetições | — | Lista não modificável de `ResultadoRepeticao`, em ordem |
| `mediaPicosN` | Média dos picos | N | Média de `picoN` das repetições; nula sem repetições |

Cada repetição vem de `detectarRepeticoes` com os valores padrão, e suas métricas, de `calcularMetricasForca` sobre o trecho:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `inicioS` | Início | s | Primeira amostra do trecho |
| `duracaoS` | Duração | s | `duracaoS` do trecho |
| `picoN` | Pico | N | `forcaMaximaN` do trecho |
| `instantePicoS` | Instante do pico | s | Primeira amostra do trecho com força igual ao pico |
| `impulsoNs` | Impulso | N·s | `impulsoNs` do trecho |

Todos os instantes são relativos à primeira amostra da série. Em empate no pico, vale o primeiro instante. O mapa de parâmetros não é usado.

### RFD e força sustentada

`ProcessadorIsometria({limiarInicioN = 10, janelasRfdUs = [50000, 100000, 200000], janelaRfdMaximaUs = 20000, janelaForcaSustentadaUs = 1000000})` acrescenta a cada repetição, sempre pelos timestamps:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `inicioContracaoS` | Início da contração | s | Última amostra antes do início detectado com força ≤ linha de base + `limiarInicioN`; a linha de base é a mediana da força desde o fim da repetição anterior (ou o início da série) até o início detectado |
| `rfdJanelas` | RFD média | N/s | `(F(início + janela) − F(início)) / janela` para cada janela de `janelasRfdUs`; nula se a repetição terminar antes do fim da janela |
| `rfdMaxima` | RFD máxima | N/s | Maior `(F(t + janela) − F(t)) / janela`, com `janelaRfdMaximaUs`, para `t` de amostra em amostra do início da contração até o pico |
| `rfdPercentualPorS` | RFD relativa | %Fmáx/s | Cada RFD dividida por `picoN`, vezes 100 |
| `forcaSustentadaN` | Força sustentada | N | Maior média das amostras numa janela de `janelaForcaSustentadaUs` dentro da repetição |
| `desvioForcaSustentadaN` | Variabilidade | N | Desvio padrão das amostras dessa janela |
| `coeficienteVariacaoPercentual` | Coeficiente de variação | % | Desvio dessa janela dividido pela sua média, vezes 100 |

`F(t)` entre amostras é interpolada linearmente pelo tempo. A força sustentada, o desvio e o coeficiente são nulos quando a repetição dura menos que a janela; a RFD máxima é nula quando a janela não cabe entre o início da contração e o pico.

## Detecção de repetições

`detectarRepeticoes(amostras, {fracaoInicio = 0.2, fracaoFim = 0.1, duracaoMinimaUs = 300000})` devolve uma lista não modificável de `Repeticao`, com `indiceInicio` e `indiceFim` (exclusivo) na lista de amostras.

O pico é a maior força da série. Uma repetição começa na primeira amostra com força maior ou igual a `fracaoInicio × pico` e termina na primeira amostra seguinte com força menor que `fracaoFim × pico`, que fica fora do trecho. Se a série acabar durante uma contração, a repetição vai até a última amostra. Como os limiares dependem do pico de toda a série, um pico isolado alto eleva os limiares das demais repetições.

São descartados os trechos com menos de duas amostras ou com duração menor que `duracaoMinimaUs`, medida do timestamp da primeira à última amostra do trecho. Lista vazia ou pico menor ou igual a zero devolve lista vazia.

## Salto

`ProcessadorSalto({duracaoRepousoInicialUs = 1000000, forcaMinimaRepousoN = 200, fracaoVoo = 0.1, duracaoMinimaVooUs = 100000, duracaoMaximaVooUs = 1000000, fracaoRepouso = 0.05, duracaoMinimaRepousoUs = 100000})` retorna `ResultadoSalto`, com g = 9,81 m/s². O mapa de parâmetros não é usado.

A massa é a média da força, dividida por g, na primeira janela de `duracaoRepousoInicialUs` em que a média passa de `forcaMinimaRepousoN` e o desvio padrão fica abaixo de 2% da média; o mínimo evita confundir a plataforma vazia com a pessoa parada. O peso é `massa × g`, e a busca de saltos começa no fim dessa janela. Um voo é um trecho com força menor que `fracaoVoo × peso` que dura de `duracaoMinimaVooUs` a `duracaoMaximaVooUs`; trechos mais longos são a pessoa fora da plataforma e são ignorados. A decolagem é a primeira amostra do trecho e a aterrissagem, a primeira amostra depois dele. O início do salto é a última amostra do último trecho antes da decolagem em que a força fica dentro de `peso ± fracaoRepouso × peso` por pelo menos `duracaoMinimaRepousoUs`. A busca não passa da aterrissagem do salto anterior; sem esse repouso, o salto é ignorado.

Do início até a última amostra antes da decolagem, cada `PontoSalto` traz:

```text
a = (F − m·g) / m
v[i] = v[i−1] + (a[i−1] + a[i]) × Δt / 2,  com v = 0 no início
P = F · v
```

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `inicioS`, `decolagemS`, `aterrissagemS` | Instantes | s | Relativos à primeira amostra da série |
| `tempoVooS` | Tempo de voo | s | Aterrissagem menos decolagem |
| `velocidadeDecolagemMs` | Velocidade de decolagem | m/s | Velocidade da última amostra antes do voo |
| `alturaVooM` | Altura pelo voo | m | `g × tempoVooS² / 8` |
| `alturaVelocidadeM` | Altura pela velocidade | m | `velocidadeDecolagemMs² / (2 × g)` |
| `potenciaMaximaW` | Potência máxima | W | Maior `P` do início à decolagem |
| `forcaMaximaN` | Força máxima | N | Maior força do início à decolagem |

As fases são separadas pela velocidade. A frenagem (excêntrica) vai do instante de velocidade mínima até a primeira amostra seguinte com `v ≥ 0`, o ponto mais baixo; a propulsão (concêntrica) vai do ponto mais baixo até a última amostra antes da decolagem. Sem velocidade negativa que volte a zero antes da decolagem, as métricas da frenagem são nulas e a propulsão começa no início do salto. Integrais pela regra do trapézio com os intervalos medidos:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `velocidadeMinimaMs` | Velocidade mínima | m/s | Menor `v` do salto |
| `tempoFrenagemS` | Tempo de frenagem | s | Duração da frenagem |
| `impulsoExcentricoNs` | Impulso excêntrico | N·s | `∫ (F − m·g) dt` na frenagem |
| `rfdFrenagemNPorS` | RFD da frenagem | N/s | `(F no fim − F no início) / tempoFrenagemS` |
| `impulsoConcentricoNs` | Impulso concêntrico | N·s | `∫ (F − m·g) dt` na propulsão |
| `forcaMaximaConcentricaN` | Força máxima concêntrica | N | Maior força na propulsão |
| `potenciaMediaConcentricaW` | Potência média concêntrica | W | `∫ P dt` na propulsão dividida pela sua duração; nula se a propulsão tiver uma amostra só |

`ResultadoSalto` traz `massaKg`, a lista não modificável de saltos, `alturaMediaM` (média de `alturaVooM`) e `melhorSalto` (maior `alturaVooM`, o primeiro em empate); os dois são nulos sem saltos. `indiceFadigaPercentual` é `100 × (1 − soma das alturas / (melhor altura × número de saltos))`, com as alturas pelo voo, e é nulo com menos de dois saltos.

## Validação

- `calcularMetricasForca` exige pelo menos duas amostras.
- `calcularMetricasForca`, `detectarRepeticoes` e `ProcessadorSalto` exigem timestamps estritamente crescentes.
- `detectarRepeticoes` exige frações em (0, 1] e `fracaoFim` menor que `fracaoInicio`.
- `ProcessadorIsometria` exige `limiarInicioN` maior ou igual a zero e janelas positivas.
- `ProcessadorSalto` exige uma série com pelo menos `duracaoRepousoInicialUs` e uma janela de repouso que atenda às condições da massa.
- Entradas inválidas produzem `ArgumentError`; `ProcessadorIsometria` repassa esses erros sem alteração.
