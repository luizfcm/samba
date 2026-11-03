"""
SAMBA - cliente BLE de teste (protocolo v2), para validar o firmware sem o app Flutter.

Faz o papel do app: conecta, assina Medicao e Estado, manda comandos, decodifica os pacotes
com as MESMAS regras do PacoteMedicao.decodificar do app (versao 2, count > 0, tamanho
16 + 6*count, delta_us = 0 na 1a e > 0 nas outras) e mede perdas, taxa e jitter.

Instalar:   python -m pip install bleak
Exemplos:
  python samba_ble_cliente.py                         # 10 s de stream, mostra estatisticas
  python samba_ble_cliente.py --tara --segundos 30 --csv salto.csv
  python samba_ble_cliente.py --bruto --segundos 5    # contagens cruas do ADC
  python samba_ble_cliente.py --calibrar-kg 20        # tara + massa conhecida -> SET_CALIBRACAO
  python samba_ble_cliente.py --cal 9.133 -12345 --segundos 0   # grava calibracao e sai
"""

import argparse
import asyncio
import csv
import struct
import sys
import time

from bleak import BleakClient, BleakScanner

UUID_SERVICO = "1d770001-fc8b-4e8e-aa34-c86e1b9eeaf5"
UUID_MEDICAO = "1d770002-fc8b-4e8e-aa34-c86e1b9eeaf5"
UUID_CONTROLE = "1d770003-fc8b-4e8e-aa34-c86e1b9eeaf5"
UUID_ESTADO = "1d770004-fc8b-4e8e-aa34-c86e1b9eeaf5"

OP_START, OP_STOP, OP_TARE, OP_MODO_BRUTO, OP_SET_CAL = 1, 2, 3, 4, 5
G = 9.80665
BITS = ["SATURACAO", "TARA", "SEM_CAL", "ERRO_ADC", "MODO_BRUTO", "AQUISICAO"]


def nomes_status(st: int) -> str:
    n = [b for i, b in enumerate(BITS) if st & (1 << i)]
    return "0x%04X %s" % (st, "|".join(n) if n else "-")


def decodifica_pacote(dados: bytes):
    """Espelho do PacoteMedicao.decodificar (app). Lanca ValueError onde o app lanca FormatException."""
    if len(dados) < 16:
        raise ValueError("pacote com %d bytes (< 16)" % len(dados))
    versao, count, status, seq, t0 = struct.unpack_from("<BBHIQ", dados, 0)
    if versao != 2:
        raise ValueError("versao %d" % versao)
    if count == 0:
        raise ValueError("count = 0")
    if len(dados) != 16 + 6 * count:
        raise ValueError("tamanho %d, esperado %d" % (len(dados), 16 + 6 * count))
    amostras = []
    t = t0
    for i in range(count):
        valor, delta = struct.unpack_from("<iH", dados, 16 + 6 * i)
        if i == 0 and delta != 0:
            raise ValueError("delta_us != 0 na 1a amostra")
        if i > 0 and delta == 0:
            raise ValueError("delta_us = 0 na amostra %d" % i)
        t += delta
        amostras.append((seq + i, t, valor, status))
    return amostras


def decodifica_estado(dados: bytes):
    if len(dados) != 13:
        raise ValueError("Estado com %d bytes (esperado 13)" % len(dados))
    versao, status, taxa, fator, desloc = struct.unpack("<BHHfi", dados)
    return {"versao": versao, "status": status, "taxa": taxa, "fator": fator, "desloc": desloc}


def mostra_estado(e, prefixo="[Estado]"):
    print("%s v%d %s | %d Hz | fator %.7f mN/cont | deslocamento %d"
          % (prefixo, e["versao"], nomes_status(e["status"]), e["taxa"], e["fator"], e["desloc"]))


