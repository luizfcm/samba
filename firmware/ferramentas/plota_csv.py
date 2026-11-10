"""
SAMBA - gera graficos (PNG) a partir dos CSVs de captura.

Aceita os dois formatos do projeto:
  1. Teste 02, comando "s <seg>" gravado pelo terminal (CoolTerm/PuTTY):
       indice,tempo_us,contagens,mV_por_V,kg   ...   FIM_CSV
     Pode haver lixo antes do cabecalho e depois do FIM_CSV: tudo isso e ignorado.
  2. Cliente BLE (samba_ble_cliente.py --csv):
       sequencia,timestamp_us,valor,status      (valor em mN; contagens se o bit 4 do status = 1)

Instalar:  python -m pip install matplotlib        (opcional: scipy, para --filtro)
Exemplos:
  python plota_csv.py salto01.csv
  python plota_csv.py tracao.txt --mvv --filtro 30     (sem calibracao: saida da ponte em mV/V)
  python plota_csv.py salto01.csv --unidade N --filtro 30 --titulo "Salto CMJ - celula em compressao"
  python plota_csv.py ruido_1000sps.csv --histograma
  python plota_csv.py ble_mao.csv --mvv --filtro 30 --espectro   (tempo + espectro: mostra o 60 Hz)
"""

import argparse
import math
import sys

G = 9.80665


MVV_POR_CONTAGEM = 1000.0 / (8388608 * 128)  # ganho 128, medicao ratiometrica


def le_csv(caminho, mvv=False):
    """Devolve (tempo_s[], valores[], descricao_formato, dados_brutos_do_ADC?).
    valores em kg, ou em mV/V se mvv=True."""
    with open(caminho, encoding="utf-8", errors="replace") as fp:
        linhas = fp.read().splitlines()

    formato = None
    inicio = 0
    for i, l in enumerate(linhas):
        s = l.strip().lower()
        if "indice,tempo_us,contagens" in s:
            formato, inicio = "teste02", i + 1
            break
        if "sequencia,timestamp_us,valor" in s:
            formato, inicio = "ble", i + 1
            break
    if formato is None:
        raise ValueError("cabecalho nao encontrado (esperado 'indice,tempo_us,...' ou 'sequencia,timestamp_us,...')")

    t, kg = [], []
    bruto = False
    sem_bruto = False
    for l in linhas[inicio:]:
        s = l.strip()
        if s.startswith("FIM_CSV"):
            break
        partes = s.split(",")
        try:
            if formato == "teste02" and len(partes) >= 5:
                t.append(int(partes[1]) / 1e6)
                kg.append(float(partes[3]) if mvv else float(partes[4]))
            elif formato == "ble" and len(partes) >= 4:
                status = int(partes[3])
                valor = int(partes[2])
                if mvv and len(partes) >= 5:  # coluna mV_por_V gravada pelo cliente BLE
                    kg.append(float(partes[4]))
                elif mvv:
                    if not status & (1 << 4):
                        sem_bruto = True
                        continue
                    kg.append(valor * MVV_POR_CONTAGEM)
                elif status & (1 << 4):
                    bruto = True
                    kg.append(float(valor))  # contagens cruas
                else:
                    kg.append(valor / 1000.0 / G)  # mN -> kg
                t.append(int(partes[1]) / 1e6)
        except ValueError:
            continue  # linha quebrada pelo terminal
    if len(t) < 2:
        if sem_bruto:
            raise ValueError("--mvv neste CSV do BLE (antigo, sem coluna mV_por_V) so funciona no modo bruto")
        raise ValueError("menos de 2 amostras validas no arquivo")
    t0 = t[0]
    t = [x - t0 for x in t]
    return t, kg, formato, bruto


def filtra(valores, taxa, corte):
    try:
        from scipy.signal import butter, filtfilt
    except ImportError:
        print("Aviso: scipy nao instalado; --filtro ignorado (python -m pip install scipy)")
        return None
    if corte >= taxa / 2:
        print("Aviso: corte >= metade da taxa; --filtro ignorado")
        return None
    b, a = butter(2, corte / (taxa / 2))  # 2a ordem ida e volta = fase zero (decisao do projeto)
    return list(filtfilt(b, a, valores))


def espectro(ax, y, taxa, unidade):
    """Densidade espectral (Welch) em escala log; marca 60 Hz e harmonicos da rede eletrica."""
    import numpy as np
    v = np.asarray(y, dtype=float)
    v = v - v.mean()
    try:
        from scipy.signal import welch
        f, pxx = welch(v, fs=taxa, nperseg=min(len(v), 2048))
        amp = np.sqrt(pxx)
        rotulo = "densidade espectral (%s/raiz(Hz))" % unidade
    except ImportError:
        w = np.hanning(len(v))
        amp = np.abs(np.fft.rfft(v * w)) * 2 / w.sum()
        f = np.fft.rfftfreq(len(v), 1 / taxa)
        rotulo = "amplitude (%s)" % unidade
    ax.semilogy(f[1:], amp[1:], lw=0.8, color="#1f5fa8")
    for k in range(1, int(taxa / 2 / 60) + 1):
        ax.axvline(60 * k, color="#c0392b", lw=0.6, alpha=0.35, ls="--")
    ax.text(61, amp[1:].max(), "60 Hz e harmonicos (rede eletrica)", color="#c0392b", fontsize=8, va="top")
    ax.set_xlim(0, taxa / 2)
    ax.set_xlabel("frequencia (Hz)")
    ax.set_ylabel(rotulo)
    ax.grid(alpha=0.3, which="both")
    # picos principais no terminal
    ordem = np.argsort(amp)[::-1]
    picos = []
    for i in ordem:
        if f[i] < 2 or any(abs(f[i] - q) < 3 for q in picos):
            continue
        picos.append(f[i])
        if len(picos) == 5:
            break
    print("picos do espectro (Hz): " + ", ".join("%.1f" % q for q in picos))


