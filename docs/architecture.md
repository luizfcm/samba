# Arquitetura do software

## Componentes atuais

O código Dart está organizado em três áreas:

- `nucleo`: modelo `AmostraForca`, contrato `FonteForca`, fonte simulada e decodificador `PacoteMedicao` do protocolo BLE v2.
- `funcionalidades/medicao/dominio`: `Exercicio`, `SessaoMedicao`, cálculo de `MetricasForca`, detector de repetições `detectarRepeticoes`, interface `ProcessadorExercicio` e sua implementação `ProcessadorIsometria`.
- `funcionalidades/medicao/aplicacao`: `ControladorMedicao`, que liga uma `FonteForca` a uma `SessaoMedicao`.

A fonte simulada e o decodificador produzem o mesmo modelo de amostra. O cálculo das métricas e o processador de isometria recebem uma lista de amostras; ainda não há conexão com o controlador nem com a interface.

```text
FonteForca → ControladorMedicao → SessaoMedicao
PacoteMedicao.decodificar → List<AmostraForca>
List<AmostraForca> → calcularMetricasForca → MetricasForca
List<AmostraForca> → ProcessadorIsometria → ResultadoIsometria
```

## Controle da medição

`ControladorMedicao` é um `ChangeNotifier` com os estados `ociosa`, `medindo` e `finalizada`, e notifica somente nas mudanças de estado. `iniciar` cria uma nova sessão, zera as contagens, assina o Stream e inicia a fonte; chamá-lo durante uma medição lança `StateError`. Se a fonte falhar ao iniciar, o controlador volta a `ociosa` sem sessão.

A sequência de cada amostra é comparada à última sequência recebida, e o timestamp ao último timestamp aceito. Amostras cuja sequência ou timestamp não seja maior são descartadas e contadas em `amostrasDescartadas`. Saltos de sequência somam as amostras ausentes em `amostrasPerdidas`, tomando a primeira amostra recebida como referência. Uma amostra descartada só pelo timestamp avança a referência de sequência e, por isso, não conta como perdida.

`finalizar` cancela a assinatura, aguarda a parada da fonte e só então finaliza a sessão e passa a `finalizada`, mesmo que a parada falhe. Amostras recebidas durante a parada são ignoradas.

Durante a medição, a interface deve ler as amostras de forma incremental com `SessaoMedicao.amostrasDesde`, guardando quantas já leu, em vez de copiar a lista inteira com `amostras` a cada atualização.

## Aquisição simulada

`FonteForca` expõe `amostras`, `iniciar()` e `parar()`. A implementação simulada usa um Stream broadcast, sem retenção de amostras para assinantes posteriores.

A primeira amostra tem sequência e timestamp zero. O temporizador solicita novas amostras a cada 10 ms, correspondendo à frequência nominal de 100 Hz. A sequência aumenta uma unidade por emissão. A força descreve um sinal triangular de 0 a 100 N a cada 100 amostras; `status` é zero.

Os timestamps são relativos ao início da aquisição e medidos por `Stopwatch`. Atrasos no agendamento podem alterar os intervalos e a frequência efetiva, mas não os valores de força associados à sequência.

Chamadas de início durante uma aquisição ativa não criam outro temporizador. A parada cancela o temporizador sem fechar o Stream. Uma nova aquisição reinicia a sequência, o relógio e o sinal.

## Limites atuais

A interface exibe apenas “SAMBA” e “Interface em desenvolvimento”, sem controles ou navegação. Não há aquisição por hardware, comunicação BLE real, firmware executável, armazenamento local ou sincronização. O processamento implementado calcula as métricas gerais da curva força-tempo e, na isometria, o instante do pico e as métricas por repetição; não há processamento específico para salto ou terra.

## Arquitetura prevista

```text
H3C3 → condicionamento/ADC → ESP32-S3 → BLE → aplicativo Flutter → processamento → persistência
```

A comunicação entre o ESP32-S3 e o aplicativo segue o protocolo BLE v2, descrito em [protocolo_ble_v2.md](protocolo_ble_v2.md), com pacotes de 20 amostras a 1000 Hz.

Esse fluxo representa a arquitetura prevista, ainda não implementada integralmente. A aquisição pelo H3C3 e pelo ADC, o firmware do ESP32-S3, a comunicação BLE real e a persistência ainda não estão implementados; o aplicativo dispõe atualmente da fonte simulada e das métricas gerais de força.
