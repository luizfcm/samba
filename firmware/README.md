# Firmware SAMBA (ESP32-S3)

Firmware da placa de aquisição: ESP32-S3-DevKitC-1 (N16R8), ADS1220 e célula de carga tipo S. As leituras são enviadas ao aplicativo por BLE, seguindo o [protocolo BLE v2](../docs/protocolo_ble_v2.md).

## Estrutura

| Pasta | Conteúdo |
| --- | --- |
| `samba_firmware/` | Firmware principal: aquisição a 1200 SPS, tara, calibração e serviço BLE v2 |
| `testes/teste_01_devkit/` | Saúde da DevKit isolada: chip, RAM e PSRAM, clock, rádio Wi-Fi e BLE de teste |
| `testes/teste_02_ads1220/` | ADS1220 na placa soldada: SPI, AVDD e referência, ruído, linearidade e captura |
| `testes/teste_ina226/` | INA226: I²C, identificação, tensão do pack, corrente, potência e autonomia |
| `ferramentas/` | Programas de PC e página Web Bluetooth para testar a placa |
| `mock_ble/` | Reservada (ainda vazia) |

## Hardware

| Sinal | GPIO |
| --- | --- |
| ADS1220 SCLK / MISO (DOUT) / MOSI (DIN) / CS | 12 / 13 / 11 / 10 |
| ADS1220 DRDY (ativo em nível baixo) | 14 |
| INA226 SDA / SCL (endereço 0x40) | 1 / 2 |

- **Medição ratiométrica:** a excitação da célula (E+), a referência do ADS (REFP0) e o AVDD vêm do mesmo LT3042 (5 V).
- **ADS1220:** ganho 128, modo turbo de 1200 SPS (REG1 = 0xB4). A taxa real é ~1164,6 amostras/s, por causa do relógio interno do ADS.
- **Alimentação:** bateria 3S de 18650 (2450 mAh, 12 V) → MP1584EN (5 V da DevKit) e LT3042 (5 V analógico).

## Compilação (Arduino IDE)

- **Placa:** "ESP32S3 Dev Module" (core esp32 3.x).
- **PSRAM:** **"OPI PSRAM"**. O firmware guarda a fila de amostras (60 s) na PSRAM. Sem essa opção, ele avisa no boot e usa uma fila de ~1,7 s.
- **Biblioteca:** NimBLE-Arduino 2.x.
- **Monitor Serial:** 921600 baud, "Nova linha".

Pelo arduino-cli:

```sh
arduino-cli compile --fqbn esp32:esp32:esp32s3:PSRAM=opi samba_firmware
arduino-cli upload  --fqbn esp32:esp32:esp32s3:PSRAM=opi -p COM6 samba_firmware
```

## Firmware principal

**Arquitetura**
- **ISR do DRDY:** carimba o tempo de cada conversão (`esp_timer`, µs).
- **Tarefa de aquisição (núcleo 1):** é a única que acessa o SPI. Lê a amostra, detecta perdas, saturação e ADC travado, aplica tara e calibração e põe a amostra na fila.
- **`loop()`:** monta pacotes de até 20 amostras (136 bytes), notifica a característica Medição, atualiza o Estado e grava a calibração na NVS.
- **NimBLE (núcleo 0):** serviço GATT `1d770001-…`.

**Fluxo de dados**
- O pacote só é notificado se sobrarem buffers no `msys_1` da NimBLE (reserva de 4). Assim, as respostas aos comandos nunca ficam sem buffer (erro ATT 0x11).
- **Rádio mais lento que a aquisição:** as amostras esperam na fila e chegam atrasadas, mas chegam todas. Com a conexão viva, nenhum pacote é descartado.
- **Depois do STOP:** a placa ainda entrega o que estava na fila (até 60 s de leituras). O cliente só deve desconectar quando os pacotes pararem de chegar.
- **Conexões:** a conexão ativa é a do cliente que assina a Medição. Uma segunda conexão do mesmo central não altera o MTU nem o handle da ativa. Se ninguém estiver recebendo e o anúncio tiver parado, ele é religado.

**Decisões não descritas no protocolo v2**
- **Calibração:**
  - sem calibração gravada, a placa usa o fator nominal da etiqueta (`config.h`, 9,1331549 mN/contagem) e liga o bit 2;
  - `SET_CALIBRACAO` com fator 0 apaga a calibração; NaN e infinito são ignorados.
