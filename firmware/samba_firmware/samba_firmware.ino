/*
  Projeto SAMBA - firmware de producao (protocolo BLE v2)
  ESP32-S3-DevKitC-1 + ADS1220 (1000 Hz) + celula de carga tipo S

  Arquitetura
    ISR do DRDY (GPIO14, borda de descida): carimba o tempo (esp_timer, us) e acorda a tarefa.
    Tarefa "aquisicao" (nucleo 1, prioridade alta): UNICA dona do SPI. Le a amostra, detecta
      perdas, saturacao e ADC travado, aplica tara/calibracao, faz TARE, e poe a amostra na fila.
      Tambem executa os comandos (vindos do BLE ou do Monitor Serial) entre uma amostra e outra.
    loop() (nucleo 1, prioridade baixa): monta os pacotes de 20 amostras, notifica Medicao com
      controle de fluxo, atualiza Estado, grava a NVS e atende o Monitor Serial.
    NimBLE (nucleo 0): servico GATT do protocolo v2.

  Bibliotecas: NimBLE-Arduino 2.x (Gerenciador de Bibliotecas). Placa: "ESP32S3 Dev Module".
  Monitor Serial: 921600 baud, "Nova linha". Digite "ajuda" para ver os comandos de bancada.

  Decisoes que nao estao escritas no protocolo v2:
    - Sem calibracao gravada: usa o fator NOMINAL da etiqueta (config.h) com o bit 2 ligado.
    - SET_CALIBRACAO com fator 0 apaga a calibracao (volta ao nominal, bit 2 ligado).
    - Sinal invertido = fator negativo (nao existe comando separado de inversao).
    - Modo bruto envia as contagens do ADC SEM subtrair o deslocamento.
    - Desconectou = STOP automatico.
    - Pacote pode ter menos de 20 amostras: quando o MTU e pequeno, quando o status muda, quando
      ha perda (salto de sequencia) ou no STOP. O campo count sempre diz quantas sao.
    - AVDD baixa (pack desligado), DRDY parado, registradores errados e ADC travado ligam o bit 3.
*/

#include <Arduino.h>
#include <atomic>
#include <Preferences.h>
#include <NimBLEDevice.h>
#ifdef USING_NIMBLE_ARDUINO_HEADERS  // os_msys_num_free(): buffers livres da pilha NimBLE (12 de 256 B)
#include "nimble/porting/nimble/include/os/os_mbuf.h"
#else
#include "os/os_mbuf.h"
#endif
#include "esp_timer.h"
#include "esp_task_wdt.h"
#include "config.h"
#include "protocolo.h"
#include "ads1220.h"

// ======================================================================
// Estado compartilhado
// ======================================================================
static const uint8_t REGS_ADS[4] = {ADS_REG0, ADS_REG1, ADS_REG2, ADS_REG3};
static const float FATOR_NOMINAL =  // mN por contagem, pela etiqueta da celula
    1000.0f / (8388608.0f * ADS_GANHO) / SENSIBILIDADE_MV_V * CAPACIDADE_KG * G_PADRAO * 1000.0f;

Ads1220 ads;
Preferences prefs;
TaskHandle_t tarefaAq = nullptr;
QueueHandle_t filaAmostras = nullptr;
QueueHandle_t filaComandos = nullptr;

// ISR -> tarefa de aquisicao
portMUX_TYPE muxIsr = portMUX_INITIALIZER_UNLOCKED;
volatile uint32_t isrContador = 0;
volatile int64_t isrTempo = 0;

// Escritos pela tarefa de aquisicao, lidos pelo loop()
std::atomic<float> fator{FATOR_NOMINAL};
std::atomic<int32_t> deslocamento{0};
std::atomic<bool> temCalibracao{false};
std::atomic<bool> modoBruto{false};
std::atomic<bool> rodando{false};
std::atomic<uint16_t> statusBase{ST_SEM_CAL};
std::atomic<uint16_t> sessaoAtual{0};
std::atomic<bool> satAtual{false}, satRecente{false};
std::atomic<bool> salvarPendente{false};
std::atomic<int32_t> ultimoBruto{0};
std::atomic<float> avddV{NAN};
std::atomic<uint32_t> nLidas{0}, nPerdidasDrdy{0}, nFilaCheia{0};

// BLE
NimBLEServer *srv = nullptr;
NimBLECharacteristic *chMedicao = nullptr, *chControle = nullptr, *chEstado = nullptr;
std::atomic<bool> conectado{false}, inscritoMedicao{false}, inscritoEstado{false}, forcaEstado{true};
std::atomic<uint16_t> connHandle{0}, mtuAtual{23};
std::atomic<uint32_t> nPacotes{0}, nPacotesDescartados{0}, nFalhasNotify{0}, nAmostrasSemMtu{0};
std::atomic<uint32_t> nEsperaBuffer{0};      // vezes em que o envio esperou para preservar a reserva de buffers
std::atomic<int> mbufMinimo{99};             // menor numero de buffers livres visto (diagnostico do enlace)
std::atomic<uint16_t> connIntervalo{0};      // unidades de 1,25 ms (o que o central aceitou de fato)
std::atomic<uint8_t> phyTx{1}, phyRx{1};     // 1 = 1M, 2 = 2M

bool logLigado = false;

