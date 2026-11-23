// Projeto SAMBA - medicao de bateria com o INA226 (dossie INA226 de 18/11/2026).
// Driver do INA226, estimativa de carga e formato da caracteristica BLE Bateria.
// Nada aqui usa o Wire sozinho: quem chama (samba_firmware.ino) garante que o I2C so e usado no loop().
#pragma once
#include <Arduino.h>
#include <Wire.h>

// ---------- INA226 (datasheet TI SBOS547) ----------
namespace ina {
constexpr uint8_t ENDERECO = 0x40;  // A0 = A1 = GND
constexpr uint8_t REG_CONFIG = 0x00, REG_SHUNT = 0x01, REG_BUS = 0x02, REG_POTENCIA = 0x03,
                  REG_CORRENTE = 0x04, REG_CAL = 0x05, REG_MASCARA = 0x06,
                  REG_FABRICANTE = 0xFE, REG_CHIP = 0xFF;
constexpr uint16_t ID_FABRICANTE = 0x5449, ID_CHIP = 0x2260;
// AVG = 512, VBUSCT = VSHCT = 1,1 ms, continuo: uma media nova a cada 512 x 2,2 ms = 1,126 s
constexpr uint16_t CONFIG = 0x4D27;
constexpr float T_CONVERSAO_S = 512 * 2.2e-3f;
constexpr float CURRENT_LSB_A = 25e-6f;  // CAL 2048 com shunt de 0,100 ohm (fundo de escala 0,82 A)
constexpr uint16_t CAL_PADRAO = 2048;
constexpr uint16_t MASK_CVRF = 1u << 3;  // conversao pronta (zera ao ler o registrador 0x06)
constexpr uint16_t MASK_OVF = 1u << 2;   // estouro no calculo de corrente/potencia
}  // namespace ina

struct LeituraIna {
  float vBus_V, vShunt_V, corrente_A, potencia_W;
  bool estouro;
};

class Ina226 {
 public:
  bool inicia(TwoWire &w, uint16_t cal) {
    _w = &w;
    uint16_t fab = 0, chip = 0, cfg = 0, c = 0;
    if (!leReg(ina::REG_FABRICANTE, fab) || !leReg(ina::REG_CHIP, chip)) return false;
    if (fab != ina::ID_FABRICANTE || chip != ina::ID_CHIP) return false;
    if (!escreve(ina::REG_CONFIG, ina::CONFIG) || !escreve(ina::REG_CAL, cal)) return false;
    if (!leReg(ina::REG_CONFIG, cfg) || !leReg(ina::REG_CAL, c)) return false;
    _cal = cal;
    return cfg == ina::CONFIG && c == cal;
  }
  // true quando ha uma media nova; tambem devolve a flag de estouro.
  // A leitura do registrador 0x06 zera o CVRF: so esta funcao pode le-lo.
  bool novaConversao(bool &estouro, bool &falhou) {
    uint16_t m = 0;
    falhou = !leReg(ina::REG_MASCARA, m);
    estouro = m & ina::MASK_OVF;
    return !falhou && (m & ina::MASK_CVRF);
  }
  bool le(LeituraIna &l) {
    uint16_t vb, vs, cr, pw;
    if (!leReg(ina::REG_BUS, vb) || !leReg(ina::REG_SHUNT, vs) || !leReg(ina::REG_CORRENTE, cr) ||
        !leReg(ina::REG_POTENCIA, pw))
      return false;
    l.vBus_V = vb * 1.25e-3f;                         // 1,25 mV/bit
    l.vShunt_V = (int16_t)vs * 2.5e-6f;               // 2,5 uV/bit
    l.corrente_A = (int16_t)cr * ina::CURRENT_LSB_A;  // ja inclui o ajuste fino da CAL
    l.potencia_W = pw * 25.0f * ina::CURRENT_LSB_A;   // Power_LSB = 25 x Current_LSB
    l.estouro = false;
    return true;
  }
  bool gravaCal(uint16_t cal) {
    if (!escreve(ina::REG_CAL, cal)) return false;
    _cal = cal;
    return true;
  }
  uint16_t cal() const { return _cal; }

