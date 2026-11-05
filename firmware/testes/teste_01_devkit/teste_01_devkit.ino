/*
  Projeto SAMBA - Teste 01: saude da DevKit ESP32-S3 (sem ADS, sem pack)

  Objetivo: verificar se a DevKit sobreviveu ao incidente de ~5,1 V no pino 3V3.
  Rode com a DevKit FORA da placa, alimentada so pelo USB.

  O que o teste faz:
    1. Mostra o chip, a revisao, flash, PSRAM, MAC e o motivo do ultimo reset
       (um "BROWNOUT" ou "PANIC" repetido indica dano).
    2. Testa a RAM interna (e a PSRAM, se houver) com padroes de escrita/leitura.
    3. Mede o clock real da CPU contra o relogio do sistema.
    4. Varre redes Wi-Fi e mostra o RSSI (confere o radio e a antena).
    5. Anuncia por BLE como "SAMBA-TESTE" com um contador que notifica 1x por
       segundo (confira no app nRF Connect: conectar, assinar a caracteristica).
    6. A cada 5 s imprime a temperatura interna do chip e a memoria livre.
       Temperatura subindo sem parar com a placa parada = suspeite de dano.

  Arduino IDE: placa "ESP32S3 Dev Module".
  Biblioteca: NimBLE-Arduino 2.x (Gerenciador de Bibliotecas).
  Monitor Serial: 921600 baud. Se estiver usando a porta USB NATIVA da S3
  (a marcada "USB", nao a "UART"), ative "USB CDC On Boot: Enabled".
*/

#include <Arduino.h>
#include <WiFi.h>
#include <NimBLEDevice.h>
#include "esp_system.h"
#include "esp_timer.h"

static const char *UUID_SERVICO_TESTE = "1d77ff01-fc8b-4e8e-aa34-c86e1b9eeaf5";
static const char *UUID_CONTADOR      = "1d77ff02-fc8b-4e8e-aa34-c86e1b9eeaf5";

NimBLECharacteristic *chContador = nullptr;
volatile bool conectado = false;
uint32_t contador = 0;
int falhas = 0;

const char *nomeReset(esp_reset_reason_t r) {
  switch (r) {
    case ESP_RST_POWERON:  return "POWERON (energizacao normal)";
    case ESP_RST_EXT:      return "EXT (pino de reset)";
    case ESP_RST_SW:       return "SW (reinicio por software)";
    case ESP_RST_PANIC:    return "PANIC (travou com excecao)  <-- atencao";
    case ESP_RST_INT_WDT:  return "INT_WDT (watchdog de interrupcao)  <-- atencao";
    case ESP_RST_TASK_WDT: return "TASK_WDT (watchdog de tarefa)  <-- atencao";
    case ESP_RST_WDT:      return "WDT (outro watchdog)  <-- atencao";
    case ESP_RST_DEEPSLEEP:return "DEEPSLEEP";
    case ESP_RST_BROWNOUT: return "BROWNOUT (tensao caiu)  <-- atencao";
    case ESP_RST_SDIO:     return "SDIO";
    case ESP_RST_USB:      return "USB (reset pela porta USB)";
    default:               return "desconhecido";
  }
}

void resultado(const char *teste, bool ok) {
  Serial.printf("  [%s] %s\n", ok ? " OK " : "FALHA", teste);
  if (!ok) falhas++;
}

// Escreve e confere padroes em um bloco de memoria
bool testaMemoria(uint32_t *p, size_t palavras) {
  const uint32_t padroes[] = {0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555};
  for (uint32_t pad : padroes) {
    for (size_t i = 0; i < palavras; i++) p[i] = pad;
    for (size_t i = 0; i < palavras; i++) if (p[i] != pad) return false;
  }
  // endereco como dado: pega linhas de endereco em curto
  for (size_t i = 0; i < palavras; i++) p[i] = (uint32_t)i * 2654435761u;
  for (size_t i = 0; i < palavras; i++) if (p[i] != (uint32_t)i * 2654435761u) return false;
  return true;
}

