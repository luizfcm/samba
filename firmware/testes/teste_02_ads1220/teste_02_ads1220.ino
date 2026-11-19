/*
  Projeto SAMBA - Teste 02: celula de carga + ADS1220 na placa soldada
  Evolucao do teste_celula_ads1220.ino (mesmos comandos, mesma pinagem) com os
  diagnosticos que faltavam para fechar o PC2 e preparar o firmware BLE.

  ESP32-S3-DevKitC-1 + ADS1220 (CJMCU-1220, SPI) + celula de carga tipo S
    GPIO12 (J1-18) -> SCLK      GPIO11 (J1-17) -> DIN      GPIO13 (J1-19) <- DOUT
    GPIO10 (J1-16) -> CS        GPIO14 (J1-20) <- DRDY
    AVDD = 5 V do LT3042 (= E+ = REFP0)   DVDD = 3V3 da DevKit (0 ohm do modulo RETIRADO)

  Arduino IDE: placa "ESP32S3 Dev Module". Monitor Serial: 921600 baud, "Nova linha".

  A leitura NAO fica rolando na tela: o Monitor Serial so mostra o que voce pedir.
  Comandos (digite e tecle Enter):
    l        UMA leitura (media de 1 s): mV/V e kg
    m        liga/desliga a leitura continua (5 linhas/s). Desligada ao ligar a placa
    p        liga/desliga o modo GRAFICO para o Serial Plotter da IDE (Ferramentas > Plotter Serial):
             imprime so "mV_V:<valor>" 20x/s. "p 10" ou "p 50" muda as linhas por segundo
    t        tara (media de 2 s, celula sem carga)
    c 20     calibra com massa conhecida (kg) aplicada; mostra tambem o fator em mN/contagem
             e o deslocamento no formato do protocolo BLE v2 (para o firmware final)
    r        mostra/esconde o valor bruto
    i        confere os registradores (teste do SPI). Esperado a 20 SPS: 0E 04 40 00
    n        ruido: desvio padrao de 4 s com a celula parada
    f 1000   troca a taxa: 20, 330, 600, 1000 (normal) ou 2000 (turbo)
    s 5      captura crua de 5 s em CSV (indice,tempo_us,contagens,mV_por_V,kg) ate FIM_CSV
    --- novos ---
    a        monitores internos do ADS: AVDD e (REFP0-REFN0) em volts. Detecta pack desligado
    z        ruido do proprio ADS (entradas em curto interno): separa ruido do ADC do ruido
             da celula/cabo. Compare com o "n" na mesma taxa
    v        taxa real e jitter do DRDY por interrupcao (2 s), contando amostras perdidas.
             Use em 1000 SPS antes de confiar no firmware BLE
    k 4      velocidade do SPI em MHz (1 ou 4) + 500 leituras de registradores para conferir
    x        inverte o sinal (fiacao S+/S- ou E+/E- trocada, ou modo tracao x compressao)
    T        temperatura interna do ADS1220
*/

#include <Arduino.h>
#include <SPI.h>
#include "esp_timer.h"

// ---------- Pinos da ESP32-S3 (numeros de GPIO) ----------
const int PINO_SCLK = 12;  // J1-18 -> SCLK do ADS
const int PINO_MISO = 13;  // J1-19 <- DOUT do ADS
const int PINO_MOSI = 11;  // J1-17 -> DIN do ADS
const int PINO_CS   = 10;  // J1-16 -> CS do ADS
const int PINO_DRDY = 14;  // J1-20 <- DRDY do ADS

// ---------- Dados da celula (confira na etiqueta) ----------
const float CAPACIDADE_KG      = 2000.0;  // celula de 2 toneladas
const float SENSIBILIDADE_MV_V = 2.0;     // 2 ou 3 mV/V
const float G = 9.80665;

// ---------- Comandos e configuracao do ADS1220 ----------
const uint8_t CMD_RESET = 0x06;
const uint8_t CMD_START = 0x08;
const uint8_t CMD_RREG  = 0x20;
const uint8_t CMD_WREG  = 0x40;