// Modo grafico (Serial Plotter): a tarefa acumula, o loop() imprime a media
portMUX_TYPE muxGraf = portMUX_INITIALIZER_UNLOCKED;
std::atomic<bool> graficoLigado{false};
int64_t grafSoma = 0;
uint32_t grafN = 0;
uint32_t pontosGrafico = 20;  // pontos por segundo
constexpr double MVV_POR_CONTAGEM = 1000.0 / (8388608.0 * ADS_GANHO);  // ganho 128, ratiometrico

// ======================================================================
// ISR do DRDY
// ======================================================================
void IRAM_ATTR isrDrdy() {
  int64_t t = esp_timer_get_time();
  portENTER_CRITICAL_ISR(&muxIsr);
  isrTempo = t;
  isrContador = isrContador + 1;
  portEXIT_CRITICAL_ISR(&muxIsr);
  BaseType_t acordou = pdFALSE;
  if (tarefaAq) vTaskNotifyGiveFromISR(tarefaAq, &acordou);
  if (acordou) portYIELD_FROM_ISR();
}

void enviaComando(uint8_t op, uint8_t u8 = 0, float f = 0, int32_t i32 = 0) {
  Comando c{op, u8, f, i32};
  if (xQueueSend(filaComandos, &c, 0) != pdTRUE) Serial.println("[CMD] fila de comandos cheia: comando ignorado");
}

// ======================================================================
// Tarefa de aquisicao
// ======================================================================
enum class Media : uint8_t { NENHUMA, TARA, CALKG, RUIDO };
constexpr uint32_t RUIDO_AMOSTRAS = 2000;  // 2 s a 1000 Hz

struct EstadoAq {
  bool erroRegs = false, erroDrdy = false, erroTravado = false, avddBaixa = false;
  uint32_t ultimoContador = 0, ultimoDrdyMs = 0, ultimaTentativaMs = 0, ultimoMonitorMs = 0;
  uint32_t seq = 0, iguais = 0;
  int32_t anterior = INT32_MIN;
  int64_t t0 = 0;
  bool primeiro = true;
  uint16_t sessao = 0;
  Media media = Media::NENHUMA;
  int64_t somaMedia = 0;
  uint32_t nMedia = 0;
  int32_t refRuido = 0;      // 1a amostra do ruido (subtraida para nao perder precisao)
  double soma2Ruido = 0;
  float massaKg = 0;
};
EstadoAq aq;

uint16_t calculaStatus() {
  uint16_t st = 0;
  if (aq.media == Media::TARA) st |= ST_TARA;
  if (!temCalibracao) st |= ST_SEM_CAL;
  if (aq.erroRegs || aq.erroDrdy || aq.erroTravado || aq.avddBaixa) st |= ST_ERRO_ADC;
  if (modoBruto) st |= ST_MODO_BRUTO;
  if (rodando) st |= ST_AQUISICAO;
  statusBase = st;
  return st;
}

// Depois de qualquer operacao no SPI fora do fluxo normal: ignora os DRDY que passaram.
void ressincroniza() {
  ulTaskNotifyTake(pdTRUE, 0);
  portENTER_CRITICAL(&muxIsr);
  aq.ultimoContador = isrContador;
  portEXIT_CRITICAL(&muxIsr);
  aq.ultimoDrdyMs = millis();
}

void checaAvdd() {
  float v = ads.medeAvdd(REGS_ADS);
  avddV = v;
  bool baixa = isnan(v) || v < AVDD_MINIMA_V;
  if (baixa != aq.avddBaixa) {
    if (baixa) Serial.printf("[ADS] AVDD %.2f V: pack desligado ou LT3042 sem entrada (bit 3 ligado)\n", v);
    else Serial.printf("[ADS] AVDD %.2f V: normal\n", v);
  }
  aq.avddBaixa = baixa;
  aq.ultimoMonitorMs = millis();
  ressincroniza();
}

void reiniciaAds() {
  aq.ultimaTentativaMs = millis();
  bool ok = ads.iniciar(REGS_ADS);
  if (ok != !aq.erroRegs) Serial.println(ok ? "[ADS] registradores OK" : "[ADS] ERRO: registradores nao conferem (SPI?)");
  aq.erroRegs = !ok;
  ressincroniza();
}

// Autodiagnostico de bancada (roda na tarefa de aquisicao, dona do SPI).
// Interrompe a conversao por ~20 ms; durante o START isso vira salto de sequencia, por isso so roda parado.
void diagnostico() {
  if (rodando) {
    Serial.println("[DIAG] pare a aquisicao (stop) antes do diagnostico");
    return;
  }
  uint8_t r[4];
  ads.leRegs(r);
  bool regsOk = memcmp(r, REGS_ADS, 4) == 0;
  int errosSpi = 0;  // 500 leituras seguidas na velocidade de producao: pega fio ruim / SPI rapido demais
  for (int i = 0; i < 500; i++) {
    uint8_t q[4];
    ads.leRegs(q);
    if (memcmp(q, REGS_ADS, 4) != 0) errosSpi++;
  }
  float avdd = ads.medeMonitor(0xD1, REGS_ADS);
  float ref = ads.medeMonitor(0xC1, REGS_ADS);
  avddV = avdd;
  Serial.println("\n[DIAG] ===== Autodiagnostico do ADS1220 =====");
  Serial.printf("[DIAG] registradores %02X %02X %02X %02X (esperado %02X %02X %02X %02X) -> %s\n", r[0], r[1], r[2], r[3],
                REGS_ADS[0], REGS_ADS[1], REGS_ADS[2], REGS_ADS[3], regsOk ? "SPI OK" : "ERRO");
  Serial.printf("[DIAG] SPI %lu MHz: %d erro(s) em 500 leituras dos registradores -> %s\n",
                (unsigned long)(SPI_HZ / 1000000), errosSpi,
                errosSpi == 0 ? "OK" : "use SPI_HZ = 1000000 no config.h e confira os fios do SPI");
  Serial.printf("[DIAG] taxa configurada %u SPS | ganho %.0f | medicao ratiometrica (REFP0 = E+)\n", TAXA_HZ,
                (double)ADS_GANHO);
  Serial.printf("[DIAG] AVDD (excitacao da celula, medida pelo ADS) = %.3f V -> %s\n", (double)avdd,
                isnan(avdd) ? "sem resposta" : (avdd < AVDD_MINIMA_V ? "BAIXA" : (avdd > 5.5f ? "ACIMA DO MAXIMO" : "OK")));
  Serial.printf("[DIAG] REFP0-REFN0 (referencia, ligacao Kelvin) = %.3f V -> %s\n", (double)ref,
                isnan(ref) ? "sem resposta" : (fabsf(ref - avdd) < 0.05f ? "OK (igual ao AVDD)" : "confira E+/E- e REFP0/REFN0"));
  Serial.printf("[DIAG] amostras lidas %lu | perdidas no DRDY %lu\n\n", (unsigned long)nLidas.load(),
                (unsigned long)nPerdidasDrdy.load());
  ressincroniza();
}