def estatisticas(t, y, unidade):
    n = len(y)
    dur = t[-1] - t[0]
    taxa = (n - 1) / dur if dur > 0 else float("nan")
    m = sum(y) / n
    dp = math.sqrt(sum((v - m) ** 2 for v in y) / (n - 1))
    dts = [t[i + 1] - t[i] for i in range(n - 1)]
    print("amostras %d | duracao %.3f s | taxa media %.1f Hz | dt min %.0f us, max %.0f us"
          % (n, dur, taxa, min(dts) * 1e6, max(dts) * 1e6))
    print("media %.5g %s | desvio padrao %.5g %s | min %.5g | max %.5g | pico-a-pico %.5g"
          % (m, unidade, dp, unidade, min(y), max(y), max(y) - min(y)))
    return taxa


def main():
    p = argparse.ArgumentParser(description="Graficos dos CSVs do SAMBA")
    p.add_argument("csv")
    p.add_argument("--unidade", choices=["kg", "N"], default="kg")
    p.add_argument("--mvv", action="store_true",
                   help="desenha em mV/V (saida da ponte, nao depende de calibracao). No teste 02 ja tira a tara")
    p.add_argument("--filtro", type=float, help="corte em Hz de um Butterworth 2a ordem fase zero (precisa de scipy)")
    p.add_argument("--titulo", default=None)
    p.add_argument("--histograma", action="store_true", help="acrescenta o histograma (bom para ruido com a celula parada)")
    p.add_argument("--espectro", action="store_true",
                   help="acrescenta o espectro (FFT/Welch): mostra interferencia de 60 Hz e harmonicos")
    p.add_argument("--saida", default=None, help="PNG de saida (padrao: mesmo nome do CSV)")
    a = p.parse_args()

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    t, y, formato, bruto = le_csv(a.csv, a.mvv)
    if a.mvv:
        unidade = "mV/V"
        bruto = False
    elif bruto:
        unidade = "contagens"
    elif a.unidade == "N":
        unidade = "N"
        y = [v * G for v in y]
    else:
        unidade = "kg"
    print("arquivo %s (formato %s)" % (a.csv, formato))
    taxa = estatisticas(t, y, unidade)
    yf = filtra(y, taxa, a.filtro) if a.filtro else None

    # Layout: tempo (+ histograma ao lado) e, com --espectro, o espectro embaixo
    linhas = [["tempo", "hist"] if a.histograma else ["tempo"]]
    if a.espectro:
        linhas.append(["espectro", "espectro"] if a.histograma else ["espectro"])
    fig, eixos = plt.subplot_mosaic(linhas, figsize=(11 if a.histograma else 10, 4.5 + (3.8 if a.espectro else 0)),
                                    width_ratios=[3, 1] if a.histograma else None,
                                    height_ratios=[1.2, 1] if a.espectro else None, layout="constrained")
    ax = eixos["tempo"]
    ax.plot(t, y, lw=0.6, color="#9aa7b8" if yf else "#1f5fa8", label="cru (%.0f amostras/s)" % taxa)
    if yf:
        ax.plot(t, yf, lw=1.4, color="#1f5fa8", label="filtrado %.0f Hz (fase zero)" % a.filtro)
        ax.legend(loc="best", fontsize=9)
    ax.set_xlim(t[0], t[-1])
    ax.set_xlabel("tempo (s)")
    if a.mvv:
        ax.set_ylabel("saida da ponte (mV/V)")
    elif bruto:
        ax.set_ylabel("contagens do ADC")
    else:
        ax.set_ylabel("forca (%s)" % unidade)
    ax.grid(alpha=0.3)
    ax.set_title(a.titulo or a.csv)
    if a.histograma:
        h = eixos["hist"]
        h.hist(y, bins=40, orientation="horizontal", color="#1f5fa8")
        h.set_xlabel("ocorrencias")
        h.grid(alpha=0.3)
        h.set_ylim(ax.get_ylim())
    if a.espectro:
        espectro(eixos["espectro"], y, taxa, unidade)
    saida = a.saida or a.csv.rsplit(".", 1)[0] + ".png"
    fig.savefig(saida, dpi=200)
    print("grafico salvo: %s" % saida)


if __name__ == "__main__":
    try:
        main()
    except ValueError as e:
        print("ERRO: %s" % e)
        sys.exit(1)
