"""SAMBA - captura pacotes reais da placa em hexadecimal, para os testes do app.

Uso (na pasta ferramentas):   python captura_hex.py > pacotes_reais.txt
Mostra: o Estado (13 bytes) parado e adquirindo, o 1o, o 2o e o ultimo pacote de Medicao de ~1 s de coleta,
cada um com o hexadecimal e os valores decodificados. Puxe ou aperte a celula durante a coleta se quiser
pacotes com forca.
"""
import asyncio

from bleak import BleakClient, BleakScanner

from samba_ble_cliente import (OP_START, OP_STOP, UUID_CONTROLE, UUID_ESTADO, UUID_MEDICAO, UUID_SERVICO,
                               decodifica_estado, decodifica_pacote, espera_fim_do_fluxo, pede_intervalo_curto)

pacotes = []


async def main():
    d = await BleakScanner.find_device_by_filter(
        lambda d, ad: (ad.local_name or d.name) == "SAMBA" or UUID_SERVICO in [u.lower() for u in (ad.service_uuids or [])],
        timeout=10)
    if d is None:
        print("SAMBA nao encontrado")
        return
    async with BleakClient(d) as c:
        pede_intervalo_curto(c)
        est = bytes(await c.read_gatt_char(UUID_ESTADO))
        print("ESTADO (lido, parado) %d bytes: %s" % (len(est), est.hex(" ")))
        print("   ->", decodifica_estado(est))
        await c.start_notify(UUID_MEDICAO, lambda _, b: pacotes.append(bytes(b)))
        await c.write_gatt_char(UUID_CONTROLE, bytes([OP_START]), response=True)
        await asyncio.sleep(1.0)
        est2 = bytes(await c.read_gatt_char(UUID_ESTADO))
        await c.write_gatt_char(UUID_CONTROLE, bytes([OP_STOP]), response=True)
        await espera_fim_do_fluxo(lambda: len(pacotes))
        print("ESTADO (lido, adquirindo) %d bytes: %s" % (len(est2), est2.hex(" ")))
        print("   ->", decodifica_estado(est2))
    if not pacotes:
        print("nenhum pacote recebido")
        return
    for i in sorted({0, min(1, len(pacotes) - 1), len(pacotes) - 1}):
        p = pacotes[i]
        a = decodifica_pacote(p)
        print("\nPACOTE %s (%d bytes, %d leituras): %s" % ("ultimo" if i == len(pacotes) - 1 else i, len(p), len(a),
                                                          p.hex(" ")))
        print("   seq %d..%d | t0 %d us | status 0x%04X | forcas em mN: %s" % (
            a[0][0], a[-1][0], a[0][1], a[0][3], [x[2] for x in a]))
    print("\ntotal: %d pacotes" % len(pacotes))


asyncio.run(main())
