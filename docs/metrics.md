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

## Detecção de repetições

`detectarRepeticoes(amostras, {fracaoInicio = 0.2, fracaoFim = 0.1, duracaoMinimaUs = 300000})` devolve uma lista não modificável de `Repeticao`, com `indiceInicio` e `indiceFim` (exclusivo) na lista de amostras.

O pico é a maior força da série. Uma repetição começa na primeira amostra com força maior ou igual a `fracaoInicio × pico` e termina na primeira amostra seguinte com força menor que `fracaoFim × pico`, que fica fora do trecho. Se a série acabar durante uma contração, a repetição vai até a última amostra. Como os limiares dependem do pico de toda a série, um pico isolado alto eleva os limiares das demais repetições.

São descartados os trechos com menos de duas amostras ou com duração menor que `duracaoMinimaUs`, medida do timestamp da primeira à última amostra do trecho. Lista vazia ou pico menor ou igual a zero devolve lista vazia.

## Validação

- `calcularMetricasForca` exige pelo menos duas amostras.
- `calcularMetricasForca` e `detectarRepeticoes` exigem timestamps estritamente crescentes.
- `detectarRepeticoes` exige frações em (0, 1] e `fracaoFim` menor que `fracaoInicio`.
- Entradas inválidas produzem `ArgumentError`; `ProcessadorIsometria` repassa esses erros sem alteração.