class Coletor:
    def __init__(self):
        self.amostras = []
        self.pacotes = 0
        self.erros = 0
        self.saltos = 0
        self.perdidas = 0
        self.ultimo_seq = None
        self.tamanhos = {}
        self.t_primeiro_pc = None
        self.estado = None

    def zera(self):
        self.__init__()

    def on_medicao(self, _, dados: bytearray):
        agora = time.perf_counter()
        try:
            amostras = decodifica_pacote(bytes(dados))
        except ValueError as e:
            self.erros += 1
            print("[ERRO de formato] %s | %s" % (e, bytes(dados[:20]).hex()))
            return
        if self.t_primeiro_pc is None:
            self.t_primeiro_pc = agora
        self.pacotes += 1
        self.tamanhos[len(amostras)] = self.tamanhos.get(len(amostras), 0) + 1
        primeiro = amostras[0][0]
        if self.ultimo_seq is not None and primeiro != self.ultimo_seq + 1:
            self.saltos += 1
            self.perdidas += max(0, primeiro - self.ultimo_seq - 1)
        self.ultimo_seq = amostras[-1][0]
        self.amostras.extend(amostras)

    def on_estado(self, _, dados: bytearray):
        try:
            self.estado = decodifica_estado(bytes(dados))
            mostra_estado(self.estado)
        except ValueError as e:
            print("[ERRO] %s" % e)

    def media_valor(self, ultimas: int):
        v = [a[2] for a in self.amostras[-ultimas:]]
        return sum(v) / len(v) if v else None

    def relatorio(self):
        a = self.amostras
        print("\n===== Relatorio =====")
        print("pacotes %d | amostras %d | erros de formato %d | saltos de sequencia %d (%d amostras perdidas)"
              % (self.pacotes, len(a), self.erros, self.saltos, self.perdidas))
        print("amostras por pacote: %s" % dict(sorted(self.tamanhos.items())))
        if len(a) < 2:
            return
        if a[0][0] != 0:
            print("ATENCAO: a 1a amostra apos START tem sequencia %d (protocolo: 0)" % a[0][0])
        if a[0][1] != 0:
            print("ATENCAO: a 1a amostra apos START tem timestamp %d us (protocolo: 0)" % a[0][1])
        dts = [a[i + 1][1] - a[i][1] for i in range(len(a) - 1) if a[i + 1][0] == a[i][0] + 1]
        if dts:
            dur = (a[-1][1] - a[0][1]) / 1e6
            taxa = (a[-1][0] - a[0][0]) / dur if dur > 0 else 0
            print("taxa pelo relogio do ESP: %.2f Hz | dt min %d us, medio %.1f us, max %d us"
                  % (taxa, min(dts), sum(dts) / len(dts), max(dts)))
        vals = [x[2] for x in a]
        m = sum(vals) / len(vals)
        dp = (sum((v - m) ** 2 for v in vals) / (len(vals) - 1)) ** 0.5
        bruto = a[-1][3] & (1 << 4)
        un = "contagens" if bruto else "mN"
        print("valor: media %.1f %s, desvio padrao %.1f %s, min %d, max %d" % (m, un, dp, un, min(vals), max(vals)))
        if not bruto:
            print("       = media %.3f N (%.3f kg), ruido %.3f N" % (m / 1000, m / 1000 / G, dp / 1000))
        sts = sorted({x[3] for x in a})
        print("status vistos: %s" % ", ".join(nomes_status(s) for s in sts))


async def comando(cliente, *dados, rotulo=""):
    await cliente.write_gatt_char(UUID_CONTROLE, bytes(dados), response=True)
    if rotulo:
        print("-> %s" % rotulo)


async def entrada(msg):
    return await asyncio.get_running_loop().run_in_executor(None, input, msg)