// Registrador 0: entrada AIN0 (+) e AIN1 (-), ganho 128, PGA ligado
const uint8_t REG0 = 0x0E;
// Registrador 1: taxa, modo e conversao continua (comeca em 20 SPS)
//   20 SPS normal = 0x04 | 330 = 0x84 | 600 = 0xA4 | 1000 = 0xC4 | 2000 turbo = 0xD4
uint8_t REG1 = 0x04;
int AMOSTRAS_POR_SEGUNDO = 20;
// Registrador 2: referencia externa em REFP0/REFN0 (medicao ratiometrica)
const uint8_t REG2 = 0x40;
// Registrador 3: aviso de dado pronto apenas no pino DRDY
const uint8_t REG3 = 0x00;

// Monitores (datasheet SBAS501B, secao 8.3.11): o ADS usa automaticamente a referencia
// interna de 2,048 V e forca PGA desligado (ganho 1). Resultado = tensao / 4.
// No MUX 1100, REG2 deve manter VREF=01 (0x40) para selecionar o par REFP0/REFN0.
const uint8_t REG0_MON_REF  = 0xC1;  // MUX 1100: (V(REFP0) - V(REFN0)) / 4
const uint8_t REG0_MON_AVDD = 0xD1;  // MUX 1101: (AVDD - AVSS) / 4
const uint8_t REG0_CURTO    = 0xEE;  // MUX 1110: AINp = AINn = (AVDD+AVSS)/2, ganho 128

int mediaLinha() { return AMOSTRAS_POR_SEGUNDO >= 5 ? AMOSTRAS_POR_SEGUNDO / 5 : 1; }  // 5 linhas/s
int mediaTara()  { return AMOSTRAS_POR_SEGUNDO * 2; }                                  // 2 s

// Captura crua (comando s): ate 12000 amostras
const int MAX_CAPTURA = 12000;
int32_t  *capValor = nullptr;
uint32_t *capTempo = nullptr;

const float GANHO = 128.0;
const float FUNDO_ESCALA = 8388608.0;  // 2^23 contagens

uint32_t spiHz = 1000000;
SPISettings configSPI(spiHz, MSBFIRST, SPI_MODE1);  // modo SPI 1

long tara = 0;
float contagensPorKg = 0;  // 0 = ainda sem calibracao
bool mostrarBruto = false;
bool leituraContinua = false;  // comando m: so imprime sem parar se voce pedir
bool modoGrafico = false;      // comando p: saida "mV_V:valor" para o Serial Plotter
int linhasGrafico = 20;        // linhas por segundo no modo grafico
int sinal = 1;             // +1 ou -1 (comando x)

// ---------- Funcoes do ADS1220 ----------
void adsComando(uint8_t cmd) {
  SPI.beginTransaction(configSPI);
  digitalWrite(PINO_CS, LOW);
  SPI.transfer(cmd);
  digitalWrite(PINO_CS, HIGH);
  SPI.endTransaction();
}

void adsEscreveRegistradores() {
  SPI.beginTransaction(configSPI);
  digitalWrite(PINO_CS, LOW);
  SPI.transfer(CMD_WREG | 0x03);  // a partir do registrador 0, escreve 4
  SPI.transfer(REG0);
  SPI.transfer(REG1);
  SPI.transfer(REG2);
  SPI.transfer(REG3);
  digitalWrite(PINO_CS, HIGH);
  SPI.endTransaction();
}

void adsEscreveReg(uint8_t reg, uint8_t valor) {
  SPI.beginTransaction(configSPI);
  digitalWrite(PINO_CS, LOW);
  SPI.transfer(CMD_WREG | (reg << 2));  // 1 byte a partir de "reg"
  SPI.transfer(valor);
  digitalWrite(PINO_CS, HIGH);
  SPI.endTransaction();
}

void adsLeRegistradores(uint8_t regs[4]) {
  SPI.beginTransaction(configSPI);
  digitalWrite(PINO_CS, LOW);
  SPI.transfer(CMD_RREG | 0x03);  // a partir do registrador 0, le 4
  for (int i = 0; i < 4; i++) regs[i] = SPI.transfer(0xFF);
  digitalWrite(PINO_CS, HIGH);
  SPI.endTransaction();
}

// Le os 24 bits da conversao (sem esperar o DRDY)
long adsLeDado() {
  SPI.beginTransaction(configSPI);
  digitalWrite(PINO_CS, LOW);
  uint32_t b2 = SPI.transfer(0xFF);
  uint32_t b1 = SPI.transfer(0xFF);
  uint32_t b0 = SPI.transfer(0xFF);
  digitalWrite(PINO_CS, HIGH);
  SPI.endTransaction();
  long v = (long)((b2 << 16) | (b1 << 8) | b0);
  if (v & 0x800000) v -= 0x1000000;  // numero negativo (24 bits)
  return v;
}