void aplicaCalibracao(float f, int32_t d, bool valida) {
  fator = valida ? f : FATOR_NOMINAL;
  deslocamento = d;
  temCalibracao = valida;
  salvarPendente = true;
}

void processaComando(const Comando &c) {
  switch (c.op) {
    case OP_START:
      checaAvdd();  // ~8 ms, antes do 1o dado: o app ja recebe o bit 3 certo
      xQueueReset(filaAmostras);
      aq.sessao++;
      sessaoAtual = aq.sessao;
      aq.seq = 0;
      aq.primeiro = true;
      rodando = true;
      Serial.println("[CMD] START");
      break;
    case OP_STOP:
      if (rodando) Serial.println("[CMD] STOP");
      rodando = false;
      break;
    case OP_TARE:
    case OP_INT_CALKG:
    case OP_INT_RUIDO:
      if (aq.media != Media::NENHUMA) {
        Serial.println("[CMD] ja ha uma media em andamento; comando ignorado");
        break;
      }
      aq.media = (c.op == OP_TARE) ? Media::TARA : (c.op == OP_INT_CALKG) ? Media::CALKG : Media::RUIDO;
      aq.massaKg = c.f;
      aq.somaMedia = 0;
      aq.nMedia = 0;
      aq.soma2Ruido = 0;
      Serial.println(c.op == OP_TARE       ? "[CMD] TARE: mantenha a celula parada..."
                     : c.op == OP_INT_CALKG ? "[CMD] CALKG: mantenha a massa parada..."
                                            : "[CMD] RUIDO: 2 s de leituras, nao toque na celula...");
      break;
    case OP_INT_DIAG:
      diagnostico();
      break;
    case OP_MODO_BRUTO:
      modoBruto = c.u8 != 0;
      Serial.printf("[CMD] MODO_BRUTO %d\n", (int)modoBruto);
      break;
    case OP_SET_CALIBRACAO:
      if (!isfinite(c.f)) {
        Serial.println("[CMD] SET_CALIBRACAO com fator invalido (NaN/inf): ignorado");
        break;
      }
      aplicaCalibracao(c.f, c.i32, c.f != 0.0f);
      Serial.printf("[CMD] SET_CALIBRACAO fator=%.7f mN/cont deslocamento=%ld%s\n", (double)c.f, (long)c.i32,
                    c.f == 0.0f ? " (fator 0: volta ao nominal)" : "");
      break;
    case OP_INT_LIMPA_CAL:
      aplicaCalibracao(0, deslocamento, false);
      Serial.println("[CMD] calibracao apagada: fator nominal da etiqueta");
      break;
  }
  calculaStatus();
}

void terminaMedia() {
  int32_t media = (int32_t)llround((double)aq.somaMedia / aq.nMedia);
  if (aq.media == Media::RUIDO) {
    double n = aq.nMedia;
    double m = (double)aq.somaMedia / n;  // somaMedia guarda (bruto - refRuido)
    double var = (aq.soma2Ruido - n * m * m) / (n - 1);
    double dp = sqrt(var > 0 ? var : 0);
    double dpN = dp * fabs((double)fator.load()) / 1000.0;
    Serial.printf("[RUIDO] %u amostras a %u Hz: desvio padrao %.1f contagens RMS = %.6f mV/V = %.2f uV/V\n",
                  (unsigned)aq.nMedia, TAXA_HZ, dp, dp * MVV_POR_CONTAGEM, dp * MVV_POR_CONTAGEM * 1000.0);
    Serial.printf("[RUIDO] = %.3f N RMS (%.3f kg) com o fator %s | pico a pico ~%.0f contagens\n", dpN, dpN / G_PADRAO,
                  temCalibracao ? "calibrado" : "NOMINAL da etiqueta (estimativa)", dp * 6.6);
    aq.media = Media::NENHUMA;
    return;
  }
  if (aq.media == Media::TARA) {
    deslocamento = media;
    salvarPendente = true;
    Serial.printf("[TARA] deslocamento = %ld contagens\n", (long)media);
  } else {
    int64_t dif = (int64_t)media - (int64_t)deslocamento.load();
    if (llabs(dif) < 100) {
      Serial.println("[CALKG] ERRO: leitura quase igual a tara. Faca 'tara' sem carga antes e confira a massa.");
    } else {
      float f = (float)((double)aq.massaKg * (double)G_PADRAO * 1000.0 / (double)dif);
      aplicaCalibracao(f, deslocamento, true);
      Serial.printf("[CALKG] fator = %.7f mN/contagem (%.2f contagens/kg), deslocamento = %ld\n", (double)f,
                    (double)dif / (double)aq.massaKg, (long)deslocamento.load());
    }
  }
  aq.media = Media::NENHUMA;
}