void testeChip() {
  Serial.println("\n== 1. Chip ==");
  Serial.printf("  Modelo: %s  revisao %d  nucleos %d  CPU %lu MHz\n", ESP.getChipModel(),
                ESP.getChipRevision(), ESP.getChipCores(), (unsigned long)ESP.getCpuFreqMHz());
  Serial.printf("  Flash: %lu MB   PSRAM: %lu KB\n", (unsigned long)(ESP.getFlashChipSize() / (1024 * 1024)),
                (unsigned long)(ESP.getPsramSize() / 1024));
  uint64_t mac = ESP.getEfuseMac();
  Serial.printf("  MAC: %02X:%02X:%02X:%02X:%02X:%02X\n", (uint8_t)(mac), (uint8_t)(mac >> 8),
                (uint8_t)(mac >> 16), (uint8_t)(mac >> 24), (uint8_t)(mac >> 32), (uint8_t)(mac >> 40));
  esp_reset_reason_t r = esp_reset_reason();
  Serial.printf("  Ultimo reset: %s\n", nomeReset(r));
  resultado("modelo e ESP32-S3", String(ESP.getChipModel()).indexOf("S3") >= 0);
  resultado("reset sem brownout/panic/watchdog",
            r != ESP_RST_BROWNOUT && r != ESP_RST_PANIC && r != ESP_RST_INT_WDT &&
            r != ESP_RST_TASK_WDT && r != ESP_RST_WDT);
}

void testeMemoria() {
  Serial.println("\n== 2. Memoria ==");
  Serial.printf("  Heap interno livre: %lu bytes (maior bloco %lu)\n", (unsigned long)ESP.getFreeHeap(),
                (unsigned long)ESP.getMaxAllocHeap());
  size_t maxBloco = ESP.getMaxAllocHeap();
  size_t tam = maxBloco > 16 * 1024 ? maxBloco - 16 * 1024 : 0;  // deixa folga para o Wi-Fi e o BLE
  if (tam > 160 * 1024) tam = 160 * 1024;
  uint32_t *p = (uint32_t *)heap_caps_malloc(tam, MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
  if (p) {
    bool ok = testaMemoria(p, tam / 4);
    free(p);
    Serial.printf("  RAM interna testada: %u KB\n", (unsigned)(tam / 1024));
    resultado("RAM interna", ok);
  } else {
    resultado("alocar RAM interna para o teste", false);
  }
  if (ESP.getPsramSize() > 0) {
    size_t t2 = 1024 * 1024;
    uint32_t *q = (uint32_t *)heap_caps_malloc(t2, MALLOC_CAP_SPIRAM);
    if (q) {
      bool ok = testaMemoria(q, t2 / 4);
      free(q);
      resultado("PSRAM (1 MB)", ok);
    } else {
      resultado("alocar PSRAM", false);
    }
  } else {
    Serial.println("  Sem PSRAM detectada (normal no modulo N8; confira a variante da DevKit).");
  }
}

void testeClock() {
  Serial.println("\n== 3. Clock ==");
  // Conta ciclos da CPU durante 200 ms do esp_timer (que usa outro oscilador interno)
  int64_t t0 = esp_timer_get_time();
  uint32_t c0 = ESP.getCycleCount();
  while (esp_timer_get_time() - t0 < 200000) { }
  uint32_t c1 = ESP.getCycleCount();
  int64_t t1 = esp_timer_get_time();
  float mhz = (float)(c1 - c0) / (float)(t1 - t0);
  Serial.printf("  CPU medida: %.1f MHz (configurada: %lu MHz)\n", mhz, (unsigned long)ESP.getCpuFreqMHz());
  resultado("clock da CPU dentro de 1%", fabsf(mhz - ESP.getCpuFreqMHz()) < ESP.getCpuFreqMHz() * 0.01f);
}

void testeWifi() {
  Serial.println("\n== 4. Radio (varredura Wi-Fi) ==");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  int n = WiFi.scanNetworks();
  if (n <= 0) {
    Serial.println("  Nenhuma rede encontrada. Se ha redes por perto, o radio/antena pode estar com problema.");
  } else {
    for (int i = 0; i < n && i < 8; i++) {
      Serial.printf("  %-28s  RSSI %4d dBm  canal %2d\n", WiFi.SSID(i).c_str(), (int)WiFi.RSSI(i), (int)WiFi.channel(i));
    }
  }
  resultado("radio encontrou pelo menos uma rede", n > 0);
  WiFi.scanDelete();
  WiFi.mode(WIFI_OFF);
  delay(100);
}

class ServidorCb : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *, NimBLEConnInfo &info) override {
    conectado = true;
    Serial.printf("\n[BLE] Conectado: %s\n", info.getAddress().toString().c_str());
  }
  void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int motivo) override {
    conectado = false;
    Serial.printf("\n[BLE] Desconectado (motivo %d). Anunciando de novo.\n", motivo);
  }
  void onMTUChange(uint16_t mtu, NimBLEConnInfo &) override {
    Serial.printf("[BLE] MTU negociado: %u\n", mtu);
  }
};

