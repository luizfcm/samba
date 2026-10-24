# Arquitetura do software

```text
FonteForca → ControladorMedicao → SessaoMedicao → processadores
```

## Fonte

Uma `FonteForca` entrega `AmostraForca` (sequência, timestamp em µs, força em N e status) por um Stream e é iniciada e parada pelo controlador. O formato dos pacotes enviados pelo dispositivo está no [protocolo BLE v2](protocolo_ble_v2.md). Nenhuma camada assume taxa fixa: os intervalos vêm sempre dos timestamps.

## Controlador

`ControladorMedicao` cria a sessão, inicia e para a fonte e passa pelos estados `ociosa`, `medindo` e `finalizada`, notificando só nas mudanças de estado. Amostras cuja sequência ou timestamp não avance são descartadas e contadas, e saltos de sequência são contados como perdas. A interface fala com o controlador e a sessão, nunca com a fonte.

## Sessão

`SessaoMedicao` guarda as amostras aceitas de um exercício, do início ao término. Durante a medição, a interface lê as amostras de forma incremental com `amostrasDesde`, em vez de copiar a lista inteira a cada atualização.

## Processadores

Um `ProcessadorExercicio` recebe a lista de amostras da sessão e devolve o resultado do exercício. Para remada e extensora, `ProcessadorIsometria` calcula as métricas da série e de cada repetição, definidas em [metrics.md](metrics.md). Para o salto, `ProcessadorSalto` estima a massa pelo repouso inicial, separa os saltos pelo voo e calcula aceleração, velocidade e potência de cada um.