inline int32_t converte(int32_t bruto) {
  double mN = (double)((int64_t)bruto - (int64_t)deslocamento.load()) * (double)fator.load();
  if (mN >= (double)INT32_MAX) return INT32_MAX;
  if (mN <= (double)INT32_MIN) return INT32_MIN;
  return (int32_t)llround(mN);
}

void tarefaAquisicao(void *) {
  esp_task_wdt_add(nullptr);  // trava aqui por mais de 5 s = reset
  reiniciaAds();
  checaAvdd();
  calculaStatus();

  for (;;) {
    esp_task_wdt_reset();
    Comando cmd;
    while (xQueueReceive(filaComandos, &cmd, 0) == pdTRUE) processaComando(cmd);

    uint32_t agora = millis();
    if (aq.erroRegs && agora - aq.ultimaTentativaMs > REINICIO_ADS_MS) reiniciaAds();

    if (ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(10)) == 0) {
      // Sem DRDY
      agora = millis();
      if (agora - aq.ultimoDrdyMs > DRDY_TIMEOUT_MS) {
        if (!aq.erroDrdy) Serial.println("[ADS] ERRO: DRDY parou (bit 3). Tentando reiniciar o ADS...");
        aq.erroDrdy = true;
        if (aq.media != Media::NENHUMA) {
          Serial.println("[ADS] media cancelada");
          aq.media = Media::NENHUMA;
        }
        if (agora - aq.ultimaTentativaMs > REINICIO_ADS_MS) reiniciaAds();
      }
      calculaStatus();
      continue;
    }

    // --- Le a amostra ---
    uint32_t c1, c2;
    int64_t t;
    portENTER_CRITICAL(&muxIsr);
    c1 = isrContador;
    t = isrTempo;
    portEXIT_CRITICAL(&muxIsr);
    if (c1 == aq.ultimoContador) continue;  // notificacao antiga, nada novo
    int32_t bruto = ads.leDado();
    portENTER_CRITICAL(&muxIsr);
    c2 = isrContador;
    portEXIT_CRITICAL(&muxIsr);

    uint32_t perdidas = c1 - aq.ultimoContador - 1;
    aq.ultimoContador = c1;
    aq.ultimoDrdyMs = millis();
    if (aq.erroDrdy) Serial.println("[ADS] DRDY voltou");
    aq.erroDrdy = false;
    if (c2 != c1) perdidas++;  // outra conversao terminou durante a leitura: dado ambiguo, descarta
    if (perdidas) {
      nPerdidasDrdy += perdidas;
      if (rodando && !aq.primeiro) aq.seq += perdidas;  // o app ve o salto na sequencia
    }
    if (c2 != c1) continue;
    nLidas++;
    ultimoBruto = bruto;
    if (graficoLigado) {
      portENTER_CRITICAL(&muxGraf);
      grafSoma += bruto;
      grafN++;
      portEXIT_CRITICAL(&muxGraf);
    }

    // --- Diagnosticos por amostra ---
    aq.iguais = (bruto == aq.anterior) ? aq.iguais + 1 : 0;
    aq.anterior = bruto;
    bool travado = aq.iguais >= AMOSTRAS_IGUAIS_MAX;
    if (travado != aq.erroTravado) Serial.println(travado ? "[ADS] ERRO: leitura travada (bit 3)" : "[ADS] leitura destravou");
    aq.erroTravado = travado;
    bool sat = bruto >= LIMITE_SATURACAO || bruto <= -LIMITE_SATURACAO;
    satAtual = sat;
    if (sat) satRecente = true;

    // --- Tara / calibracao por media ---
    if (aq.media != Media::NENHUMA) {
      if (sat || aq.erroRegs || aq.erroTravado || aq.avddBaixa) {
        Serial.println("[MEDIA] cancelada: saturacao ou erro no ADC. Deslocamento mantido.");
        aq.media = Media::NENHUMA;
      } else if (aq.media == Media::RUIDO) {
        if (aq.nMedia == 0) aq.refRuido = bruto;
        double d = (double)((int64_t)bruto - aq.refRuido);
        aq.somaMedia += (int64_t)bruto - aq.refRuido;
        aq.soma2Ruido += d * d;
        aq.nMedia++;
        if (aq.nMedia >= RUIDO_AMOSTRAS) terminaMedia();
      } else {
        aq.somaMedia += bruto;
        aq.nMedia++;
        uint32_t alvo = (aq.media == Media::TARA) ? TARA_AMOSTRAS : CALKG_AMOSTRAS;
        if (aq.nMedia >= alvo) terminaMedia();
      }
    }
    uint16_t st = calculaStatus() | (sat ? ST_SATURACAO : 0);

    // --- Envia para a fila ---
    if (rodando) {
      if (aq.primeiro) {
        aq.t0 = t;
        aq.primeiro = false;
      }
      Amostra a;
      a.t_us = (uint64_t)(t - aq.t0);
      a.seq = aq.seq++;
      a.valor = modoBruto ? bruto : converte(bruto);
      a.status = st;
      a.sessao = aq.sessao;
      if (xQueueSend(filaAmostras, &a, 0) != pdTRUE) nFilaCheia++;  // a sequencia ja avancou: o app ve a perda
    } else if (aq.media == Media::NENHUMA && millis() - aq.ultimoMonitorMs > MONITOR_AVDD_MS) {
      checaAvdd();  // parado: confere o pack a cada 2 s sem atrapalhar o stream
    }
  }
}