async def principal(args):
    print("Procurando o SAMBA...")
    dispositivo = await BleakScanner.find_device_by_filter(
        lambda d, ad: (d.name or ad.local_name or "") == args.nome or UUID_SERVICO in [u.lower() for u in ad.service_uuids],
        timeout=15.0)
    if dispositivo is None:
        print("Nao encontrado. O firmware esta rodando? O celular nao esta conectado nele?")
        return 1
    print("Encontrado: %s %s" % (dispositivo.name, dispositivo.address))

    col = Coletor()
    async with BleakClient(dispositivo) as cli:
        print("Conectado. MTU = %d (precisa de >= 139 para 20 amostras/pacote)" % cli.mtu_size)
        col.estado = decodifica_estado(bytes(await cli.read_gatt_char(UUID_ESTADO)))
        mostra_estado(col.estado, "[Estado lido]")
        await cli.start_notify(UUID_ESTADO, col.on_estado)
        await cli.start_notify(UUID_MEDICAO, col.on_medicao)

        if args.cal is not None:
            f, d = args.cal
            await comando(cli, OP_SET_CAL, *struct.pack("<fi", f, int(d)), rotulo="SET_CALIBRACAO %.7f %d" % (f, d))
            await asyncio.sleep(0.5)

        if args.calibrar_kg:
            await calibra(cli, col, args.calibrar_kg)
            await asyncio.sleep(0.5)

        if args.segundos > 0:
            await comando(cli, OP_MODO_BRUTO, 1 if args.bruto else 0, rotulo="MODO_BRUTO %d" % args.bruto)
            if args.tara:
                await comando(cli, OP_TARE, rotulo="TARE (1 s, celula parada)")
                await asyncio.sleep(1.5)
            col.zera()
            await comando(cli, OP_START, rotulo="START (%g s)" % args.segundos)
            await asyncio.sleep(args.segundos)
            await comando(cli, OP_STOP, rotulo="STOP")
            await asyncio.sleep(0.5)  # recebe o ultimo pacote
            if args.bruto:
                await comando(cli, OP_MODO_BRUTO, 0)
            col.relatorio()
            if args.csv:
                with open(args.csv, "w", newline="") as fp:
                    w = csv.writer(fp)
                    w.writerow(["sequencia", "timestamp_us", "valor", "status"])
                    w.writerows(col.amostras)
                print("CSV gravado: %s (valor em mN, ou contagens se o bit 4 do status estiver ligado)" % args.csv)
    return 0


async def calibra(cli, col, kg):
    """O mesmo fluxo que o app pode usar: modo bruto, media sem carga, media com massa, SET_CALIBRACAO."""
    print("\n== Calibracao com %.3f kg ==" % kg)
    await comando(cli, OP_MODO_BRUTO, 1)
    col.zera()
    await comando(cli, OP_START)
    await entrada("Deixe a celula SEM carga e tecle Enter...")
    await asyncio.sleep(2.0)
    zero = col.media_valor(1500)
    await entrada("Coloque %.3f kg, espere parar de balancar e tecle Enter..." % kg)
    await asyncio.sleep(2.0)
    carga = col.media_valor(1500)
    await comando(cli, OP_STOP)
    await comando(cli, OP_MODO_BRUTO, 0)
    if zero is None or carga is None or abs(carga - zero) < 100:
        print("ERRO: a leitura nao mudou o suficiente (zero=%s, carga=%s)." % (zero, carga))
        return
    fator = kg * G * 1000.0 / (carga - zero)
    desloc = int(round(zero))
    print("zero = %.1f contagens, carga = %.1f contagens -> fator %.7f mN/contagem" % (zero, carga, fator))
    await comando(cli, OP_SET_CAL, *struct.pack("<fi", fator, desloc), rotulo="SET_CALIBRACAO gravado")


def argumentos():
    p = argparse.ArgumentParser(description="Cliente BLE de teste do SAMBA (protocolo v2)")
    p.add_argument("--nome", default="SAMBA")
    p.add_argument("--segundos", type=float, default=10.0, help="duracao do stream (0 = nao faz stream)")
    p.add_argument("--tara", action="store_true", help="manda TARE antes do START")
    p.add_argument("--bruto", type=int, choices=[0, 1], default=0, nargs="?", const=1, help="modo bruto")
    p.add_argument("--csv", help="arquivo CSV de saida")
    p.add_argument("--cal", nargs=2, type=float, metavar=("FATOR", "DESLOCAMENTO"), help="SET_CALIBRACAO")
    p.add_argument("--calibrar-kg", type=float, help="calibra com massa conhecida (interativo)")
    return p.parse_args()


if __name__ == "__main__":
    sys.exit(asyncio.run(principal(argumentos())))
