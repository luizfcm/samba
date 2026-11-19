"""
SAMBA - curva de calibracao (massa conhecida x leitura do ADC).

Os pontos vem do teste 02: ligue 'r' (mostra o bruto) e use 'l' com cada massa aplicada.
Anote o numero depois de "bruto". Inclua o ponto sem carga (0 kg).

Exemplo:
  python curva_calibracao.py 0:-1520 5:3850 10:9230 20:19990 --titulo "Celula S 2 t - tracao"

Saida: reta ajustada (contagens/kg), R2, erro de nao linearidade e um PNG com a reta e os residuos.
Instalar: python -m pip install matplotlib
"""

import argparse

G = 9.80665


def ajusta(x, y):
    n = len(x)
    mx, my = sum(x) / n, sum(y) / n
    sxx = sum((a - mx) ** 2 for a in x)
    sxy = sum((a - mx) * (b - my) for a, b in zip(x, y))
    incl = sxy / sxx
    inter = my - incl * mx
    ss_res = sum((b - (incl * a + inter)) ** 2 for a, b in zip(x, y))
    ss_tot = sum((b - my) ** 2 for b in y)
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else 1.0
    return incl, inter, r2


def main():
    p = argparse.ArgumentParser(description="Curva de calibracao do SAMBA")
    p.add_argument("pontos", nargs="+", help="massa_kg:contagens (ex.: 0:-1520 10:9230)")
    p.add_argument("--titulo", default="Curva de calibracao - SAMBA")
    p.add_argument("--saida", default="curva_calibracao.png")
    a = p.parse_args()

    x, y = [], []
    for s in a.pontos:
        m, c = s.split(":")
        x.append(float(m))
        y.append(float(c))
    if len(x) < 2:
        p.error("precisa de pelo menos 2 pontos")

    incl, inter, r2 = ajusta(x, y)
    res_kg = [(b - (incl * a_ + inter)) / incl for a_, b in zip(x, y)]
    fundo = max(abs(v) for v in x) or 1.0
    nl = max(abs(r) for r in res_kg) / fundo * 100

    print("Reta: contagens = %.2f x massa_kg %+.1f" % (incl, inter))
    print("Sensibilidade: %.2f contagens/kg  |  R2 = %.6f" % (incl, r2))
    print("Maior residuo: %.3f kg = %.2f %% da maior massa usada" % (max(abs(r) for r in res_kg), nl))
    print("Para o firmware final: fator = %.7f mN/contagem (deslocamento = tara feita na hora)" % (G * 1000 / incl))
    for a_, b, r in zip(x, y, res_kg):
        print("  %8.3f kg  %10.0f contagens  residuo %+.3f kg" % (a_, b, r))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, (ax, ar) = plt.subplots(2, 1, figsize=(7, 6), sharex=True, gridspec_kw={"height_ratios": [3, 1]})
    xs = [min(x), max(x)]
    ax.plot(xs, [incl * v + inter for v in xs], color="#1f5fa8", lw=1.2,
            label="ajuste: %.1f cont/kg, R² = %.5f" % (incl, r2))
    ax.plot(x, y, "o", color="#c0392b", label="medido")
    ax.set_ylabel("leitura do ADC (contagens)")
    ax.set_title(a.titulo)
    ax.grid(alpha=0.3)
    ax.legend(loc="best", fontsize=9)
    ar.axhline(0, color="#1f5fa8", lw=0.8)
    ar.plot(x, res_kg, "o", color="#c0392b")
    ar.set_xlabel("massa aplicada (kg)")
    ar.set_ylabel("resíduo (kg)")
    ar.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(a.saida, dpi=200)
    print("grafico salvo: %s" % a.saida)


if __name__ == "__main__":
    main()