// ======================================================================
// BLE
// ======================================================================
class CbServidor : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *s, NimBLEConnInfo &info) override {
    connHandle = info.getConnHandle();
    mtuAtual = info.getMTU();
    conectado = true;
    s->updateConnParams(info.getConnHandle(), CONN_INT_MIN, CONN_INT_MAX, CONN_LATENCIA, CONN_TIMEOUT);
    s->setDataLen(info.getConnHandle(), 251);
    connIntervalo = info.getConnInterval();
    mbufMinimo = 99;
    Serial.printf("[BLE] conectado: %s | intervalo inicial %.2f ms\n", info.getAddress().toString().c_str(),
                  info.getConnInterval() * 1.25);
  }
  void onConnParamsUpdate(NimBLEConnInfo &info) override {
    connIntervalo = info.getConnInterval();
    Serial.printf("[BLE] parametros de conexao: intervalo %.2f ms, latencia %u, timeout %u ms\n",
                  info.getConnInterval() * 1.25, info.getConnLatency(), info.getConnTimeout() * 10);
  }
  void onPhyUpdate(NimBLEConnInfo &, uint8_t tx, uint8_t rx) override {
    phyTx = tx;
    phyRx = rx;
    Serial.printf("[BLE] PHY: tx %uM, rx %uM\n", tx, rx);
  }
  void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int motivo) override {
    conectado = false;
    inscritoMedicao = false;
    inscritoEstado = false;
    mtuAtual = 23;
    enviaComando(OP_STOP);
    Serial.printf("[BLE] desconectado (motivo 0x%X): STOP automatico, anunciando de novo\n", motivo);
  }
  void onMTUChange(uint16_t mtu, NimBLEConnInfo &) override {
    mtuAtual = mtu;
    Serial.printf("[BLE] MTU = %u -> %u amostras por pacote%s\n", mtu, amostrasPorMtu(mtu, AMOSTRAS_POR_PACOTE),
                  mtu < 139 ? " (abaixo de 139: o app deve pedir requestMtu(247))" : "");
  }
};

class CbControle : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *ch, NimBLEConnInfo &) override {
    NimBLEAttValue v = ch->getValue();
    const uint8_t *d = v.data();
    size_t n = v.length();
    if (n == 0) return;
    uint8_t op = d[0];
    size_t esperado = (op == OP_START || op == OP_STOP || op == OP_TARE) ? 1
                    : (op == OP_MODO_BRUTO) ? 2
                    : (op == OP_SET_CALIBRACAO) ? 9 : 0;
    if (esperado == 0 || n != esperado) {
      Serial.printf("[BLE] comando rejeitado: opcode 0x%02X com %u bytes\n", op, (unsigned)n);
      return;
    }
    float f = 0;
    int32_t i32 = 0;
    if (op == OP_SET_CALIBRACAO) {
      uint32_t fb = (uint32_t)d[1] | ((uint32_t)d[2] << 8) | ((uint32_t)d[3] << 16) | ((uint32_t)d[4] << 24);
      memcpy(&f, &fb, 4);
      i32 = (int32_t)((uint32_t)d[5] | ((uint32_t)d[6] << 8) | ((uint32_t)d[7] << 16) | ((uint32_t)d[8] << 24));
    }
    enviaComando(op, n > 1 ? d[1] : 0, f, i32);
  }
};

class CbInscricao : public NimBLECharacteristicCallbacks {
  void onSubscribe(NimBLECharacteristic *ch, NimBLEConnInfo &, uint16_t valor) override {
    bool ligado = valor & 0x0001;
    if (ch == chMedicao) inscritoMedicao = ligado;
    if (ch == chEstado) {
      inscritoEstado = ligado;
      forcaEstado = true;  // manda o estado atual logo que o app assina
    }
  }
};