// Espera o DRDY descer e le os 24 bits da conversao
bool adsLeAmostra(long &valor, unsigned long limiteMs) {
  unsigned long inicio = millis();
  while (digitalRead(PINO_DRDY) == HIGH) {
    if (millis() - inicio > limiteMs) return false;
  }
  valor = adsLeDado();
  return true;
}

long adsMedia(int n) {
  long long soma = 0;
  int lidas = 0;
  for (int i = 0; i < n; i++) {
    long v;
    if (adsLeAmostra(v, 500)) {
      soma += v;
      lidas++;
    } else {
      Serial.println("ERRO: DRDY nao respondeu; media interrompida.");
      break;  // nao fica travado n x 500 ms se o ADS estiver mudo
    }
  }
  if (lidas == 0) return 0;
  return (long)(soma / lidas);
}

float paraMvPorV(long contagens) {
  return contagens * 1000.0 / (FUNDO_ESCALA * GANHO);
}

int timeoutMs() { return 3000 / AMOSTRAS_POR_SEGUNDO + 50; }

// Troca a configuracao (REG0/REG1/REG2), descarta 2 conversoes, faz a media de n
// e devolve a configuracao normal. Retorna false se o DRDY nao responder.
bool adsMediaComConfig(uint8_t r0, uint8_t r1, uint8_t r2, int n, double &media) {
  adsEscreveReg(0, r0);
  adsEscreveReg(1, r1);
  adsEscreveReg(2, r2);
  adsComando(CMD_START);
  long v;
  bool ok = adsLeAmostra(v, timeoutMs()) && adsLeAmostra(v, timeoutMs());  // descarta 2
  long long soma = 0;
  int lidas = 0;
  for (int i = 0; ok && i < n; i++) {
    if (adsLeAmostra(v, timeoutMs())) { soma += v; lidas++; }
  }
  adsEscreveRegistradores();
  adsComando(CMD_START);
  adsLeAmostra(v, timeoutMs());  // descarta a 1a apos voltar
  if (!ok || lidas == 0) return false;
  media = (double)soma / lidas;
  return true;
}

// ---------- Diagnosticos ----------
void medeRuido(int n) {
  Serial.printf("Medindo o ruido com %d leituras: nao toque na celula...\n", n);
  double soma = 0, soma2 = 0;
  long ref = 0;
  int lidas = 0;
  for (int i = 0; i < n; i++) {
    long v;
    if (adsLeAmostra(v, 500)) {
      if (lidas == 0) ref = v;
      double d = (double)(v - ref);
      soma += d;
      soma2 += d * d;
      lidas++;
    }
  }
  if (lidas < 2) {
    Serial.println("ERRO: poucas leituras. Confira o DRDY e a alimentacao do ADS.");
    return;
  }
  double media = soma / lidas;
  double variancia = (soma2 - lidas * media * media) / (lidas - 1);
  double desvio = sqrt(variancia > 0.0 ? variancia : 0.0);
  Serial.printf("Ruido: %.1f contagens RMS (%.6f mV/V)", desvio, desvio * 1000.0 / (FUNDO_ESCALA * GANHO));
  if (contagensPorKg != 0) Serial.printf(" = %.3f kg = %.1f N", desvio / fabs(contagensPorKg), desvio / fabs(contagensPorKg) * G);
  Serial.printf("  | pico a pico ~%.0f contagens\n", desvio * 6.6);
}

void monitores() {
  double m;
  Serial.println("Monitores internos do ADS1220 (referencia interna 2,048 V):");
  if (adsMediaComConfig(REG0_MON_AVDD, REG1, REG2, 8, m)) {
    float avdd = m / FUNDO_ESCALA * 2.048 * 4.0;
    Serial.printf("  AVDD          = %.3f V  ", avdd);
    if (avdd < 1.0) Serial.println("-> AVDD AUSENTE: pack desligado/chave aberta. Leituras sem sentido.");
    else if (avdd < 4.5) Serial.println("-> BAIXA: provavel retroalimentacao pelo USB com o pack desligado.");
    else if (avdd > 5.5) Serial.println("-> ACIMA do maximo do ADS (5,5 V)! Desligue.");
    else Serial.println("-> OK (esperado ~5,1 V do LT3042)");
  } else {
    Serial.println("  AVDD: sem DRDY.");
  }
  if (adsMediaComConfig(REG0_MON_REF, REG1, REG2, 8, m)) {
    float vref = m / FUNDO_ESCALA * 2.048 * 4.0;
    Serial.printf("  REFP0 - REFN0 = %.3f V  ", vref);
    Serial.println(vref > 4.5 ? "-> OK (deve ficar a poucos mV do AVDD)" : "-> confira E+/REFP0 e o fio de referencia E-/REFN0 (5.3)");
  } else {
    Serial.println("  REF: sem DRDY.");
  }
}

