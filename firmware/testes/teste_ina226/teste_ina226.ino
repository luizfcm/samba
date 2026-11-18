/*
  Projeto SAMBA - Teste basico do INA226

  O INA226 fica depois da chave: mede a tensao do pack e TODA a corrente que o sistema consome
  (ESP32-S3 + ADS1220 + celula + reguladores). A corrente de carga do pack nao passa por ele.

  Ligacoes: SDA = GPIO1 (J3-4), SCL = GPIO2 (J3-5), VCC = 3V3 (J1-2), GND = J3-1.
  Shunt R100 = 0,100 ohm (ja vem no modulo). Endereco esperado 0x40 (A0 e A1 no GND).

  O que o teste faz:
    1. Varre o barramento I2C e mostra o que encontrou.
    2. Confere os numeros de identificacao (fabricante 0x5449 "TI", chip 0x2260).
    3. Programa a configuracao (media de 16, 1,1 ms por conversao, continuo) e a calibracao do R100,
       e le de volta para conferir.
    4. A cada 0,5 s: tensao do pack, tensao no shunt, corrente e potencia.
    5. A cada 10 s: resumo (corrente minima/media/maxima, potencia media) e autonomia estimada.

  Comandos no Monitor Serial (921600 baud, "Nova linha"):
    m 85      ajuste fino: informe a corrente que o MULTIMETRO mede (mA) e a calibracao e corrigida
              (multimetro em serie entre ENTRA e SAI do borne CHAVE)
    r         zera o resumo
    i         repete a identificacao e a conferencia dos registradores

  Arduino IDE: placa "ESP32S3 Dev Module". So usa a biblioteca Wire.
  Depois do teste, grave de novo o firmware/samba_firmware para voltar a usar o Bluetooth.
*/

#include <Arduino.h>
#include <Wire.h>

// ---------- Ligacoes e componentes ----------
const int PINO_SDA = 1;
const int PINO_SCL = 2;
const uint8_t INA_ADDR = 0x40;

const float R_SHUNT = 0.100;       // ohm (R100 do modulo)
const float CURRENT_LSB = 25e-6;   // A por bit: 0,82 A de fundo de escala / 32768
uint16_t CAL = 2048;               // 0,00512 / (CURRENT_LSB x R_SHUNT); pode ser ajustado com o comando m
const uint16_t CONFIG = 0x4527;    // media de 16, VBUS e VSHUNT com 1,1 ms, modo continuo

// ---------- Bateria (para a estimativa de autonomia) ----------
const float CAPACIDADE_MAH = 2450.0;  // pack 3S de celulas 18650 de 2450 mAh
const float FRACAO_UTIL = 0.80;       // usa 80% da capacidade nominal

// ---------- Registradores do INA226 (datasheet TI SBOS547) ----------
const uint8_t REG_CONFIG = 0x00, REG_SHUNT = 0x01, REG_BUS = 0x02, REG_POWER = 0x03, REG_CURRENT = 0x04,
              REG_CAL = 0x05, REG_MASK = 0x06, REG_FAB = 0xFE, REG_DIE = 0xFF;

int falhas = 0;

struct Leitura {
  float vBus, vShunt, corrente, potencia;
  bool estouro;
  bool ok;
};

bool inaEscreve(uint8_t reg, uint16_t valor) {
  Wire.beginTransmission(INA_ADDR);
  Wire.write(reg);
  Wire.write(valor >> 8);
  Wire.write(valor & 0xFF);
  return Wire.endTransmission() == 0;
}

bool inaLe(uint8_t reg, uint16_t &valor) {
  Wire.beginTransmission(INA_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((int)INA_ADDR, 2) != 2) return false;
  valor = (uint16_t)Wire.read() << 8;
  valor |= Wire.read();
  return true;
}

void resultado(const char *teste, bool ok) {
  Serial.printf("  [%s] %s\n", ok ? " OK " : "FALHA", teste);
  if (!ok) falhas++;
}