void iniciaBle() {
  NimBLEDevice::init(NOME_BLE);
  NimBLEDevice::setMTU(MTU_PREFERIDO);
  // Aceita PHY 2M (dobro da taxa do radio) quando o central suporta; senao continua em 1M.
  NimBLEDevice::setDefaultPhy(BLE_GAP_LE_PHY_1M_MASK | BLE_GAP_LE_PHY_2M_MASK,
                              BLE_GAP_LE_PHY_1M_MASK | BLE_GAP_LE_PHY_2M_MASK);
  NimBLEDevice::setPower(9);  // dBm
  srv = NimBLEDevice::createServer();
  srv->setCallbacks(new CbServidor());
  srv->advertiseOnDisconnect(true);

  NimBLEService *svc = srv->createService(UUID_SERVICO);
  chMedicao = svc->createCharacteristic(UUID_MEDICAO, NIMBLE_PROPERTY::NOTIFY);
  chControle = svc->createCharacteristic(UUID_CONTROLE, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  chEstado = svc->createCharacteristic(UUID_ESTADO, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY, ESTADO_BYTES);
  static CbInscricao cbInscricao;
  static CbControle cbControle;
  chMedicao->setCallbacks(&cbInscricao);
  chEstado->setCallbacks(&cbInscricao);
  chControle->setCallbacks(&cbControle);
  uint8_t est[ESTADO_BYTES];
  montaEstado(est, statusBase, TAXA_HZ, fator, deslocamento);
  chEstado->setValue(est, ESTADO_BYTES);
  srv->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(UUID_SERVICO);
  adv->setName(NOME_BLE);
  if (!adv->start()) Serial.println("[BLE] ERRO ao iniciar o anuncio");
}

// Notifica um pacote. true = pode descartar (enviado, ou sem ninguem para receber).
bool enviaPacote(const MontadorPacote &p) {
  static uint32_t falhandoDesde = 0;
  if (!conectado || !inscritoMedicao) {
    nPacotesDescartados++;
    return true;
  }
  int livres = os_msys_num_free();
  if (livres < mbufMinimo) mbufMinimo = livres;
  if (livres > RESERVA_BUFFERS_BLE) {
    if (chMedicao->notify(p.buf, p.tamanho(), connHandle)) {
      nPacotes++;
      falhandoDesde = 0;
      return true;
    }
    nFalhasNotify++;
  } else {
    nEsperaBuffer++;  // radio atrasado: guarda a reserva para os comandos e tenta de novo
  }
  // Sem buffer na pilha BLE: tenta de novo; a fila de 2 s absorve.
  uint32_t agora = millis();
  if (falhandoDesde == 0) falhandoDesde = agora;
  if (agora - falhandoDesde > 500) {  // conexao ruim de verdade: desiste deste pacote
    falhandoDesde = 0;
    nPacotesDescartados++;
    return true;
  }
  return false;
}

void servicoMedicao() {
  static MontadorPacote pac;
  static bool pronto = false;     // pacote fechado esperando envio
  static Amostra sobra;           // amostra que nao coube no pacote anterior
  static bool temSobra = false;

  uint16_t sessaoViva = sessaoAtual.load();
  if (pronto && pac.sessao() != sessaoViva) {
    pac.limpa();
    pronto = false;
  }
  if (temSobra && sobra.sessao != sessaoViva) {
    temSobra = false;
  }
  if (!pronto && pac.quantidade() > 0 && pac.sessao() != sessaoViva) {
    pac.limpa();
  }

  if (pronto) {
    if (!enviaPacote(pac)) {
      vTaskDelay(1);
      return;
    }
    pac.limpa();
    pronto = false;
  }

  uint8_t maxN = amostrasPorMtu(mtuAtual, AMOSTRAS_POR_PACOTE);
  Amostra a;
  while (!pronto) {
    if (temSobra) {
      a = sobra;
      temSobra = false;
    } else if (xQueueReceive(filaAmostras, &a, pdMS_TO_TICKS(pac.quantidade() ? 2 : 5)) != pdTRUE) {
      break;
    }
    sessaoViva = sessaoAtual.load();
    if (a.sessao != sessaoViva) {
      if (pac.quantidade() > 0 && pac.sessao() != sessaoViva) pac.limpa();
      continue;
    }
    if (pac.quantidade() > 0 && a.sessao != pac.sessao()) pac.limpa();  // novo START: descarta o resto da sessao velha
    if (maxN == 0) {  // MTU 23: nem 1 amostra cabe
      nAmostrasSemMtu++;
      continue;
    }
    if (pac.aceita(a, maxN)) {
      pac.adiciona(a, millis());
      if (pac.quantidade() >= maxN) pronto = true;
    } else {
      sobra = a;
      temSobra = true;
      pronto = true;
    }
  }
  if (!pronto && pac.quantidade() > 0 &&
      (pac.idadeMs(millis()) >= PACOTE_MAX_ESPERA_MS || (!rodando && uxQueueMessagesWaiting(filaAmostras) == 0)))
    pronto = true;  // STOP ou fluxo parado: manda o que tem
  if (pronto && enviaPacote(pac)) {
    pac.limpa();
    pronto = false;
  }
}

void servicoEstado() {
  static uint32_t ultimoSatMs = 0, ultimoRetryMs = 0;
  static uint16_t ultSt = 0xFFFF, bitSat = 0;
  static float ultF = NAN;
  static int32_t ultD = 0;

  uint32_t agora = millis();
  if (agora - ultimoSatMs >= ESTADO_INTERVALO_MS) {
    ultimoSatMs = agora;
    bitSat = satRecente.exchange(false) ? ST_SATURACAO : 0;
  }
  uint16_t st = statusBase.load() | bitSat;
  float f = fator.load();
  int32_t d = deslocamento.load();
  bool mudou = st != ultSt || f != ultF || d != ultD;
  if (!mudou && !(forcaEstado && agora - ultimoRetryMs >= 20)) return;

  ultSt = st;
  ultF = f;
  ultD = d;
  uint8_t est[ESTADO_BYTES];
  montaEstado(est, st, TAXA_HZ, f, d);
  chEstado->setValue(est, ESTADO_BYTES);  // leitura (Read) sempre ve o valor atual imediatamente
  if (conectado && inscritoEstado) {
    ultimoRetryMs = agora;
    forcaEstado = !chEstado->notify(est, ESTADO_BYTES, connHandle);  // se faltar buffer BLE, retenta
  } else {
    forcaEstado = false;
  }
}

// ======================================================================
// NVS
// ======================================================================
void carregaNvs() {
  prefs.begin("samba", true);
  bool tem = prefs.getBool("temcal", false);
  float f = prefs.getFloat("fator", FATOR_NOMINAL);
  int32_t d = prefs.getInt("desloc", 0);
  prefs.end();
  if (!isfinite(f) || f == 0.0f) tem = false;
  temCalibracao = tem;
  fator = tem ? f : FATOR_NOMINAL;
  deslocamento = d;
}

void servicoNvs() {
  // Gravar na flash para o cache das duas CPUs por alguns ms: so grava parado, para nao perder amostras.
  if (!salvarPendente || rodando) return;
  salvarPendente = false;
  prefs.begin("samba", false);
  prefs.putBool("temcal", temCalibracao);
  prefs.putFloat("fator", fator);
  prefs.putInt("desloc", deslocamento);
  prefs.end();
  Serial.println("[NVS] calibracao gravada");
}

// ======================================================================
// Monitor Serial (bancada)
// ======================================================================
void mostraStatus() {
  uint16_t st = statusBase.load() | (satAtual.load() ? ST_SATURACAO : 0);
  Serial.printf("\nSAMBA firmware %s | protocolo v%u | %u Hz\n", FIRMWARE_VERSAO, PROTOCOLO_VERSAO, TAXA_HZ);
  Serial.printf("  status 0x%04X:%s%s%s%s%s%s\n", st, st & ST_SATURACAO ? " SATURACAO" : "",
                st & ST_TARA ? " TARA" : "", st & ST_SEM_CAL ? " SEM_CAL" : "",
                st & ST_ERRO_ADC ? " ERRO_ADC" : "", st & ST_MODO_BRUTO ? " BRUTO" : "",
                st & ST_AQUISICAO ? " AQUISICAO" : "");
  Serial.printf("  fator %.7f mN/contagem (%s) | deslocamento %ld | AVDD %.3f V\n", (double)fator.load(),
                temCalibracao ? "calibrado" : "NOMINAL da etiqueta", (long)deslocamento.load(), (double)avddV.load());
  Serial.printf("  amostras lidas %lu | perdidas no DRDY %lu | fila cheia %lu | fila agora %u\n", (unsigned long)nLidas.load(),
                (unsigned long)nPerdidasDrdy.load(), (unsigned long)nFilaCheia.load(), (unsigned)uxQueueMessagesWaiting(filaAmostras));
  static uint32_t ultN = 0, ultMs = 0;
  uint32_t n = nLidas.load(), agora = millis();
  if (ultMs != 0 && agora - ultMs >= 1000)
    Serial.printf("  taxa medida desde o ultimo status: %.1f amostras/s (em %.1f s)\n",
                  (double)(n - ultN) * 1000.0 / (double)(agora - ultMs), (double)(agora - ultMs) / 1000.0);
  ultN = n;
  ultMs = agora;
  Serial.printf("  BLE %s | MTU %u | Medicao %s | Estado %s\n", conectado ? "conectado" : "anunciando", mtuAtual.load(),
                inscritoMedicao ? "assinada" : "-", inscritoEstado ? "assinado" : "-");
  Serial.printf("  pacotes enviados %lu | descartados %lu | notify sem buffer %lu | amostras sem MTU %lu\n",
                (unsigned long)nPacotes.load(), (unsigned long)nPacotesDescartados.load(), (unsigned long)nFalhasNotify.load(),
                (unsigned long)nAmostrasSemMtu.load());
  Serial.printf("  enlace: intervalo %.2f ms | PHY tx %uM rx %uM | buffers BLE livres agora %d (minimo %d, reserva %d) | "
                "esperas por buffer %lu\n\n",
                connIntervalo.load() * 1.25, phyTx.load(), phyRx.load(), os_msys_num_free(), mbufMinimo.load(),
                RESERVA_BUFFERS_BLE, (unsigned long)nEsperaBuffer.load());
}

void mostraAjuda() {
  Serial.println("\nComandos de bancada (os mesmos efeitos dos comandos BLE):");
  Serial.println("  status | log | start | stop | tara | bruto 0/1");
  Serial.println("  cal <fator_mN_por_contagem> <deslocamento>   (ex.: cal 9.1330000 -12345)");
  Serial.println("  calkg <kg>   calibra com massa conhecida (faca 'tara' sem carga antes)");
  Serial.println("  limpacal     apaga a calibracao (volta ao fator nominal da etiqueta)");
  Serial.println("Diagnostico de bancada:");
  Serial.println("  diag         registradores, AVDD e referencia medidos pelo proprio ADS (com a aquisicao parada)");
  Serial.println("  ruido        desvio padrao de 2 s de leituras (celula parada)");
  Serial.println("  grafico [n]  saida 'mV_V:valor' para o Plotter Serial (n pontos/s, padrao 20). 'grafico' de novo sai\n");
}

void servicoSerial() {
  static String bufSerial;
  String l;
  bool temLinha = false;
  while (Serial.available()) {
    char ch = (char)Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (bufSerial.length() > 0) {
        l = bufSerial;
        bufSerial = "";
        temLinha = true;
        break;
      }
    } else if (bufSerial.length() < 96) {
      bufSerial += ch;
    }
  }
  if (!temLinha) return;
  l.trim();
  l.toLowerCase();
  if (l.length() == 0) return;
  int esp = l.indexOf(' ');
  String cmd = esp < 0 ? l : l.substring(0, esp);
  String arg = esp < 0 ? "" : l.substring(esp + 1);
  arg.trim();

  if (cmd == "status" || cmd == "?") mostraStatus();
  else if (cmd == "log") {
    logLigado = !logLigado;
    graficoLigado = false;
    Serial.printf("log %s\n", logLigado ? "ligado (5 linhas/s)" : "desligado");
  } else if (cmd == "diag") enviaComando(OP_INT_DIAG);
  else if (cmd == "ruido") enviaComando(OP_INT_RUIDO);
  else if (cmd == "grafico" || cmd == "g") {
    int pps = arg.toInt();
    if (pps > 0) {
      pontosGrafico = constrain(pps, 1, 100);
      graficoLigado = true;
    } else {
      graficoLigado = !graficoLigado;
    }
    logLigado = false;
    portENTER_CRITICAL(&muxGraf);
    grafSoma = 0;
    grafN = 0;
    portEXIT_CRITICAL(&muxGraf);
    if (graficoLigado)
      Serial.printf("grafico ligado: %lu pontos/s em mV/V (tara atual descontada). Abra o Plotter Serial.\n",
                    (unsigned long)pontosGrafico);
    else
      Serial.println("grafico desligado");
  }
  else if (cmd == "start") enviaComando(OP_START);
  else if (cmd == "stop") enviaComando(OP_STOP);
  else if (cmd == "tara" || cmd == "t") enviaComando(OP_TARE);
  else if (cmd == "bruto") enviaComando(OP_MODO_BRUTO, arg.toInt() ? 1 : 0);
  else if (cmd == "cal") {
    int e2 = arg.indexOf(' ');
    if (e2 < 0) { Serial.println("Use: cal <fator> <deslocamento>"); return; }
    enviaComando(OP_SET_CALIBRACAO, 0, arg.substring(0, e2).toFloat(), (int32_t)arg.substring(e2 + 1).toInt());
  } else if (cmd == "calkg") {
    float kg = arg.toFloat();
    if (kg <= 0) { Serial.println("Use: calkg 20   (massa em kg ja aplicada)"); return; }
    enviaComando(OP_INT_CALKG, 0, kg);
  } else if (cmd == "limpacal") enviaComando(OP_INT_LIMPA_CAL);
  else mostraAjuda();
}