void ruidoCurto() {
  Serial.printf("Ruido do ADS com as entradas em curto interno (%d SPS, ganho 128):\n", AMOSTRAS_POR_SEGUNDO);
  adsEscreveReg(0, REG0_CURTO);
  adsComando(CMD_START);
  long v;
  adsLeAmostra(v, timeoutMs());
  adsLeAmostra(v, timeoutMs());
  medeRuido(AMOSTRAS_POR_SEGUNDO * 2 > 40 ? AMOSTRAS_POR_SEGUNDO * 2 : 40);
  adsEscreveRegistradores();
  adsComando(CMD_START);
  adsLeAmostra(v, timeoutMs());
  Serial.println("Compare com o 'n': se o 'n' for muito maior, o ruido vem da celula, do cabo ou da excitacao.");
}

void temperaturaAds() {
  double m;
  // TS = bit 1 do REG1. Resultado de 14 bits alinhado a esquerda; 0,03125 C por LSB.
  if (adsMediaComConfig(REG0, REG1 | 0x02, REG2, 4, m)) {
    Serial.printf("Temperatura interna do ADS1220: %.2f C\n", (m / 1024.0) * 0.03125);
  } else {
    Serial.println("Temperatura: sem DRDY.");
  }
}

// --- Teste de temporizacao do DRDY por interrupcao (como no firmware final) ---
volatile uint32_t isrContagem = 0;
volatile int64_t isrTempo = 0;
portMUX_TYPE muxIsr = portMUX_INITIALIZER_UNLOCKED;
void IRAM_ATTR isrDrdy() {
  portENTER_CRITICAL_ISR(&muxIsr);
  isrTempo = esp_timer_get_time();
  isrContagem = isrContagem + 1;
  portEXIT_CRITICAL_ISR(&muxIsr);
}

void testeDrdy() {
  Serial.printf("Teste do DRDY por interrupcao: 2 s a %d SPS, SPI a %lu MHz...\n", AMOSTRAS_POR_SEGUNDO,
                (unsigned long)(spiHz / 1000000));
  long v;
  adsLeAmostra(v, timeoutMs());
  isrContagem = 0;
  attachInterrupt(PINO_DRDY, isrDrdy, FALLING);
  uint32_t ultimo = 0, cPrimeiro = 0, lidas = 0, perdidas = 0;
  int64_t tPrimeiro = 0, tAnterior = 0, pMin = INT64_MAX, pMax = 0;
  int64_t fim = esp_timer_get_time() + 2000000;
  while (esp_timer_get_time() < fim) {
    portENTER_CRITICAL(&muxIsr);
    uint32_t c = isrContagem;
    int64_t t = isrTempo;
    portEXIT_CRITICAL(&muxIsr);
    if (c == ultimo) continue;
    adsLeDado();
    if (lidas > 0) {
      perdidas += c - ultimo - 1;
      int64_t p = (t - tAnterior) / (int64_t)(c - ultimo);
      if (p < pMin) pMin = p;
      if (p > pMax) pMax = p;
    } else {
      tPrimeiro = t;
      cPrimeiro = c;
    }
    tAnterior = t;
    ultimo = c;
    lidas++;
  }
  detachInterrupt(PINO_DRDY);
  if (lidas < 3) {
    Serial.println("ERRO: quase nenhum DRDY. Confira o GPIO14 e a alimentacao do ADS.");
    return;
  }
  double taxa = (double)(ultimo - cPrimeiro) * 1e6 / (double)(tAnterior - tPrimeiro);
  Serial.printf("  Taxa real: %.2f SPS (nominal %d, desvio %+.2f %%)\n", taxa, AMOSTRAS_POR_SEGUNDO,
                (taxa / AMOSTRAS_POR_SEGUNDO - 1.0) * 100.0);
  Serial.printf("  Periodo: min %lld us, max %lld us | lidas %lu, perdidas %lu\n", (long long)pMin, (long long)pMax,
                (unsigned long)lidas, (unsigned long)perdidas);
  Serial.println(perdidas == 0 ? "  OK: nenhuma amostra perdida." : "  ATENCAO: amostras perdidas (o loop nao acompanhou).");
}

