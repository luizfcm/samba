# Protocolo BLE — pacote de medição versão 1

Este documento registra o formato do pacote de medição atualmente suportado por `PacoteMedicao.decodificar`: versão **1**, identificada pelo valor `1` no primeiro byte do pacote.

## Formato binário

O pacote tem exatamente 20 bytes. Os campos multibyte usam little-endian.

| Offset | Bytes | Campo no formato | Tipo |
|---:|---:|---|---|
| 0 | 1 | version | uint8 |
| 1 | 1 | flags | uint8 |
| 2 | 4 | sequence | uint32 |
| 6 | 8 | timestamp_us | uint64 |
| 14 | 4 | force_mN | int32 |
| 18 | 2 | status | uint16 |

Os nomes da tabela identificam os campos binários. No modelo Dart, `sequence` corresponde a `sequencia` e `force_mN` é convertido para `forcaN` pela divisão por 1000.

O timestamp representa o instante de aquisição no relógio da fonte, em microssegundos; não é uma data de calendário. A força é expressa em milinewtons no pacote e em newtons no aplicativo, preservando valores negativos.

O decodificador rejeita tamanhos diferentes de 20 bytes e versões diferentes de 1 com `FormatException`. O campo `flags` não é interpretado. `status` é preservado como inteiro, sem definição de bits no código atual. A sequência é preservada pelo decodificador; a detecção de perdas e de amostras fora de ordem é feita pelo `ControladorMedicao`.

## Transporte e controle

Não há serviço GATT implementado nem UUIDs definidos. A especificação inicial registra `Measurement` como Notify e `Control` como Write, com os seguintes opcodes:

| Opcode | Comando |
|---:|---|
| 0x01 | START |
| 0x02 | STOP |
| 0x03 | TARE |
| 0x04 | GET_STATUS |

Esses comandos não são implementados. Não estão definidos formatos de resposta, semântica dos bits de status ou regras de reinício da sequência no dispositivo. A validação atual se limita à decodificação de pacotes em testes unitários.
