// Projeto SAMBA - configuracao do firmware (protocolo BLE v2)
// Pinagem conforme a placa soldada (ESP32-S3-DevKitC-1 + ADS1220).
#pragma once
#include <Arduino.h>

#define FIRMWARE_VERSAO "2.0.0"
#define NOME_BLE "SAMBA"  // ate 8 caracteres: o anuncio (31 bytes) leva flags + UUID de 128 bits + nome

// ---------- Pinos (GPIO) ----------
constexpr int PINO_SCLK = 12;  // J1-18
constexpr int PINO_MISO = 13;  // J1-19 <- DOUT
constexpr int PINO_MOSI = 11;  // J1-17 -> DIN
constexpr int PINO_CS   = 10;  // J1-16
constexpr int PINO_DRDY = 14;  // J1-20 (ativo em nivel baixo)
constexpr int PINO_SDA  = 1;   // J3-4, INA226 (I2C, endereco 0x40)
constexpr int PINO_SCL  = 2;   // J3-5, INA226 (I2C)

// ---------- Celula (etiqueta) ----------
// So servem para o fator NOMINAL usado enquanto nao ha calibracao (bit 2 de status ligado).
constexpr float CAPACIDADE_KG      = 2000.0f;
constexpr float SENSIBILIDADE_MV_V = 2.0f;
constexpr float G_PADRAO           = 9.80665f;

// ---------- ADS1220 ----------
constexpr uint32_t SPI_HZ   = 4000000;  // datasheet: SCLK ate ~6,6 MHz. Se o teste 02 ('k 4') falhar, use 1000000
constexpr uint16_t TAXA_HZ  = 1200;     // turbo 1200 SPS: com o oscilador interno do ADS (-2 %) fica > 1000 Hz
constexpr uint8_t  ADS_REG0 = 0x0E;     // AIN0/AIN1, ganho 128, PGA ligado
constexpr uint8_t  ADS_REG1 = 0xB4;     // DR=101 + MODE=10 (turbo) + CM=1 -> 1200 SPS continuo
                                        // (1000 SPS normal = 0xC4 resulta em ~983 Hz, abaixo de 1000)
constexpr uint8_t  ADS_REG2 = 0x40;     // referencia externa REFP0/REFN0 (ratiometrico)
constexpr uint8_t  ADS_REG3 = 0x00;     // DRDY so no pino dedicado
constexpr float    ADS_GANHO = 128.0f;

// ---------- Aquisicao ----------
constexpr uint32_t TARA_AMOSTRAS       = 1200;     // 1 s a 1200 Hz
constexpr uint32_t CALKG_AMOSTRAS      = 2400;     // 2 s (comando serial calkg)
constexpr int32_t  LIMITE_SATURACAO    = 8388000;  // |contagens| >= isso -> bit 0 (fundo de escala = 8388607)
constexpr uint32_t AMOSTRAS_IGUAIS_MAX = 250;      // 250 leituras identicas seguidas = ADC travado (bit 3)
constexpr uint32_t DRDY_TIMEOUT_MS     = 100;      // sem DRDY por 100 ms = erro (bit 3)
constexpr uint32_t REINICIO_ADS_MS     = 1000;     // intervalo entre tentativas de reiniciar o ADS
constexpr float    AVDD_MINIMA_V       = 4.5f;     // abaixo disso: pack desligado / LT3042 sem entrada (bit 3)
constexpr uint32_t MONITOR_AVDD_MS     = 2000;     // checagem de AVDD quando parado (nao interrompe o stream)

// ---------- Transmissao ----------
constexpr uint8_t  AMOSTRAS_POR_PACOTE = 20;    // 16 + 6*20 = 136 bytes -> MTU >= 139
// Fila aquisicao -> BLE: com o enlace abaixo de ~1165 amostras/s as amostras aguardam aqui.
// ESP32-S3 N16R8 com "PSRAM: OPI PSRAM": 60 s na PSRAM; sem PSRAM, 2048 amostras na RAM interna.
constexpr size_t   FILA_AMOSTRAS_PSRAM = (size_t)TAXA_HZ * 60;  // 72 000 amostras x 24 B = ~1,7 MB
constexpr size_t   FILA_AMOSTRAS       = 2048;                  // sem PSRAM
constexpr uint32_t PACOTE_MAX_ESPERA_MS = 60;   // envia pacote incompleto se ficar parado esse tempo
constexpr uint16_t MTU_PREFERIDO       = 247;
constexpr uint32_t ESTADO_INTERVALO_MS = 100;   // notifica Estado no maximo 10x/s
// Pacotes ATT (notificacoes e respostas de escrita) saem do pool msys_1 (12 x 256 B). A Medicao so notifica
// com mais que isto livre no msys_1, para a resposta de um comando (ex.: STOP) nao falhar com ATT 0x11.
constexpr int      RESERVA_BUFFERS_BLE = 4;

// Parametros de conexao pedidos ao celular (unidades de 1,25 ms; timeout em 10 ms).
// 15-30 ms atende as regras do iOS e do Android.
constexpr uint16_t CONN_INT_MIN = 12, CONN_INT_MAX = 24, CONN_LATENCIA = 0, CONN_TIMEOUT = 400;

// ---------- UUIDs (protocolo_ble_v2.md) ----------
#define UUID_SERVICO  "1d770001-fc8b-4e8e-aa34-c86e1b9eeaf5"
#define UUID_MEDICAO  "1d770002-fc8b-4e8e-aa34-c86e1b9eeaf5"
#define UUID_CONTROLE "1d770003-fc8b-4e8e-aa34-c86e1b9eeaf5"
#define UUID_ESTADO   "1d770004-fc8b-4e8e-aa34-c86e1b9eeaf5"
#define UUID_BATERIA  "1d770005-fc8b-4e8e-aa34-c86e1b9eeaf5"  // READ + NOTIFY, 13 bytes, 1 Hz (proposta: dossie INA226)