void servicoLog() {
  static uint32_t ultimo = 0;
  if (!logLigado || millis() - ultimo < 200) return;
  ultimo = millis();
  int32_t b = ultimoBruto;
  double n = (double)((int64_t)b - (int64_t)deslocamento.load()) * (double)fator.load() / 1000.0;
  uint16_t st = statusBase.load() | (satAtual.load() ? ST_SATURACAO : 0);
  Serial.printf("bruto %9ld | %10.2f N | %8.2f kg | status 0x%04X\n", (long)b, n, n / G_PADRAO, st);
}

void servicoGrafico() {
  static uint32_t ultimo = 0;
  if (!graficoLigado) return;
  uint32_t agora = millis();
  if (agora - ultimo < 1000 / pontosGrafico) return;
  ultimo = agora;
  portENTER_CRITICAL(&muxGraf);
  int64_t s = grafSoma;
  uint32_t n = grafN;
  grafSoma = 0;
  grafN = 0;
  portEXIT_CRITICAL(&muxGraf);
  if (n == 0) return;
  double media = (double)s / n - (double)deslocamento.load();
  // fator negativo (sinal invertido pela calibracao) tambem inverte o grafico
  double sinal = fator.load() < 0 ? -1.0 : 1.0;
  Serial.printf("mV_V:%.5f\n", sinal * media * MVV_POR_CONTAGEM);
}

