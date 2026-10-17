# Protocolo BLE — versão 2

Este documento especifica a versão **2** do protocolo entre o dispositivo SAMBA e o aplicativo: pacote de medição em lote, serviço GATT, comandos e característica de estado. O pacote de medição é identificado pelo valor `2` no primeiro byte.

## Aquisição

O firmware do ESP32-S3 lê o ADC ADS1220 a 1000 Hz. A calibração e a tara são feitas no firmware, que guarda o fator e o deslocamento de calibração em NVS. Fora do modo bruto, o pacote transporta a força já convertida em milinewtons.

### Calibração

A força é calculada a partir das contagens do ADC:

```text
força_mN = (contagens − deslocamento) × fator
```

O firmware arredonda o resultado para o inteiro mais próximo antes de enviá-lo em `force_mN`. O deslocamento é expresso em contagens do ADC e o fator em mN por contagem. SET_CALIBRACAO grava os dois valores; TARE grava as contagens atuais como novo deslocamento e mantém o fator.

## Formato binário

Cada pacote reúne N amostras consecutivas: um cabeçalho de 16 bytes seguido de N blocos de 6 bytes, num total de `16 + 6 × N` bytes. Os campos multibyte usam little-endian.

| Offset | Bytes | Campo no formato | Tipo |
|---:|---:|---|---|
| 0 | 1 | version | uint8 |
| 1 | 1 | count | uint8 |
| 2 | 2 | status | uint16 |
| 4 | 4 | sequence | uint32 |
| 8 | 8 | timestamp_us | uint64 |

O bloco da amostra `i`, de 0 a N − 1, começa no offset `16 + 6 × i`:

| Offset no bloco | Bytes | Campo no formato | Tipo |
|---:|---:|---|---|
| 0 | 4 | force_mN | int32 |
| 4 | 2 | delta_us | uint16 |

`count` é a quantidade N de amostras. `sequence` e `timestamp_us` pertencem à primeira amostra; a amostra `i` tem sequência `sequence + i`. `delta_us` é o intervalo em microssegundos desde a amostra anterior do mesmo pacote: vale 0 na primeira amostra e é maior que zero nas seguintes, de modo que `timestamp[i] = timestamp[i − 1] + delta_us[i]`. O intervalo entre amostras consecutivas fica limitado a 65 535 µs. Cada pacote traz o timestamp absoluto da sua primeira amostra, sem depender do pacote anterior.

`status` vale para todas as amostras do pacote. O timestamp é relativo ao relógio do dispositivo, em microssegundos; não é uma data de calendário. A força é expressa em milinewtons, preservando valores negativos.

### Dimensionamento

O pacote leva 20 amostras: `16 + 6 × 20 = 136` bytes. Com os 3 bytes do cabeçalho ATT da notificação, o MTU mínimo é 139. A 1000 Hz, são 50 pacotes por segundo.

### Bits de status

| Bit | Significado |
|---:|---|
| 0 | Saturação |
| 1 | Tara em andamento |
| 2 | Sem calibração |
| 3 | Erro no ADC |
| 4 | Modo bruto: `force_mN` carrega contagens do ADC em vez de mN |
| 5 | Aquisição em andamento: ligado após START, desligado após STOP |
| 6–15 | Reservados |

## Serviço GATT

| Elemento | UUID | Propriedades |
|---|---|---|
| Serviço SAMBA | `1d770001-fc8b-4e8e-aa34-c86e1b9eeaf5` | — |
| Medição | `1d770002-fc8b-4e8e-aa34-c86e1b9eeaf5` | Notify |
| Controle | `1d770003-fc8b-4e8e-aa34-c86e1b9eeaf5` | Write |
| Estado | `1d770004-fc8b-4e8e-aa34-c86e1b9eeaf5` | Read, Notify |

A característica Medição notifica os pacotes descritos acima.

## Comandos

Os comandos são escritos na característica Controle. O primeiro byte é o opcode, seguido dos parâmetros em little-endian.

| Opcode | Comando | Parâmetros | Bytes |
|---:|---|---|---:|
| 0x01 | START | — | 1 |
| 0x02 | STOP | — | 1 |
| 0x03 | TARE | — | 1 |
| 0x04 | MODO_BRUTO | uint8: 1 liga, 0 desliga | 2 |
| 0x05 | SET_CALIBRACAO | fator float32, deslocamento int32 | 9 |

START inicia a aquisição e zera a sequência e o timestamp: a primeira amostra enviada depois dele tem sequência 0 e timestamp 0. STOP interrompe a aquisição. TARE inicia a tara no firmware, sinalizada pelo bit 1 de status enquanto estiver em andamento, e ao terminar grava as contagens atuais como deslocamento. MODO_BRUTO liga ou desliga o envio de contagens do ADC, sinalizado pelo bit 4. SET_CALIBRACAO grava o fator e o deslocamento de calibração.

Os comandos não têm resposta direta. O efeito aparece na característica Estado, que notifica o aplicativo sempre que o status ou a calibração mudam. START e STOP também seguem essa regra: o efeito deles aparece no bit 5 de status, notificado pela característica Estado.

## Estado

A característica Estado tem 13 bytes em little-endian:

| Offset | Bytes | Campo no formato | Tipo |
|---:|---:|---|---|
| 0 | 1 | version | uint8 |
| 1 | 2 | status | uint16 |
| 3 | 2 | rate_hz | uint16 |
| 5 | 4 | calibration_factor | float32 |
| 9 | 4 | calibration_offset | int32 |

`version` é a versão do protocolo, 2. `status` usa os mesmos bits do pacote de medição. `rate_hz` é a taxa de amostragem em hertz. `calibration_factor` é o fator em mN por contagem e `calibration_offset` é o deslocamento em contagens, gravados por SET_CALIBRACAO; o deslocamento também é gravado por TARE.

A característica notifica o aplicativo quando `status`, `calibration_factor` ou `calibration_offset` mudam, e pode ser lida a qualquer momento.

## Implementação no aplicativo

`PacoteMedicao.decodificar` converte um pacote de medição numa lista não modificável de `AmostraForca`. A sequência de cada amostra é a da primeira mais o índice, o timestamp é o da anterior mais `delta_us`, a força em mN é dividida por 1000 e o status do cabeçalho é repetido em todas as amostras, sem interpretação dos bits. No modo bruto, portanto, `forcaN` contém as contagens do ADC divididas por 1000; cabe a quem consome as amostras verificar o bit 4.

O decodificador lança `FormatException` para versão diferente de 2, `count` igual a zero, tamanho diferente de `16 + 6 × count`, `delta_us` diferente de zero na primeira amostra ou igual a zero nas seguintes.

O aplicativo ainda não implementa o serviço GATT, os comandos nem a leitura do estado.