void velocidadeSpi(int mhz) {
  if (mhz != 1 && mhz != 4) {
    Serial.println("Use: k 1  ou  k 4");
    return;
  }
  spiHz = (uint32_t)mhz * 1000000;
  configSPI = SPISettings(spiHz, MSBFIRST, SPI_MODE1);
  int erros = 0;
  for (int i = 0; i < 500; i++) {
    uint8_t r[4];
    adsLeRegistradores(r);
    if (r[0] != REG0 || r[1] != REG1 || r[2] != REG2 || r[3] != REG3) erros++;
  }
  Serial.printf("SPI a %d MHz: %d erro(s) em 500 leituras dos registradores. %s\n", mhz, erros,
                erros == 0 ? "OK" : "Volte para 1 MHz e confira os fios 6.1 a 6.5.");
}

bool trocaTaxa(int sps) {
  uint8_t r;
  if (sps == 20) r = 0x04;
  else if (sps == 330) r = 0x84;
  else if (sps == 600) r = 0xA4;
  else if (sps == 1000) r = 0xC4;
  else if (sps == 2000) r = 0xD4;
  else return false;
  REG1 = r;
  AMOSTRAS_POR_SEGUNDO = sps;
  adsEscreveReg(1, REG1);
  adsComando(CMD_START);
  delay(20);
  return true;
}

float kgDe(long liquido) {
  if (contagensPorKg != 0) return liquido / contagensPorKg;
  return sinal * paraMvPorV(liquido) / SENSIBILIDADE_MV_V * CAPACIDADE_KG;
}

void capturaCrua(float segundos) {
  if (capValor == nullptr) {
    capValor = (int32_t *)malloc(MAX_CAPTURA * sizeof(int32_t));
    capTempo = (uint32_t *)malloc(MAX_CAPTURA * sizeof(uint32_t));
    if (capValor == nullptr || capTempo == nullptr) {
      Serial.println("ERRO: sem memoria para a captura.");
      return;
    }
  }
  long total = (long)(segundos * AMOSTRAS_POR_SEGUNDO);
  if (total > MAX_CAPTURA) total = MAX_CAPTURA;
  if (total < 1) total = 1;
  Serial.printf("Captura de %ld amostras a %d SPS: comece o movimento agora.\n", total, AMOSTRAS_POR_SEGUNDO);
  Serial.flush();
  long lidas = 0;
  uint32_t t0 = micros();
  while (lidas < total) {
    long v;
    if (!adsLeAmostra(v, 200)) break;
    capTempo[lidas] = micros() - t0;
    capValor[lidas] = (int32_t)v;
    lidas++;
  }
  Serial.printf("Fim da captura: %ld amostras. Dados a seguir.\n", lidas);
  Serial.println("indice,tempo_us,contagens,mV_por_V,kg");
  for (long i = 0; i < lidas; i++) {
    long liquido = capValor[i] - tara;
    Serial.printf("%ld,%lu,%ld,%.6f,%.3f\n", i, (unsigned long)capTempo[i], (long)capValor[i],
                  sinal * paraMvPorV(liquido), kgDe(liquido));
  }
  Serial.println("FIM_CSV");
}

// ---------- Mensagens ----------
void imprimeLeitura(long media) {
  long liquido = media - tara;
  float mvv = sinal * paraMvPorV(liquido);
  if (mostrarBruto) Serial.printf("bruto %9ld | ", media);
  if (contagensPorKg != 0) {
    Serial.printf("%+.5f mV/V | %8.2f kg (calibrado)\n", mvv, kgDe(liquido));
  } else {
    Serial.printf("%+.5f mV/V | %8.1f kg (estimado pela etiqueta)\n", mvv, kgDe(liquido));
  }
}

