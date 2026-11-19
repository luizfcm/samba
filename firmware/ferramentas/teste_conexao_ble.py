"""
SAMBA - teste de confiabilidade da conexao BLE pelo PC (mesma ideia do botao "Testar conexao" da pagina do celular).

Faz N ciclos de: procurar -> conectar -> START por alguns segundos -> STOP -> desconectar, e no fim mostra
quantos ciclos funcionaram, o tempo para conectar e as leituras perdidas, repetidas e invalidas.

Uso (na pasta ferramentas):   python teste_conexao_ble.py            (10 ciclos de 3 s)
                              python teste_conexao_ble.py --ciclos 20 --segundos 5
"""

import argparse
import asyncio
import time

from bleak import BleakClient, BleakScanner

from samba_ble_cliente import (OP_START, OP_STOP, UUID_CONTROLE, UUID_MEDICAO, UUID_SERVICO, decodifica_pacote,
                               pede_intervalo_curto)


async def comando(cli, op, r):
    """Envia um comando. Se a placa responder 'sem recursos' (erro 0x11, radio congestionado), reenvia como
    'write without response': a placa nao precisa montar resposta, e o comando passa mesmo congestionada."""
    try:
        await cli.write_gatt_char(UUID_CONTROLE, bytes([op]), response=True)
        return
    except Exception:
        pass
    r["repeticoes"] += 1
    await cli.write_gatt_char(UUID_CONTROLE, bytes([op]), response=False)


async def espera_fim_do_fluxo(r, limite=90.0):
    """Depois do STOP a placa ainda entrega o que estava na fila (ate 60 s de leituras). Com o radio
    congestionado isso leva alguns segundos. Espera os pacotes pararem antes de desconectar."""
    t0 = time.perf_counter()
    antes = r["pacotes"]
    while time.perf_counter() - t0 < limite:
        n = r["pacotes"]
        await asyncio.sleep(0.6)
        if r["pacotes"] == n:
            r["drenados"] = r["pacotes"] - antes
            return
    raise RuntimeError("os pacotes nao pararam %.0f s depois do STOP" % limite)


async def ciclo(k, segundos, vazao):
    r = {"ciclo": k, "achou": False, "conectou": False, "t_conexao": None, "pacotes": 0, "perdidas": 0, "erro": "",
         "repeticoes": 0, "drenados": 0, "intervalo": None, "leituras": 0, "repetidas": 0, "invalidos": 0}
    disp = await BleakScanner.find_device_by_filter(
        lambda d, ad: (ad.local_name or d.name) == "SAMBA" or UUID_SERVICO in [u.lower() for u in (ad.service_uuids or [])],
        timeout=10.0)
    if disp is None:
        r["erro"] = "nao encontrado"
        return r
    r["achou"] = True
    ult = {"seq": None}

    def recebe(_, dados):
        try:
            a = decodifica_pacote(bytes(dados))
        except ValueError:
            r["invalidos"] += 1
            return
        anterior = -1 if ult["seq"] is None else ult["seq"]  # a sequencia comeca em 0 a cada START
        if a[0][0] > anterior + 1:
            r["perdidas"] += a[0][0] - anterior - 1
        elif a[0][0] <= anterior:  # repetida ou fora de ordem
            r["repetidas"] += len(a)
        ult["seq"] = a[-1][0]
        r["pacotes"] += 1
        r["leituras"] += len(a)

    t0 = time.perf_counter()
    try:
        async with BleakClient(disp, timeout=15.0) as cli:
            r["conectou"] = True
            r["t_conexao"] = time.perf_counter() - t0
            if vazao:
                r["intervalo"] = pede_intervalo_curto(cli)
            await cli.start_notify(UUID_MEDICAO, recebe)
            await comando(cli, OP_START, r)
            await asyncio.sleep(segundos)
            await comando(cli, OP_STOP, r)
            await espera_fim_do_fluxo(r)
    except Exception as e:
        r["erro"] = type(e).__name__ + (": " + str(e) if str(e) else "")
    return r


async def principal(args):
    res = []
    for k in range(1, args.ciclos + 1):
        r = await ciclo(k, args.segundos, not args.sem_intervalo_curto)
        ok = r["conectou"] and r["pacotes"] > 0 and not r["erro"]
        print("ciclo %2d: %s | conexao %s |%s %5d leituras em %4d pacotes | %d perdidas%s%s%s %s" % (
            k, "OK   " if ok else "FALHA", "%.1f s" % r["t_conexao"] if r["t_conexao"] else "  -  ",
            " intervalo %2.0f ms |" % r["intervalo"] if r["intervalo"] else "",
            r["leituras"], r["pacotes"], r["perdidas"],
            " | %d REPETIDAS/fora de ordem" % r["repetidas"] if r["repetidas"] else "",
            " | %d pacotes INVALIDOS" % r["invalidos"] if r["invalidos"] else "",
            (" | comando sem resposta %dx" % r["repeticoes"] if r["repeticoes"] else "") +
            (" | %d pacotes da fila depois do STOP" % r["drenados"] if r["drenados"] > 3 else ""),
            ("| " + r["erro"]) if r["erro"] else ""), flush=True)
        r["ok"] = ok
        res.append(r)
        await asyncio.sleep(1.5)
    n_ok = sum(r["ok"] for r in res)
    tempos = [r["t_conexao"] for r in res if r["t_conexao"]]
    print("\n===== %d de %d ciclos OK (%.0f%%) =====" % (n_ok, len(res), 100.0 * n_ok / len(res)))
    if tempos:
        print("tempo para conectar: medio %.1f s, maximo %.1f s" % (sum(tempos) / len(tempos), max(tempos)))
    print("leituras recebidas: %d | perdidas: %d | repetidas/fora de ordem: %d | pacotes invalidos: %d" % (
        sum(r["leituras"] for r in res), sum(r["perdidas"] for r in res), sum(r["repetidas"] for r in res),
        sum(r["invalidos"] for r in res)))


def argumentos():
    p = argparse.ArgumentParser(description="Teste de confiabilidade da conexao BLE do SAMBA")
    p.add_argument("--ciclos", type=int, default=10)
    p.add_argument("--segundos", type=float, default=3.0, help="duracao da coleta em cada ciclo")
    p.add_argument("--sem-intervalo-curto", action="store_true",
                   help="nao pede o intervalo de 15 ms ao Windows (para comparar)")
    return p.parse_args()


if __name__ == "__main__":
    asyncio.run(principal(argumentos()))