// ======================================================================
void setup() {
  Serial.begin(921600);
  delay(1000);
  Serial.printf("\nSAMBA firmware %s (protocolo BLE v%u)\n", FIRMWARE_VERSAO, PROTOCOLO_VERSAO);

  carregaNvs();
  Serial.printf("Calibracao: %s, fator %.7f mN/contagem, deslocamento %ld\n",
                temCalibracao ? "gravada" : "NAO gravada (usando o nominal da etiqueta)", (double)fator.load(),
                (long)deslocamento.load());

  filaAmostras = xQueueCreate(FILA_AMOSTRAS, sizeof(Amostra));
  filaComandos = xQueueCreate(16, sizeof(Comando));
  if (!filaAmostras || !filaComandos) {
    Serial.println("ERRO: sem memoria para as filas");
    while (true) delay(1000);
  }

  delay(50);  // alimentacoes estaveis antes de falar com o ADS (datasheet: >= 50 us)
  ads.begin(PINO_SCLK, PINO_MISO, PINO_MOSI, PINO_CS, PINO_DRDY, SPI_HZ);
  attachInterrupt(PINO_DRDY, isrDrdy, FALLING);

  // Tarefa de aquisicao no nucleo 1 (o NimBLE roda no nucleo 0), prioridade alta.
  xTaskCreatePinnedToCore(tarefaAquisicao, "aquisicao", 6144, nullptr, configMAX_PRIORITIES - 2, &tarefaAq, 1);

  iniciaBle();
  Serial.printf("BLE: anunciando como \"%s\" (%s)\n", NOME_BLE, NimBLEDevice::getAddress().toString().c_str());
  mostraAjuda();
}

void loop() {
  servicoMedicao();  // bloqueia no maximo ~5 ms esperando amostras
  servicoEstado();
  servicoNvs();
  servicoSerial();
  servicoLog();
  servicoGrafico();
}
