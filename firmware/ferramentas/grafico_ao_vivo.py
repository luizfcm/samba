"""
SAMBA - grafico ao vivo da forca recebida por BLE, SEM limite de tempo.

Uso (na pasta ferramentas):
    python grafico_ao_vivo.py                        # tara ao conectar e mostra os ultimos 10 s
    python grafico_ao_vivo.py --janela 20            # mostra os ultimos 20 s
    python grafico_ao_vivo.py --positivo compressao  # se a compressao aparecer para cima

Na janela do grafico:
    t  -> refaz a tara (deixe a celula sem carga)
    q  -> encerra (ou simplesmente feche a janela)

A forca e estimada pelos dados de catalogo da celula (ainda sem calibracao com massas).
Requer: python -m pip install bleak matplotlib numpy

Por que o Bluetooth roda numa thread separada: no Windows, a janela grafica (Qt/Tk) coloca a
thread principal num modo (COM "STA") em que o bleak so recebe as notificacoes quando a janela
processa mensagens. Com Bluetooth e janela na mesma thread, a busca trava ou as leituras chegam
atrasadas e o firmware descarta amostras. Na thread propria, o Bluetooth nunca espera a janela.
"""

import argparse
import asyncio
import collections
import threading
import time

import numpy as np
from bleak import BleakClient, BleakScanner

from samba_ble_cliente import (OP_MODO_BRUTO, OP_START, OP_STOP, OP_TARE, UUID_CONTROLE, UUID_MEDICAO,
                               UUID_SERVICO, decodifica_pacote, pede_intervalo_curto)

G = 9.80665


class Dados:
    """Recebe os pacotes (na thread do Bluetooth) e guarda so a janela visivel (memoria constante)."""

    def __init__(self, janela_s):
        self.trava = threading.Lock()
        self.t = collections.deque(maxlen=int(janela_s * 1300))
        self.kgf = collections.deque(maxlen=int(janela_s * 1300))
        self.pacotes = self.perdidas = self.erros = 0
        self.ultimo_seq = None

    def recebe(self, _, dados):
        try:
            amostras = decodifica_pacote(bytes(dados))
        except ValueError:
            self.erros += 1
            return
        with self.trava:
            seq0 = amostras[0][0]
            if self.ultimo_seq is not None and seq0 > self.ultimo_seq + 1:
                self.perdidas += seq0 - self.ultimo_seq - 1
            self.ultimo_seq = amostras[-1][0]
            self.pacotes += 1
            for _seq, t_us, valor_mN, _st in amostras:
                self.t.append(t_us / 1e6)
                self.kgf.append(valor_mN / 1000.0 / G)

    def limpa(self):
        with self.trava:
            self.t.clear()
            self.kgf.clear()
            self.ultimo_seq = None

    def copia(self):
        with self.trava:
            return (np.fromiter(self.t, float, len(self.t)), np.fromiter(self.kgf, float, len(self.kgf)),
                    self.pacotes, self.perdidas, self.erros)


async def comando(cli, *bytes_cmd):
    # Com o radio congestionado a placa pode nao ter buffer para RESPONDER (erro 0x11), mas o comando
    # chega se for enviado sem pedir resposta ("write without response").
    try:
        await cli.write_gatt_char(UUID_CONTROLE, bytes(bytes_cmd), response=True)
        return True
    except Exception:
        pass
    for _ in range(3):
        try:
            await cli.write_gatt_char(UUID_CONTROLE, bytes(bytes_cmd), response=False)
            return True
        except Exception:
            await asyncio.sleep(0.2)
    return False


class Bluetooth(threading.Thread):
    """Conexao BLE inteira numa thread propria, com o seu proprio laco asyncio."""

    def __init__(self, dados):
        super().__init__(daemon=True)
        self.dados = dados
        self.pronto = threading.Event()
        self.parar = threading.Event()
        self.erro = None
        self.mtu = None
        self.loop = None
        self.cli = None

    def run(self):
        try:
            asyncio.run(self._principal())
        except Exception as e:  # mostra o erro em vez de travar em silencio
            self.erro = "erro no Bluetooth: %s" % e
        finally:
            self.pronto.set()

    async def _principal(self):
        disp = await BleakScanner.find_device_by_filter(
            lambda d, ad: (ad.local_name or d.name) == "SAMBA"
            or UUID_SERVICO in [u.lower() for u in (ad.service_uuids or [])],
            timeout=15.0)
        if disp is None:
            self.erro = ("SAMBA nao encontrado. A chave da placa esta ligada? O Bluetooth do Windows esta ligado? "
                         "Outro programa ou celular esta conectado nela?")
            return
        async with BleakClient(disp) as cli:
            self.cli, self.mtu, self.loop = cli, cli.mtu_size, asyncio.get_running_loop()
            pede_intervalo_curto(cli)  # 15 ms no Windows 11: o dobro de folga no radio
            await cli.start_notify(UUID_MEDICAO, self.dados.recebe)
            await comando(cli, OP_MODO_BRUTO, 0)
            self.pronto.set()
            while not self.parar.is_set() and cli.is_connected:
                await asyncio.sleep(0.1)
            if cli.is_connected:
                await comando(cli, OP_STOP)

    def envia(self, *cmd):
        """Chamado pela janela: executa o comando na thread do Bluetooth e espera terminar."""
        if self.loop is None or self.cli is None:
            return False
        return asyncio.run_coroutine_threadsafe(comando(self.cli, *cmd), self.loop).result(timeout=10)


