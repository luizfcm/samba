"""Uso: python serial_cmd.py COM6 "cmd1;espera_s" "cmd2;espera_s" ...  (cmd vazio = so le)"""
import sys, time, serial
s = serial.Serial()
s.port = sys.argv[1]; s.baudrate = 921600; s.timeout = 0.1
s.dtr = False; s.rts = False          # nao reseta a ESP ao abrir
s.open()
time.sleep(0.3); s.reset_input_buffer()
for arg in sys.argv[2:]:
    cmd, _, esp = arg.partition(";")
    if cmd:
        s.write((cmd + "\n").encode()); print(">>> " + cmd, flush=True)
    fim = time.time() + float(esp or 1)
    while time.time() < fim:
        l = s.readline()
        if l:
            print(l.decode(errors="replace").rstrip(), flush=True)
s.close()
