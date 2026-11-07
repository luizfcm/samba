"""
SAMBA - cliente BLE de teste (protocolo v2), para validar o firmware sem o app Flutter.

Faz o papel do app: conecta, assina Medicao e Estado, manda comandos, decodifica os pacotes
com as MESMAS regras do PacoteMedicao.decodificar do app (versao 2, count > 0, tamanho
16 + 6*count, delta_us = 0 na 1a e > 0 nas outras) e mede perdas, taxa e jitter.

Instalar:   python -m pip install bleak
Exemplos:
  python samba_ble_cliente.py                         # 10 s de stream, mostra estatisticas
  python samba_ble_cliente.py --tara --segundos 30 --csv salto.csv
  python samba_ble_cliente.py --tara --segundos 20 --ao-vivo --csv coleta.csv   # grafico ao vivo
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
    if versao != 2:
        raise ValueError("Estado com versao %d (esperado 2)" % versao)
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
        self.chegadas = []  # por pacote: (instante no PC em s, timestamp da ultima amostra em us, bytes)
        self.mtu = getattr(self, "mtu", None)

    def zera(self):
        est, mtu = self.estado, self.mtu
        self.__init__()
        self.estado, self.mtu = est, mtu

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
        self.chegadas.append((agora, amostras[-1][1], len(dados)))

    def on_estado(self, _, dados: bytearray):
        try:
            self.estado = decodifica_estado(bytes(dados))
            mostra_estado(self.estado)
        except ValueError as e:
            print("[ERRO] %s" % e)

    def media_valor(self, ultimas: int):
        v = [a[2] for a in self.amostras[-ultimas:]]
        return sum(v) / len(v) if v else None

    def janela_calibracao(self, inicio: int, minimo: int = 1000):
        fatia = self.amostras[inicio:]
        if len(fatia) < minimo:
            return None, "poucas amostras recebidas (%d < %d); confira o MTU e a conexao" % (len(fatia), minimo)
        ruins = [a[3] for a in fatia if a[3] & ((1 << 0) | (1 << 3))]  # SATURACAO ou ERRO_ADC
        if ruins:
            return None, "saturacao ou erro no ADC durante a coleta (%s)" % nomes_status(ruins[0])
        vals = [a[2] for a in fatia[-1500:]]
        return sum(vals) / len(vals), None

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
        self.relatorio_ble()

    def relatorio_ble(self):
        """Desempenho do enlace: o que mostra que a transmissao em lotes esta otimizada."""
        c = self.chegadas
        if len(c) < 3:
            return
        dur = c[-1][0] - c[0][0]
        if dur <= 0:
            return
        n_amostras = len(self.amostras)
        bytes_tot = sum(x[2] for x in c)
        media_cont = n_amostras / len(c)
        ints = sorted((c[i + 1][0] - c[i][0]) * 1000 for i in range(len(c) - 1))
        p95 = ints[int(0.95 * (len(ints) - 1))]
        # atraso relativo: (chegada no PC) - (instante da ultima amostra no ESP), descontado o menor valor.
        # Mostra quanto cada pacote esperou a mais que o pacote mais rapido (fila + intervalo de conexao).
        t0_pc, t0_esp = c[0][0], c[0][1] / 1e6
        atrasos = sorted((x[0] - t0_pc) - (x[1] / 1e6 - t0_esp) for x in c)
        base = atrasos[0]
        atr = [(v - base) * 1000 for v in atrasos]
        util = 6 * n_amostras
        print("\n----- Desempenho do BLE -----")
        print("MTU negociado: %s | %.1f amostras por notificacao (maximo 20)" % (self.mtu, media_cont))
        print("notificacoes por segundo: %.1f (sem lotes seriam %.0f, uma por amostra)"
              % (len(c) / dur, n_amostras / dur))
        print("vazao: %.2f kB/s de payload (%.2f kB/s so de amostras) | eficiencia do pacote %.1f %%"
              % (bytes_tot / dur / 1000, util / dur / 1000, 100.0 * util / bytes_tot))
        print("intervalo entre notificacoes no PC: medio %.1f ms, 95%% abaixo de %.1f ms, maximo %.1f ms"
              % (sum(ints) / len(ints), p95, ints[-1]))
        print("atraso extra por pacote (em relacao ao mais rapido): mediana %.1f ms, 95%% abaixo de %.1f ms, max %.1f ms"
              % (atr[len(atr) // 2], atr[int(0.95 * (len(atr) - 1))], atr[-1]))


MVV_POR_CONTAGEM = 1000.0 / (8388608 * 128)  # ganho 128, medicao ratiometrica


def para_mvv(amostra, fator):
    """mV/V da ponte a partir de uma amostra (seq, t_us, valor, status).
    Modo bruto: contagens do ADC. Normal: mN -> contagens pelo fator do Estado (tara ja descontada)."""
    _, _, valor, status = amostra
    if status & (1 << 4):
        return valor * MVV_POR_CONTAGEM
    if not fator:
        return float("nan")
    # |fator|: se a calibracao inverteu o sinal (fator < 0), o grafico segue o sinal ja corrigido, igual ao firmware
    return valor / abs(fator) * MVV_POR_CONTAGEM


async def ao_vivo(col, segundos, janela=5.0):
    """Grafico em tempo real das amostras que chegam pelo BLE."""
    import matplotlib.pyplot as plt
    plt.ion()
    fig, ax = plt.subplots(figsize=(10, 4.5))
    linha, = ax.plot([], [], lw=0.8, color="#1f5fa8")
    ax.set_xlim(-janela, 0)
    ax.set_xlabel("tempo (s)")
    ax.set_ylabel("saida da ponte (mV/V)")
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fim = time.perf_counter() + segundos
    n_janela = int(janela * 1100)
    while time.perf_counter() < fim and plt.fignum_exists(fig.number):
        a = col.amostras[-n_janela:]
        if len(a) > 1:
            fator = col.estado["fator"] if col.estado else None
            t_ult = a[-1][1]
            x = [(s[1] - t_ult) / 1e6 for s in a]
            y = [para_mvv(s, fator) for s in a]
            linha.set_data(x, y)
            lo, hi = min(y), max(y)
            meio, meia = (lo + hi) / 2, max((hi - lo) / 2 * 1.15, 0.002)  # escala minima: o ruido nao parece enorme
            ax.set_ylim(meio - meia, meio + meia)
            ax.set_title("SAMBA via BLE | %d amostras | %d pacotes | %d perdidas | MTU %s"
                         % (len(col.amostras), col.pacotes, col.perdidas, col.mtu))
            fig.canvas.draw_idle()
        fig.canvas.flush_events()
        await asyncio.sleep(0.05)  # devolve o controle ao bleak para receber as notificacoes
    restante = fim - time.perf_counter()
    if restante > 0:  # janela fechada antes do fim: continua coletando sem grafico
        await asyncio.sleep(restante)
    return fig


async def progresso(col, segundos):
    """Uma linha por segundo durante a coleta: mostra na hora se os pacotes estao chegando."""
    inicio = time.perf_counter()
    fim = inicio + segundos
    ant = 0
    while time.perf_counter() < fim:
        await asyncio.sleep(min(1.0, max(0.0, fim - time.perf_counter())))
        n = len(col.amostras)
        print("  %5.1f s | %6d amostras (+%4d/s) | %5d pacotes | perdidas %d | erros de formato %d"
              % (time.perf_counter() - inicio, n, n - ant, col.pacotes, col.perdidas, col.erros))
        ant = n


async def comando(cliente, *dados, rotulo="", tentativas=5):
    """Escreve no Controle. Se a placa responder com erro (ex.: 0x11 Insufficient Resource quando o
    radio esta congestionado), tenta de novo; na ultima, usa escrita sem resposta. Retorna True/False."""
    ultimo_erro = None
    for i in range(tentativas):
        try:
            await cliente.write_gatt_char(UUID_CONTROLE, bytes(dados), response=(i < tentativas - 1))
            if rotulo:
                print("-> %s%s" % (rotulo, "" if i == 0 else " (na tentativa %d)" % (i + 1)))
            return True
        except Exception as e:  # BleakGATTProtocolError, BleakError...
            ultimo_erro = e
            await asyncio.sleep(0.2)
    print("AVISO: comando %s falhou %d vezes: %s" % (rotulo or bytes(dados).hex(), tentativas, ultimo_erro))
    return False


async def entrada(msg):
    return await asyncio.get_running_loop().run_in_executor(None, input, msg)


async def principal(args):
    print("Procurando o SAMBA...")
    def filtro_samba(d, ad):
        uuids = [u.lower() for u in (ad.service_uuids or [])]
        if ad.local_name == args.nome or d.name == args.nome:
            return True
        return args.nome == "SAMBA" and UUID_SERVICO in uuids

    dispositivo = await BleakScanner.find_device_by_filter(filtro_samba, timeout=15.0)
    if dispositivo is None:
        print("Nao encontrado. O firmware esta rodando? O celular nao esta conectado nele?")
        return 1
    print("Encontrado: %s %s" % (dispositivo.name, dispositivo.address))

    col = Coletor()
    async with BleakClient(dispositivo) as cli:
        print("Conectado. MTU = %d (precisa de >= 139 para 20 amostras/pacote)" % cli.mtu_size)
        col.mtu = cli.mtu_size
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
            fig = None
            try:
                if args.ao_vivo:
                    fig = await ao_vivo(col, args.segundos)
                else:
                    await progresso(col, args.segundos)
            finally:
                await comando(cli, OP_STOP, rotulo="STOP")  # mesmo se o grafico der erro ou Ctrl+C
            await asyncio.sleep(0.5)  # recebe o ultimo pacote
            if args.bruto:
                await comando(cli, OP_MODO_BRUTO, 0)
            col.relatorio()
            if args.csv:
                with open(args.csv, "w", newline="") as fp:
                    w = csv.writer(fp)
                    w.writerow(["sequencia", "timestamp_us", "valor", "status", "mV_por_V"])
                    fator = col.estado["fator"] if col.estado else None
                    for s in col.amostras:
                        w.writerow(list(s) + ["%.7f" % para_mvv(s, fator)])
                print("CSV gravado: %s (valor em mN, ou contagens se o bit 4 do status estiver ligado; "
                      "mV_por_V = saida da ponte)" % args.csv)
            if fig is not None:
                import matplotlib.pyplot as plt
                if plt.fignum_exists(fig.number):
                    print("Feche a janela do grafico para terminar.")
                    plt.ioff()
                    plt.show()
    return 0


async def calibra(cli, col, kg):
    """O mesmo fluxo que o app pode usar: modo bruto, media sem carga, media com massa, SET_CALIBRACAO."""
    print("\n== Calibracao com %.3f kg ==" % kg)
    await comando(cli, OP_MODO_BRUTO, 1)
    col.zera()
    await comando(cli, OP_START)
    await entrada("Deixe a celula SEM carga e tecle Enter...")
    i0 = len(col.amostras)
    await asyncio.sleep(2.0)
    zero, erro_zero = col.janela_calibracao(i0)
    if erro_zero:
        await comando(cli, OP_STOP)
        await comando(cli, OP_MODO_BRUTO, 0)
        print("ERRO na leitura sem carga: %s" % erro_zero)
        return
    await entrada("Coloque %.3f kg, espere parar de balancar e tecle Enter..." % kg)
    i1 = len(col.amostras)
    await asyncio.sleep(2.0)
    carga, erro_carga = col.janela_calibracao(i1)
    await comando(cli, OP_STOP)
    await comando(cli, OP_MODO_BRUTO, 0)
    if erro_carga:
        print("ERRO na leitura com carga: %s" % erro_carga)
        return
    if abs(carga - zero) < 100:
        print("ERRO: a leitura nao mudou o suficiente (zero=%.1f, carga=%.1f)." % (zero, carga))
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
    p.add_argument("--ao-vivo", action="store_true",
                   help="grafico em tempo real (mV/V) durante a coleta; precisa de matplotlib")
    p.add_argument("--cal", nargs=2, type=float, metavar=("FATOR", "DESLOCAMENTO"), help="SET_CALIBRACAO")
    p.add_argument("--calibrar-kg", type=float, help="calibra com massa conhecida (interativo)")
    return p.parse_args()


if __name__ == "__main__":
    sys.exit(asyncio.run(principal(argumentos())))