class Usb(threading.Thread):
    """Plano B sem Bluetooth: le a placa pelo cabo USB (comando 'grafico' do firmware, 100 pontos/s em mV/V).
    Mesma interface da classe Bluetooth, para o resto do programa nao mudar."""

    def __init__(self, dados, porta):
        super().__init__(daemon=True)
        self.dados, self.porta = dados, porta
        self.pronto, self.parar = threading.Event(), threading.Event()
        self.erro, self.mtu, self.cli = None, 0, None
        self.trava_tx = threading.Lock()
        self.ligado = False

    def run(self):
        import serial
        try:
            s = serial.Serial()
            s.port, s.baudrate, s.timeout, s.dtr, s.rts = self.porta, 921600, 0.2, False, False  # sem resetar a ESP
            s.open()
        except Exception as e:
            self.erro = "nao consegui abrir %s: %s (feche o Monitor Serial da Arduino IDE)" % (self.porta, e)
            self.pronto.set()
            return
        self.cli = s
        self.pronto.set()
        n_pontos = 0  # o firmware envia 100 pontos/s: o tempo vem da contagem (a USB entrega em rajadas)
        buf = b""
        while not self.parar.is_set():
            buf += s.read(s.in_waiting or 1)
            while b"\n" in buf:
                linha, buf = buf.split(b"\n", 1)
                linha = linha.strip()
                if linha.startswith(b"mV_V:"):
                    try:
                        mvv = float(linha[5:])
                    except ValueError:
                        continue
                    n_pontos += 1
                    with self.dados.trava:
                        self.dados.t.append(n_pontos / 100.0)
                        self.dados.kgf.append(mvv * 1000.0)  # 0,001 mV/V = 1 kgf (celula de 2000 kgf, 2 mV/V)
                        self.dados.pacotes += 1
        if self.ligado:
            self._escreve("grafico")  # desliga o grafico no firmware
        s.close()

    def _escreve(self, txt):
        with self.trava_tx:
            self.cli.write((txt + "\n").encode())

    def envia(self, op, *_):
        if self.cli is None:
            return False
        if op == OP_TARE:
            self._escreve("tara")
        elif op == OP_START:
            self._escreve("grafico 100")
            self.ligado = True
        elif op == OP_STOP and self.ligado:
            self._escreve("grafico")
            self.ligado = False
        return True


