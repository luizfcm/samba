// Driver minimo do ADS1220 (TI SBAS501B) para o SAMBA.
// Todas as funcoes usam o SPI e devem ser chamadas SO pela tarefa de aquisicao.
#pragma once
#include <Arduino.h>
#include <SPI.h>

class Ads1220 {
 public:
  void begin(int sclk, int miso, int mosi, int cs, int drdy, uint32_t spiHz);
  // RESET + escreve os 4 registradores + confere + START. Retorna true se a leitura de volta bateu.
  bool iniciar(const uint8_t regs[4]);
  void comando(uint8_t cmd);
  void escreveReg(uint8_t reg, uint8_t valor);
  void escreveRegs(const uint8_t regs[4]);
  void leRegs(uint8_t regs[4]);
  int32_t leDado();                   // 24 bits com sinal, sem esperar o DRDY
  bool esperaDrdy(uint32_t timeoutMs);  // espera o pino DRDY descer (polling)
  // Mede AVDD (monitor MUX=1101) em volts com referencia interna e restaura a configuracao.
  // Interrompe a conversao continua por ~8 ms. Retorna NAN se o DRDY nao responder.
  float medeAvdd(const uint8_t regsNormais[4]);
  // Mesmo procedimento para qualquer monitor: 0xD1 = AVDD, 0xC1 = REFP0-REFN0. Resultado em volts.
  float medeMonitor(uint8_t reg0Monitor, const uint8_t regsNormais[4]);

  static constexpr uint8_t CMD_RESET = 0x06;
  static constexpr uint8_t CMD_START = 0x08;
  static constexpr uint8_t CMD_RREG  = 0x20;
  static constexpr uint8_t CMD_WREG  = 0x40;

 private:
  int _cs = -1, _drdy = -1;
  SPISettings _spi;
};