 private:
  bool escreve(uint8_t reg, uint16_t v) {
    _w->beginTransmission(ina::ENDERECO);
    _w->write(reg);
    _w->write(v >> 8);  // MSB primeiro
    _w->write(v & 0xFF);
    return _w->endTransmission() == 0;
  }
  bool leReg(uint8_t reg, uint16_t &v) {
    _w->beginTransmission(ina::ENDERECO);
    _w->write(reg);
    if (_w->endTransmission(false) != 0) return false;
    if (_w->requestFrom((int)ina::ENDERECO, 2) != 2) return false;
    v = (uint16_t)_w->read() << 8;
    v |= _w->read();
    return true;
  }
  TwoWire *_w = nullptr;
  uint16_t _cal = ina::CAL_PADRAO;
};

// ---------- Estado de carga (pack 3S, celulas 18650 de 2450 mAh) ----------
namespace bat {
constexpr float CAPACIDADE_NOMINAL_MAH = 2450.0f;
constexpr float CAPACIDADE_UTIL_INICIAL_MAH = 2205.0f;  // 90 % ate 9,6 V; substituida pela medida
constexpr float V_CHEIA = 12.45f;           // 4,15 V/celula: marca 100 % ao ligar
constexpr float V_FRACA = 10.20f;           // 3,40 V/celula: aviso
constexpr float V_FRACA_SAI = 10.40f;       // histerese do aviso
constexpr float V_CRITICA = 9.60f;          // 3,20 V/celula: desligamento controlado
constexpr float V_SEM_BATERIA = 6.0f;       // abaixo disso: chave aberta e placa no USB
constexpr float DIFERENCA_MAX_PCT = 15.0f;  // tensao x contador ao ligar
}  // namespace bat

// Tensao de repouso por celula -> % (tabela tipica de Li-ion 18650; refinar com descarga real)
inline float socPorTensao(float vPack) {
  static const float V[] = {3.20f, 3.50f, 3.62f, 3.70f, 3.75f, 3.79f, 3.82f, 3.87f, 3.92f, 3.98f, 4.06f, 4.15f};
  static const float P[] = {0.0f, 5.0f, 10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f, 90.0f, 100.0f};
  const int n = sizeof(V) / sizeof(V[0]);
  float v = vPack / 3.0f;
  if (v <= V[0]) return 0.0f;
  if (v >= V[n - 1]) return 100.0f;
  for (int i = 1; i < n; i++)
    if (v < V[i]) return P[i - 1] + (P[i] - P[i - 1]) * (v - V[i - 1]) / (V[i] - V[i - 1]);
  return 100.0f;
}

// ---------- Caracteristica Bateria (1d770005-..., READ + NOTIFY, 13 bytes, little-endian) ----------
constexpr uint8_t BAT_VERSAO = 1;
constexpr uint8_t BAT_INA_OK = 1u << 0, BAT_SOC_PELA_TENSAO = 1u << 1, BAT_FRACA = 1u << 2,
                  BAT_CRITICA = 1u << 3, BAT_SEM_BATERIA = 1u << 4, BAT_ESTOURO = 1u << 5;
constexpr size_t BATERIA_BYTES = 13;

inline void montaBateria(uint8_t out[BATERIA_BYTES], uint8_t flags, uint16_t tensao_mV, int16_t corrente_dmA,
                         uint16_t potencia_mW, uint8_t soc_pct, uint16_t autonomia_min, uint16_t consumido_mAh) {
  auto w16 = [](uint8_t *p, uint16_t v) { p[0] = v & 0xFF; p[1] = v >> 8; };
  out[0] = BAT_VERSAO;
  out[1] = flags;
  w16(out + 2, tensao_mV);
  w16(out + 4, (uint16_t)corrente_dmA);  // 0,1 mA por unidade
  w16(out + 6, potencia_mW);
  out[8] = soc_pct;                      // 255 = desconhecido
  w16(out + 9, autonomia_min);           // 65535 = desconhecido
  w16(out + 11, consumido_mAh);
}