void varreduraI2c() {
  Serial.println("\n== 1. Varredura do I2C (SDA=GPIO1, SCL=GPIO2) ==");
  int achados = 0;
  for (uint8_t a = 1; a < 127; a++) {
    Wire.beginTransmission(a);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  dispositivo em 0x%02X%s\n", a, a == INA_ADDR ? "  <- INA226" : "");
      achados++;
    }
  }
  if (achados == 0) {
    Serial.println("  Nenhum dispositivo. Confira VCC (E3 s2), GND (E2), SDA (E1 s1 -> J3-4) e SCL (D5 s1 -> J3-5).");
  }
  Wire.beginTransmission(INA_ADDR);
  resultado("INA226 responde no endereco 0x40", Wire.endTransmission() == 0);
}

void identificacao() {
  Serial.println("\n== 2. Identificacao e registradores ==");
  uint16_t fab = 0, die = 0, cfg = 0, cal = 0;
  bool ok = inaLe(REG_FAB, fab) && inaLe(REG_DIE, die);
  Serial.printf("  fabricante 0x%04X (esperado 0x5449) | chip 0x%04X (esperado 0x2260)\n", fab, die);
  resultado("identificacao do INA226", ok && fab == 0x5449 && die == 0x2260);
  inaEscreve(REG_CONFIG, CONFIG);
  inaEscreve(REG_CAL, CAL);
  delay(5);
  inaLe(REG_CONFIG, cfg);
  inaLe(REG_CAL, cal);
  Serial.printf("  configuracao 0x%04X (gravado 0x%04X) | calibracao %u (gravado %u)\n", cfg, CONFIG, cal, CAL);
  resultado("configuracao e calibracao gravadas e lidas de volta", cfg == CONFIG && cal == CAL);
}

Leitura le() {
  Leitura l{};
  uint16_t vb, vs, cr, pw, mask;
  l.ok = inaLe(REG_BUS, vb) && inaLe(REG_SHUNT, vs) && inaLe(REG_CURRENT, cr) && inaLe(REG_POWER, pw) &&
         inaLe(REG_MASK, mask);
  if (!l.ok) return l;
  l.vBus = vb * 1.25e-3;                         // V, 1,25 mV por bit
  l.vShunt = (int16_t)vs * 2.5e-6;               // V, 2,5 uV por bit
  l.corrente = (int16_t)cr * CURRENT_LSB;        // A
  l.potencia = pw * 25.0 * CURRENT_LSB;          // W, Power_LSB = 25 x Current_LSB
  l.estouro = mask & (1 << 2);                   // OVF: a potencia/corrente passou do fundo de escala
  return l;
}

// ---------- Resumo ----------
float iMin = 1e9, iMax = -1e9, iSoma = 0, pSoma = 0, vUlt = 0;
uint32_t nAmostras = 0, inicioResumo = 0;

void zeraResumo() {
  iMin = 1e9; iMax = -1e9; iSoma = 0; pSoma = 0; nAmostras = 0; inicioResumo = millis();
}

void mostraResumo() {
  if (nAmostras == 0) return;
  float iMed = iSoma / nAmostras, pMed = pSoma / nAmostras;
  Serial.println("\n---------------- resumo dos ultimos 10 s ----------------");
  Serial.printf("  corrente: min %.1f mA | media %.1f mA | max %.1f mA\n", iMin * 1e3, iMed * 1e3, iMax * 1e3);
  Serial.printf("  potencia media %.3f W | pack %.3f V (%.2f V por celula)\n", pMed, vUlt, vUlt / 3.0);
  if (iMed > 0.001) {
    float horas = CAPACIDADE_MAH * FRACAO_UTIL / (iMed * 1e3);
    Serial.printf("  autonomia estimada: %.1f h (%.0f mAh x %.0f%% / %.1f mA)\n", horas, CAPACIDADE_MAH,
                  FRACAO_UTIL * 100, iMed * 1e3);
  }
  bool vOk = vUlt > 9.0 && vUlt < 12.7;
  bool iOk = iMed > 0.020 && iMed < 0.400;
  Serial.printf("  %s tensao do pack na faixa 9,0 a 12,7 V\n", vOk ? "[ OK ]" : "[ATENCAO]");
  Serial.printf("  %s corrente media na faixa esperada (20 a 400 mA)%s\n", iOk ? "[ OK ]" : "[ATENCAO]",
                iMed < 0.005 ? " -> quase zero: a corrente esta passando pelo shunt? (JP1 cortado e pontes 9.7)" : "");
  if (vUlt < 10.2 && vUlt > 1.0) Serial.println("  [ATENCAO] bateria fraca: abaixo de 10,2 V (3,4 V por celula)");
  Serial.println("---------------------------------------------------------\n");
  zeraResumo();
}