def principal(args):
    dados = Dados(args.janela)
    if args.usb:
        ble = Usb(dados, args.usb)
        meio = "pela USB"
        print("Abrindo %s..." % args.usb)
    else:
        ble = Bluetooth(dados)
        meio = "por Bluetooth"
        print("Procurando o SAMBA...")
    ble.start()
    ble.pronto.wait(timeout=40)
    if ble.erro or ble.cli is None:
        print(ble.erro or "Nao foi possivel conectar.")
        return
    print("Conectado %s. Feche a janela ou aperte q para sair; t refaz a tara." % meio)

    import matplotlib.pyplot as plt  # janela so depois de conectar (o Bluetooth ja esta na outra thread)

    pedidos = []
    fig, ax = plt.subplots(figsize=(11, 5), layout="constrained")
    fig.canvas.manager.set_window_title("SAMBA - forca ao vivo (t = tara, q = sair)")
    cru, = ax.plot([], [], lw=0.5, color="#9aa7b8", alpha=0.6, label="leituras individuais")
    media, = ax.plot([], [], lw=2.4, color="#1f5fa8", label="média de 50 ms (remove a interferência de 60 Hz)")
    ax.axhline(0, color="k", lw=0.6)
    ax.set_xlabel("tempo desde o início (s)")
    ax.set_ylabel("força estimada (kgf)")
    ax.grid(alpha=0.3)
    ax.legend(loc="lower center", fontsize=9)
    acima, abaixo = ("TRAÇÃO", "COMPRESSÃO") if args.positivo == "tracao" else ("COMPRESSÃO", "TRAÇÃO")
    ax.axhspan(0, 1e6, color="#2e8b57", alpha=0.05)
    ax.axhspan(-1e6, 0, color="#d35400", alpha=0.05)
    ax.text(0.01, 0.97, "▲ " + acima, transform=ax.transAxes, ha="left", va="top", fontsize=14, weight="bold",
            color="#2e8b57")
    ax.text(0.01, 0.03, "▼ " + abaixo, transform=ax.transAxes, ha="left", va="bottom", fontsize=14, weight="bold",
            color="#d35400")
    valor = ax.text(0.99, 0.95, "", transform=ax.transAxes, ha="right", va="top", fontsize=22, weight="bold")
    rodape = ax.text(0.5, 0.97, "", transform=ax.transAxes, ha="center", va="top", fontsize=9, color="#444")
    ax.set_xlim(0, args.janela)
    ax.set_ylim(-2.4, 2.4)
    fig.canvas.mpl_connect("key_press_event", lambda e: pedidos.append(e.key))
    plt.show(block=False)

    def tara():
        ax.set_title("Tara: deixe a célula sem carga...")
        plt.pause(0.05)
        ble.envia(OP_STOP)
        ble.envia(OP_TARE)
        plt.pause(1.5)  # a tara leva 1 s no firmware
        dados.limpa()
        ble.envia(OP_START)
        ax.set_title("SAMBA: força recebida %s, ao vivo" % meio)

    fim = time.perf_counter() + args.segundos if args.segundos > 0 else float("inf")
    try:
        if args.sem_tara:
            ble.envia(OP_START)
            ax.set_title("SAMBA: força recebida %s, ao vivo" % meio)
        else:
            tara()
        while plt.fignum_exists(fig.number) and time.perf_counter() < fim:
            if not ble.is_alive():
                ax.set_title("Conexão perdida: feche e rode de novo", color="#c0392b")
            while pedidos:
                k = pedidos.pop(0)
                if k == "q":
                    plt.close(fig)
                elif k == "t":
                    tara()
            if not plt.fignum_exists(fig.number):
                break
            t, y, pacotes, perdidas, erros = dados.copia()
            if len(t) > 60 and t[-1] > t[0]:
                # media de 50 ms: 3 periodos de 60 Hz, anula a interferencia da rede e seus harmonicos
                fs = (len(t) - 1) / (t[-1] - t[0])
                n = max(2, min(len(y), int(round(fs * 0.05))))
                m = np.convolve(y, np.ones(n) / n, mode="valid")
                cru.set_data(t, y)
                media.set_data(t[n - 1:], m)
                esq = max(t[0], t[-1] - args.janela)  # no comeco, nao mostra tempo antes da coleta
                ax.set_xlim(esq, esq + args.janela)
                lim = max(abs(y.min()), abs(y.max()), 2.0) * 1.2  # escala simetrica, minimo de ±2 kgf
                ax.set_ylim(-lim, lim)
                f = m[-1]
                if abs(f) < 0.5:
                    valor.set_text("em repouso")
                    valor.set_color("#444")
                else:
                    valor.set_text(("%s  %.1f kgf" % (acima if f > 0 else abaixo, abs(f))).replace(".", ","))
                    valor.set_color("#2e8b57" if f > 0 else "#d35400")
                rodape.set_text("%.0f leituras/s  ·  %d pacotes  ·  %d perdidas  ·  %d erros"
                                % (fs, pacotes, perdidas, erros))
            plt.pause(0.05)
    finally:
        if args.salvar and plt.fignum_exists(fig.number):
            fig.savefig(args.salvar, dpi=150)
        ble.parar.set()
        ble.join(timeout=5)
        _, _, pacotes, perdidas, erros = dados.copia()
        print("Encerrado: %d pacotes, %d leituras perdidas, %d erros de formato." % (pacotes, perdidas, erros))


def argumentos():
    p = argparse.ArgumentParser(description="Grafico ao vivo do SAMBA via BLE (sem limite de tempo)")
    p.add_argument("--janela", type=float, default=10.0, help="segundos visiveis no grafico (padrao 10)")
    p.add_argument("--sem-tara", action="store_true", help="nao faz a tara ao conectar")
    p.add_argument("--positivo", choices=["tracao", "compressao"], default="tracao",
                   help="qual esforco aparece acima de zero (depende da fiacao; confira puxando a celula)")
    p.add_argument("--usb", metavar="PORTA", default=None,
                   help="plano B sem Bluetooth: le a placa pelo cabo USB (ex.: --usb COM6)")
    p.add_argument("--segundos", type=float, default=0, help=argparse.SUPPRESS)  # 0 = sem limite (teste)
    p.add_argument("--salvar", default=None, help=argparse.SUPPRESS)              # PNG ao encerrar (teste)
    return p.parse_args()


if __name__ == "__main__":
    try:
        principal(argumentos())
    except KeyboardInterrupt:
        print("Interrompido.")