- **Sinal:** a inversão é feita com fator negativo; não há comando separado.
- **Modo bruto:** envia as contagens do ADC sem subtrair o deslocamento.
- **Desconexão:** gera um STOP automático. No START seguinte, a sequência volta a 0.
- **Bit 3 (erro no ADC):** junta quatro causas:
  - registradores errados;
  - DRDY parado por 100 ms;
  - 250 leituras iguais seguidas;
  - AVDD abaixo de 4,5 V (medido no START e a cada 2 s com a aquisição parada).
- **Taxa:** o Estado informa a taxa nominal (1200). O tempo real de cada amostra vem de `timestamp_us` e `delta_us`.
- **MTU:** precisa ser de pelo menos 25 para caber 1 amostra e 139 para o pacote cheio de 20 amostras (136 bytes de payload). No Android, chame `requestMtu(247)` antes do START.

**Comandos do Monitor Serial**
- `status`, `start`, `stop`, `tara`, `bruto 0|1`, `cal <fator> <deslocamento>`, `calkg <kg>`, `limpacal`, `log`;
- de bancada: `diag` (registradores, AVDD e referência medidos pelo ADS), `ruido` (desvio padrão de 2 s) e `grafico [n]` (saída para o Plotter Serial).

## Testes de bancada

1. **`teste_01_devkit`:** DevKit fora da placa, só no USB. Deve terminar com "0 falha(s)". No nRF Connect, o contador `SAMBA-TESTE` deve subir 1 por segundo.
2. **`teste_02_ads1220`:** na placa soldada. Comandos pelo Monitor Serial (lista no cabeçalho do sketch).
3. **`teste_ina226`:** varredura I²C, IDs 0x5449/0x2260, leitura a cada 0,5 s e resumo de 10 s com a autonomia estimada. O comando `m <mA>` ajusta a calibração com o multímetro.

Depois de qualquer teste, grave de novo o `samba_firmware`.

## Ferramentas (`ferramentas/`)

Dependências: `pip install bleak numpy matplotlib pyserial`

| Arquivo | Uso |
| --- | --- |
| `samba_ble_cliente.py` | Cliente de referência do protocolo: `python samba_ble_cliente.py --tara --segundos 60 --csv coleta.csv`. No fim, informa a integridade (todas as sequências recebidas, sem buracos nem repetições) e o desempenho do enlace |
| `teste_conexao_ble.py` | N ciclos de conectar → START → STOP → desconectar, com contagem de leituras perdidas, repetidas e pacotes inválidos: `python teste_conexao_ble.py --ciclos 20 --segundos 5` |
| `grafico_ao_vivo.py` | Gráfico contínuo de tração e compressão por BLE, ou pelo USB com `--usb COM6` |
| `samba_celular.html` | Página Web Bluetooth (Chrome no Android, ou Chrome/Edge no PC): gráfico ao vivo, tara e teste de conexão de 10 ciclos |
| `captura_hex.py` | Imprime o Estado e pacotes reais em hexadecimal, para os testes do aplicativo |
| `plota_csv.py` | Gráfico de força × tempo a partir de um CSV (com filtro de fase zero opcional) |
| `curva_calibracao.py` | Reta massa × contagens, R² e fator para o comando `cal` |
| `serial_cmd.py` | Envia comandos ao Monitor Serial sem reiniciar a ESP32 |

**Sobre o `samba_celular.html`:** o Chrome só libera o Bluetooth em contexto seguro, ou seja, num arquivo local ou em https. Se o arquivo local for bloqueado, sirva a pasta com `python -m http.server 8000` e, no Chrome do celular, ative `chrome://flags` → "Insecure origins treated as secure" para o endereço do PC.

**No Windows 11:** os scripts pedem intervalo de conexão de 15 ms (`ThroughputOptimized`). Sozinho, o Windows usa 30 ms.

## Resultados medidos

| Ensaio | Resultado |
| --- | --- |
| Taxa real | 1164,6 amostras/s, 0 perdas no DRDY |
| Ruído em repouso | 0,59 µV rms |
| Sessão BLE de 60 s (PC) | 69 910 de 69 910 leituras, em ordem; 58 notificações/s; 7,9 kB/s |
| Confiabilidade (PC, 25 ciclos de 5 s) | 25/25 ciclos; 146 496 leituras; 0 perdidas, 0 repetidas, 0 inválidas |
| INA226 (placa parada) | pack 12,31 V; ~58 mA; 0,71 W; autonomia estimada de ~34 h |
