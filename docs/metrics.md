# Métricas de força

`calcularMetricasForca` recebe uma lista de `AmostraForca` e retorna `MetricasForca`. A força está em newtons e o timestamp em microssegundos.

## Definições

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `forcaMaximaN` | Força máxima | N | Maior valor da lista, sem valor absoluto |
| `forcaMediaN` | Força média | N | Média aritmética das amostras |
| `duracaoS` | Duração | s | Diferença entre o último e o primeiro timestamp, dividida por 10⁶ |
| `impulsoNs` | Impulso | N·s | Integração trapezoidal da força com os intervalos medidos |

Para duas amostras consecutivas, a contribuição ao impulso é:

```text
Δt = (timestampUs[i] − timestampUs[i−1]) / 10⁶
impulso = (forcaN[i−1] + forcaN[i]) × Δt / 2
```

O resultado soma as contribuições de todos os intervalos. Forças e impulsos negativos são preservados. A força média não é ponderada pelo tempo; intervalos irregulares afetam a integração, mas não o peso de cada amostra na média.

## Isometria

`ProcessadorIsometria` implementa `ProcessadorExercicio<ResultadoIsometria>` para remada e extensora. Ele calcula as métricas com `calcularMetricasForca` e retorna `ResultadoIsometria`:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `metricas` | Métricas de força | — | Resultado de `calcularMetricasForca`; o pico de força é `metricas.forcaMaximaN` |
| `instantePicoS` | Instante do pico | s | Timestamp da primeira amostra com força igual ao pico, menos o timestamp da primeira amostra, dividido por 10⁶ |
| `repeticoes` | Repetições | — | Lista não modificável de `ResultadoRepeticao`, na ordem em que ocorrem |
| `mediaPicosN` | Média dos picos | N | Média aritmética de `picoN` das repetições; nula quando não há repetições |

O instante é relativo à primeira amostra da lista, não ao relógio da fonte. Em empate no pico, vale o primeiro instante. O mapa de parâmetros não é usado. Os erros de validação de `calcularMetricasForca` são repassados sem alteração.

Cada repetição é detectada por `detectarRepeticoes` com os valores padrão, e suas métricas vêm de `calcularMetricasForca` aplicado ao trecho:

| Campo | Métrica | Unidade | Cálculo |
|---|---|---|---|
| `inicioS` | Início | s | Timestamp da primeira amostra do trecho, relativo à primeira amostra da série |
| `duracaoS` | Duração | s | `duracaoS` das métricas do trecho |
| `picoN` | Pico | N | `forcaMaximaN` das métricas do trecho |
| `instantePicoS` | Instante do pico | s | Primeira amostra do trecho com força igual ao pico, relativa à primeira amostra da série |
| `impulsoNs` | Impulso | N·s | `impulsoNs` das métricas do trecho |

## Detecção de repetições

`detectarRepeticoes(amostras, {fracaoInicio = 0.2, fracaoFim = 0.1, duracaoMinimaUs = 300000})` devolve uma lista não modificável de `Repeticao`, com `indiceInicio` e `indiceFim` (exclusivo) na lista de amostras.

Os limiares são frações do pico da série, a maior força da lista. Uma repetição começa na primeira amostra com força maior ou igual a `fracaoInicio × pico` e termina na primeira amostra seguinte com força menor que `fracaoFim × pico`; essa amostra fica fora do trecho. A diferença entre os dois limiares funciona como histerese: oscilações em torno do limiar de início não criam repetições extras. Se a série acabar durante uma contração, a repetição vai até a última amostra.

Trechos com menos de duas amostras ou com duração menor que `duracaoMinimaUs` são descartados; a duração é a diferença entre o timestamp da última e o da primeira amostra do trecho. Lista vazia ou pico menor ou igual a zero devolve lista vazia.

As frações devem estar em (0, 1], e `fracaoFim` deve ser menor que `fracaoInicio`; os timestamps devem ser estritamente crescentes. Caso contrário, a função lança `ArgumentError`. Como os limiares dependem do pico de toda a série, um pico isolado muito alto eleva os limiares das demais repetições.

## Validação e limites

São necessárias pelo menos duas amostras, com timestamps estritamente crescentes. Entradas menores, timestamps repetidos ou fora de ordem produzem `ArgumentError` antes do cálculo.

Não há filtragem, remoção de peso corporal, segmentação de movimentos além da detecção de repetições por limiar, detecção de perdas, cálculo de RFD, velocidade ou potência. Também não há validação explícita de forças não finitas.

A força isolada não determina velocidade ou potência para terra, remada e extensora sem um modelo mecânico. No salto, a estimativa de aceleração a partir da força de reação vertical depende da massa e da remoção do peso corporal; essa estimativa não está implementada.
