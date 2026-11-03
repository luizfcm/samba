// Protocolo BLE versao 2 (protocolo_ble_v2.md): formatos binarios, little-endian.
#pragma once
#include <Arduino.h>
#include <string.h>

constexpr uint8_t PROTOCOLO_VERSAO = 2;

// ---------- Bits de status ----------
constexpr uint16_t ST_SATURACAO  = 1u << 0;
constexpr uint16_t ST_TARA       = 1u << 1;
constexpr uint16_t ST_SEM_CAL    = 1u << 2;
constexpr uint16_t ST_ERRO_ADC   = 1u << 3;
constexpr uint16_t ST_MODO_BRUTO = 1u << 4;
constexpr uint16_t ST_AQUISICAO  = 1u << 5;

// ---------- Opcodes da caracteristica Controle ----------
constexpr uint8_t OP_START          = 0x01;
constexpr uint8_t OP_STOP           = 0x02;
constexpr uint8_t OP_TARE           = 0x03;
constexpr uint8_t OP_MODO_BRUTO     = 0x04;
constexpr uint8_t OP_SET_CALIBRACAO = 0x05;
// Uso interno (Monitor Serial), nunca chega pelo BLE:
constexpr uint8_t OP_INT_CALKG      = 0x80;  // calibra com massa conhecida
constexpr uint8_t OP_INT_LIMPA_CAL  = 0x81;  // volta ao fator nominal

struct Comando {
  uint8_t op;
  uint8_t u8;
  float f;
  int32_t i32;
};

// Amostra produzida pela tarefa de aquisicao (ja convertida)
struct Amostra {
  uint64_t t_us;    // relativo ao START
  uint32_t seq;     // indice da amostra desde o START
  int32_t valor;    // mN, ou contagens do ADC no modo bruto
  uint16_t status;
  uint16_t sessao;  // muda a cada START: separa amostras de sessoes diferentes
};

// ---------- Escrita little-endian ----------
inline void le16(uint8_t *p, uint16_t v) { p[0] = v; p[1] = v >> 8; }
inline void le32(uint8_t *p, uint32_t v) { for (int i = 0; i < 4; i++) p[i] = v >> (8 * i); }
inline void le64(uint8_t *p, uint64_t v) { for (int i = 0; i < 8; i++) p[i] = v >> (8 * i); }

constexpr size_t PACOTE_CABECALHO = 16;
constexpr size_t PACOTE_BLOCO = 6;
constexpr size_t PACOTE_MAX_AMOSTRAS = 20;
constexpr size_t PACOTE_MAX_BYTES = PACOTE_CABECALHO + PACOTE_BLOCO * PACOTE_MAX_AMOSTRAS;  // 136

// Quantas amostras cabem numa notificacao com esse MTU (3 bytes vao para o cabecalho ATT)
inline uint8_t amostrasPorMtu(uint16_t mtu, uint8_t maximo) {
  if (mtu < 3 + PACOTE_CABECALHO + PACOTE_BLOCO) return 0;
  size_t n = (mtu - 3 - PACOTE_CABECALHO) / PACOTE_BLOCO;
  return n > maximo ? maximo : (uint8_t)n;
}

// Monta um pacote de medicao. Regras do protocolo garantidas aqui:
//  - amostras consecutivas (seq + i), mesma sessao e mesmo status;
//  - delta_us = 0 na 1a e 1..65535 nas seguintes.
// Quando a proxima amostra nao cabe por qualquer regra, o pacote e fechado e outro comeca.
class MontadorPacote {
 public:
  uint8_t buf[PACOTE_MAX_BYTES];

  void limpa() { _n = 0; }
  uint8_t quantidade() const { return _n; }
  size_t tamanho() const { return PACOTE_CABECALHO + PACOTE_BLOCO * _n; }
  uint16_t sessao() const { return _sessao; }
  uint32_t idadeMs(uint32_t agoraMs) const { return agoraMs - _criadoMs; }

  bool aceita(const Amostra &a, uint8_t maximo) const {
    if (_n == 0) return maximo > 0;
    if (_n >= maximo) return false;
    if (a.sessao != _sessao || a.status != _status) return false;
    if (a.seq != _seqUlt + 1) return false;  // houve perda: o app ve o salto na sequencia
    if (a.t_us <= _tUlt || a.t_us - _tUlt > 65535) return false;
    return true;
  }

  // Chame so depois de aceita() == true
  void adiciona(const Amostra &a, uint32_t agoraMs) {
    uint16_t delta = 0;
    if (_n == 0) {
      buf[0] = PROTOCOLO_VERSAO;
      le16(buf + 2, a.status);
      le32(buf + 4, a.seq);
      le64(buf + 8, a.t_us);
      _sessao = a.sessao;
      _status = a.status;
      _criadoMs = agoraMs;
    } else {
      delta = (uint16_t)(a.t_us - _tUlt);
    }
    uint8_t *b = buf + PACOTE_CABECALHO + PACOTE_BLOCO * _n;
    le32(b, (uint32_t)a.valor);
    le16(b + 4, delta);
    _n++;
    buf[1] = _n;
    _seqUlt = a.seq;
    _tUlt = a.t_us;
  }

 private:
  uint8_t _n = 0;
  uint16_t _status = 0, _sessao = 0;
  uint32_t _seqUlt = 0, _criadoMs = 0;
  uint64_t _tUlt = 0;
};

// Caracteristica Estado: 13 bytes
constexpr size_t ESTADO_BYTES = 13;
inline void montaEstado(uint8_t out[ESTADO_BYTES], uint16_t status, uint16_t taxaHz, float fator, int32_t deslocamento) {
  out[0] = PROTOCOLO_VERSAO;
  le16(out + 1, status);
  le16(out + 3, taxaHz);
  uint32_t f;
  memcpy(&f, &fator, 4);  // IEEE 754, little-endian
  le32(out + 5, f);
  le32(out + 9, (uint32_t)deslocamento);
}
