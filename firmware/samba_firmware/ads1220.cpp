#include "ads1220.h"

void Ads1220::begin(int sclk, int miso, int mosi, int cs, int drdy, uint32_t spiHz) {
  _cs = cs;
  _drdy = drdy;
  _spi = SPISettings(spiHz, MSBFIRST, SPI_MODE1);  // CPOL 0, CPHA 1
  pinMode(_cs, OUTPUT);
  digitalWrite(_cs, HIGH);
  pinMode(_drdy, INPUT);
  SPI.begin(sclk, miso, mosi, cs);  // GPIO10-13 = FSPI nativo (IOMUX)
}

void Ads1220::comando(uint8_t cmd) {
  SPI.beginTransaction(_spi);
  digitalWrite(_cs, LOW);
  SPI.transfer(cmd);
  digitalWrite(_cs, HIGH);
  SPI.endTransaction();
}

void Ads1220::escreveReg(uint8_t reg, uint8_t valor) {
  SPI.beginTransaction(_spi);
  digitalWrite(_cs, LOW);
  SPI.transfer(CMD_WREG | (reg << 2));
  SPI.transfer(valor);
  digitalWrite(_cs, HIGH);
  SPI.endTransaction();
}

void Ads1220::escreveRegs(const uint8_t regs[4]) {
  SPI.beginTransaction(_spi);
  digitalWrite(_cs, LOW);
  SPI.transfer(CMD_WREG | 0x03);
  for (int i = 0; i < 4; i++) SPI.transfer(regs[i]);
  digitalWrite(_cs, HIGH);
  SPI.endTransaction();
}

void Ads1220::leRegs(uint8_t regs[4]) {
  SPI.beginTransaction(_spi);
  digitalWrite(_cs, LOW);
  SPI.transfer(CMD_RREG | 0x03);
  for (int i = 0; i < 4; i++) regs[i] = SPI.transfer(0xFF);
  digitalWrite(_cs, HIGH);
  SPI.endTransaction();
}

int32_t Ads1220::leDado() {
  uint8_t b[3] = {0xFF, 0xFF, 0xFF};
  SPI.beginTransaction(_spi);
  digitalWrite(_cs, LOW);
  SPI.transferBytes(b, b, 3);
  digitalWrite(_cs, HIGH);
  SPI.endTransaction();
  int32_t v = ((int32_t)b[0] << 16) | ((int32_t)b[1] << 8) | b[2];
  if (v & 0x800000) v -= 0x1000000;  // complemento de 2, 24 bits
  return v;
}

bool Ads1220::esperaDrdy(uint32_t timeoutMs) {
  uint32_t t0 = millis();
  while (digitalRead(_drdy) == HIGH) {
    if (millis() - t0 > timeoutMs) return false;
  }
  return true;
}

bool Ads1220::iniciar(const uint8_t regs[4]) {
  comando(CMD_RESET);
  delay(5);  // datasheet: ~50 us apos RESET; folga
  escreveRegs(regs);
  uint8_t lido[4];
  leRegs(lido);
  bool ok = memcmp(lido, regs, 4) == 0;
  comando(CMD_START);
  return ok;
}

float Ads1220::medeAvdd(const uint8_t regsNormais[4]) { return medeMonitor(0xD1, regsNormais); }

float Ads1220::medeMonitor(uint8_t reg0Monitor, const uint8_t regsNormais[4]) {
  // Monitores (SBAS501B 8.3.11): MUX 1101 = (AVDD-AVSS)/4 e MUX 1100 = (REFPx-REFNx)/4.
  // O ADS usa sozinho a referencia interna de 2,048 V e desliga o PGA; o REG2 continua
  // selecionando o par REFP0/REFN0 (VREF = 01) para o monitor de referencia.
  escreveReg(0, reg0Monitor);
  comando(CMD_START);
  leDado();  // limpa um DRDY pendente da configuracao anterior
  bool ok = esperaDrdy(60);
  if (ok) leDado();  // descarta a 1a conversao
  int64_t soma = 0;
  int n = 0;
  for (int i = 0; ok && i < 4; i++) {
    if (!esperaDrdy(60)) { ok = false; break; }
    soma += leDado();
    n++;
  }
  escreveReg(0, regsNormais[0]);
  escreveReg(2, regsNormais[2]);
  comando(CMD_START);
  if (ok && esperaDrdy(60)) leDado();  // descarta a 1a conversao apos religar o PGA
  if (!ok || n == 0) return NAN;
  return (float)((double)soma / n / 8388608.0 * 2.048 * 4.0);
}