void testeBle() {
  Serial.println("\n== 5. BLE ==");
  bool ok = NimBLEDevice::init("SAMBA-TESTE");
  NimBLEDevice::setMTU(247);
  NimBLEServer *srv = NimBLEDevice::createServer();
  srv->setCallbacks(new ServidorCb());
  srv->advertiseOnDisconnect(true);
  NimBLEService *svc = srv->createService(UUID_SERVICO_TESTE);
  chContador = svc->createCharacteristic(UUID_CONTADOR, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  chContador->setValue(contador);
  srv->start();
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->enableScanResponse(true);  // UUID (18 B) + flags (3 B) no anuncio; nome (13 B) no scan response
  ok = ok && adv->addServiceUUID(UUID_SERVICO_TESTE);
  ok = ok && adv->setName("SAMBA-TESTE");
  ok = ok && adv->start();
  Serial.printf("  Endereco BLE: %s\n", NimBLEDevice::getAddress().toString().c_str());
  resultado("BLE iniciou e esta anunciando como SAMBA-TESTE", ok);
  Serial.println("  No celular (nRF Connect): procure SAMBA-TESTE, conecte e assine a caracteristica ...ff02.");
  Serial.println("  O valor deve subir 1 por segundo (uint32 little-endian).");
}

void setup() {
  Serial.begin(921600);
  delay(1500);
  Serial.println("\n\nSAMBA - Teste 01: saude da DevKit ESP32-S3");
  testeChip();
  testeMemoria();
  testeClock();
  testeWifi();
  testeBle();
  Serial.printf("\n== Resumo: %d falha(s) ==\n", falhas);
  if (falhas == 0) Serial.println("DevKit aparentemente OK. Toque no regulador e no chip: devem estar frios/mornos.");
  else Serial.println("Ha falhas: troque a DevKit antes de seguir.");
  Serial.println("\nMonitoramento continuo (temperatura e memoria a cada 5 s):");
}

void loop() {
  static uint32_t ultimoSeg = 0, ultimoMon = 0;
  uint32_t agora = millis();
  if (agora - ultimoSeg >= 1000) {
    ultimoSeg = agora;
    contador++;
    chContador->setValue(contador);
    if (conectado) chContador->notify();
  }
  if (agora - ultimoMon >= 5000) {
    ultimoMon = agora;
    Serial.printf("t=%4lus  temp. chip %.1f C  heap livre %lu  BLE %s\n", (unsigned long)(agora / 1000),
                  temperatureRead(), (unsigned long)ESP.getFreeHeap(), conectado ? "conectado" : "anunciando");
  }
  delay(10);
}