void trataSerial() {
  static String buf;
  while (Serial.available()) {
    char c = Serial.read();
    if (c != '\n' && c != '\r') {
      if (buf.length() < 40) buf += c;
      continue;
    }
    buf.trim();
    if (buf.length() == 0) continue;
    char cmd = buf.charAt(0);
    if (cmd == 'm') {
      float mAmult = buf.substring(1).toFloat();
      Leitura l = le();
      if (mAmult <= 0 || !l.ok || l.corrente <= 0.001) {
        Serial.println("Use: m 85   (corrente medida pelo multimetro em mA, com o sistema ligado)");
      } else {
        uint16_t novo = (uint16_t)lroundf(CAL * (mAmult / 1000.0f) / l.corrente);
        Serial.printf("Ajuste fino: INA %.1f mA, multimetro %.1f mA -> CAL %u -> %u (anote e troque no codigo)\n",
                      l.corrente * 1e3, mAmult, CAL, novo);
        CAL = novo;
        inaEscreve(REG_CAL, CAL);
        zeraResumo();
      }
    } else if (cmd == 'r') {
      zeraResumo();
      Serial.println("Resumo zerado.");
    } else if (cmd == 'i') {
      identificacao();
    } else {
      Serial.println("Comandos: m <mA do multimetro> | r (zera resumo) | i (identificacao)");
    }
    buf = "";
  }
}

void setup() {
  Serial.begin(921600);
  delay(1500);
  Serial.println("\n\nSAMBA - Teste basico do INA226");
  Wire.begin(PINO_SDA, PINO_SCL);
  Wire.setClock(400000);
  varreduraI2c();
  identificacao();
  delay(50);  // espera a 1a conversao com media de 16 (~35 ms)

  Serial.println("\n== 3. Primeira leitura ==");
  Leitura l = le();
  resultado("leitura dos registradores de medida", l.ok);
  if (l.ok) {
    Serial.printf("  pack %.3f V | shunt %.3f mV | corrente %.1f mA | potencia %.3f W\n", l.vBus, l.vShunt * 1e3,
                  l.corrente * 1e3, l.potencia);
    resultado("tensao do pack entre 9 e 12,7 V (pack ligado e chave fechada)", l.vBus > 9.0 && l.vBus < 12.7);
    resultado("corrente positiva (IN+ do lado da chave, IN- do lado das cargas)", l.corrente > 0);
    float pCalc = l.vBus * l.corrente;
    resultado("potencia do INA confere com tensao x corrente (+-5%)",
              l.corrente > 0.005 && fabsf(l.potencia - pCalc) < 0.05f * pCalc + 0.002f);
  }
  Serial.printf("\n== Resumo inicial: %d falha(s) ==\n", falhas);
  Serial.println("Leitura continua a cada 0,5 s; resumo a cada 10 s. Comandos: m <mA> | r | i\n");
  zeraResumo();
}

void loop() {
  trataSerial();
  static uint32_t ultimo = 0;
  if (millis() - ultimo < 500) return;
  ultimo = millis();
  Leitura l = le();
  if (!l.ok) {
    Serial.println("ERRO: o INA226 nao respondeu (confira SDA, SCL, VCC e GND)");
    return;
  }
  Serial.printf("pack %6.3f V | shunt %7.3f mV | %6.1f mA | %6.3f W%s\n", l.vBus, l.vShunt * 1e3, l.corrente * 1e3,
                l.potencia, l.estouro ? " | ESTOURO (acima de 0,82 A)" : "");
  vUlt = l.vBus;
  iMin = min(iMin, l.corrente);
  iMax = max(iMax, l.corrente);
  iSoma += l.corrente;
  pSoma += l.potencia;
  nAmostras++;
  if (millis() - inicioResumo >= 10000) mostraResumo();
}
