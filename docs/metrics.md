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

O instante é relativo à primeira amostra da lista, não ao relógio da fonte. Em empate no pico, vale o primeiro instante. O mapa de parâmetros não é usado. Os erros de validação de `calcularMetricasForca` são repassados sem alteração.

## Validação e limites

São necessárias pelo menos duas amostras, com timestamps estritamente crescentes. Entradas menores, timestamps repetidos ou fora de ordem produzem `ArgumentError` antes do cálculo.

Não há filtragem, remoção de peso corporal, segmentação de movimentos, detecção de perdas, cálculo de RFD, velocidade ou potência. Também não há validação explícita de forças não finitas.

A força isolada não determina velocidade ou potência para terra, remada e extensora sem um modelo mecânico. No salto, a estimativa de aceleração a partir da força de reação vertical depende da massa e da remoção do peso corporal; essa estimativa não está implementada.