void leituraUnica() {
  long v;
  if (!adsLeAmostra(v, timeoutMs())) {  // confirma que o ADS esta vivo antes de fazer a media
    Serial.println("Sem sinal no DRDY: confira o fio do DRDY (GPIO14) e a alimentacao do ADS.");
    return;
  }
  imprimeLeitura(adsMedia(AMOSTRAS_POR_SEGUNDO));  // 1 s
}

void mostraRegistradores() {
  uint8_t regs[4];
  adsLeRegistradores(regs);
  Serial.printf("Registradores do ADS1220: %02X %02X %02X %02X (esperado: %02X %02X %02X %02X)\n",
                regs[0], regs[1], regs[2], regs[3], REG0, REG1, REG2, REG3);
  if (regs[0] == REG0 && regs[1] == REG1 && regs[2] == REG2 && regs[3] == REG3) {
    Serial.println("Comunicacao SPI OK.");
  } else {
    Serial.println("ERRO: o ADS nao respondeu como esperado.");
    Serial.println("  FF FF FF FF: confira DOUT (GPIO13), CS (GPIO10) e a alimentacao do ADS.");
    Serial.println("  00 00 00 00: confira SCLK (GPIO12), DIN (GPIO11) e o GND.");
  }
}

void mostraAjuda() {
  Serial.println();
  Serial.printf("Leitura continua: %s. Taxa atual: %d SPS. SPI: %lu MHz.\n", leituraContinua ? "LIGADA" : "desligada",
                AMOSTRAS_POR_SEGUNDO, (unsigned long)(spiHz / 1000000));
  Serial.println("Comandos: l 1 leitura | m leitura continua | p grafico (Serial Plotter) | t tara | c <kg> calibra | r bruto");
  Serial.println("          i registradores | n ruido | f <SPS> taxa | s <seg> captura");
  Serial.println("          a AVDD/REF | z ruido do ADS | v teste DRDY | k <MHz> SPI | x inverte sinal | T temperatura");
  Serial.println();
}

void trataComando() {
  static String bufSerial;
  String linha;
  bool temLinha = false;
  while (Serial.available()) {
    char ch = (char)Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (bufSerial.length() > 0) {
        linha = bufSerial;
        bufSerial = "";
        temLinha = true;
        break;
      }
    } else if (bufSerial.length() < 80) {
      bufSerial += ch;
    }
  }
  if (!temLinha) return;
  linha.trim();
  if (linha.length() == 0) return;
  char c0 = linha.charAt(0);
  char c = tolower(c0);

  if (c0 == 'T') {
    temperaturaAds();
  } else if (c == 't') {
    Serial.println("Tara: deixe a celula sem carga...");
    tara = adsMedia(mediaTara());
    Serial.printf("Tara feita: %ld contagens.\n", tara);
  } else if (c == 'c') {
    float massa = linha.substring(1).toFloat();
    if (massa <= 0) {
      Serial.println("Use assim: c 20   (massa conhecida em kg, ja aplicada na celula)");
      return;
    }
    Serial.printf("Calibrando com %.2f kg: mantenha a carga parada...\n", massa);
    long leitura = adsMedia(mediaTara());
    long diferenca = leitura - tara;
    if (diferenca == 0) {
      Serial.println("ERRO: a leitura nao mudou. Confira a carga e as ligacoes de S+ e S-.");
      return;
    }
    contagensPorKg = diferenca / massa;
    Serial.printf("Calibrado: %.2f contagens por kg.\n", contagensPorKg);
    Serial.printf("Protocolo BLE v2: fator = %.7f mN/contagem, deslocamento = %ld contagens\n",
                  1000.0 * G / contagensPorKg, tara);
    Serial.printf("  No firmware final, pelo Monitor Serial: cal %.7f %ld\n", 1000.0 * G / contagensPorKg, tara);
    Serial.println("  (o fator ja carrega o sinal: negativo = leitura invertida)");
  } else if (c == 'l') {
    leituraUnica();
  } else if (c == 'm') {
    leituraContinua = !leituraContinua;
    modoGrafico = false;
    Serial.printf("Leitura continua %s.\n", leituraContinua ? "LIGADA (digite m para parar)" : "desligada");
  } else if (c == 'p') {
    int lps = linha.substring(1).toInt();
    if (lps > 0) {
      linhasGrafico = constrain(lps, 1, 100);
      modoGrafico = true;
    } else {
      modoGrafico = !modoGrafico;
    }
    leituraContinua = false;
    if (modoGrafico) {
      Serial.printf("Modo grafico: %d pontos/s em mV/V. Abra Ferramentas > Plotter Serial. Digite p para sair.\n",
                    linhasGrafico);
    } else {
      Serial.println("Modo grafico desligado.");
    }
  } else if (c == 'r') {
    mostrarBruto = !mostrarBruto;
    Serial.printf("Valor bruto %s nas leituras.\n", mostrarBruto ? "visivel" : "escondido");
  } else if (c == 'i') {
    mostraRegistradores();
  } else if (c == 'n') {
    medeRuido(AMOSTRAS_POR_SEGUNDO * 4);
  } else if (c == 'f') {
    int sps = linha.substring(1).toInt();
    if (trocaTaxa(sps)) {
      Serial.printf("Taxa: %d amostras/s. Faca a tara de novo (t).\n", sps);
      mostraRegistradores();
    } else {
      Serial.println("Use: f 20, f 330, f 600, f 1000 ou f 2000");
    }
  } else if (c == 's') {
    float seg = linha.substring(1).toFloat();
    if (seg <= 0) seg = 5;
    capturaCrua(seg);
  } else if (c == 'a') {
    monitores();
  } else if (c == 'z') {
    ruidoCurto();
  } else if (c == 'v') {
    testeDrdy();
  } else if (c == 'k') {
    velocidadeSpi(linha.substring(1).toInt());
  } else if (c == 'x') {
    sinal = -sinal;
    Serial.printf("Sinal: %s (vale para a leitura estimada; a calibracao 'c' ja embute o sinal).\n",
                  sinal > 0 ? "normal" : "invertido");
  } else {
    mostraAjuda();
  }
}

// ---------- Programa ----------
void setup() {
  Serial.begin(921600);
  delay(1500);
  Serial.println();
  Serial.println("SAMBA - Teste 02: celula de carga com ADS1220");

  pinMode(PINO_CS, OUTPUT);
  digitalWrite(PINO_CS, HIGH);
  pinMode(PINO_DRDY, INPUT);
  SPI.begin(PINO_SCLK, PINO_MISO, PINO_MOSI, PINO_CS);

  delay(50);  // alimentacoes estaveis antes de falar com o ADS
  adsComando(CMD_RESET);
  delay(5);
  adsEscreveRegistradores();
  mostraRegistradores();
  uint8_t regs[4];
  adsLeRegistradores(regs);
  bool spiOk = regs[0] == REG0 && regs[1] == REG1 && regs[2] == REG2 && regs[3] == REG3;

  adsComando(CMD_START);
  delay(100);
  long v;
  bool drdyOk = adsLeAmostra(v, 500);
  if (!drdyOk) Serial.println("ERRO: nenhum DRDY em 500 ms. Confira o fio 6.1 (DRDY -> GPIO14) e o DVDD (3,3 V).");

  if (spiOk && drdyOk) {
    monitores();  // primeira coisa util: o AVDD diz se o pack/LT3042 esta chegando ao ADS
    Serial.println("Tara inicial: deixe a celula sem carga...");
    tara = adsMedia(mediaTara());
    Serial.printf("Tara feita: %ld contagens.\n", tara);
  } else {
    Serial.println("Tara e monitores pulados: resolva o SPI/DRDY primeiro (use 'i' para repetir o teste).");
  }
  mostraAjuda();
}

void loop() {
  trataComando();

  static int64_t soma = 0;
  static int n = 0;
  if (!leituraContinua && !modoGrafico) {  // modo silencioso: so responde aos comandos
    soma = 0;
    n = 0;
    delay(5);
    return;
  }
  long v;
  if (!adsLeAmostra(v, 500)) {
    Serial.println("Sem sinal no DRDY: confira o fio do DRDY (GPIO14) e a alimentacao do ADS. Leitura desligada.");
    leituraContinua = false;
    modoGrafico = false;
    return;
  }
  soma += v;
  n++;
  int alvo = modoGrafico ? max(1, AMOSTRAS_POR_SEGUNDO / linhasGrafico) : mediaLinha();
  if (n < alvo) return;

  long media = (long)(soma / n);
  soma = 0;
  n = 0;
  if (modoGrafico) {
    Serial.printf("mV_V:%.5f\n", sinal * paraMvPorV(media - tara));  // formato "rotulo:valor" do Serial Plotter
  } else {
    imprimeLeitura(media);
  }
}
