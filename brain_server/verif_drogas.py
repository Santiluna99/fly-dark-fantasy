#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
import time, threading, numpy as np, fly_server as fsv
srv = fsv.Server(speed=50.0); threading.Thread(target=srv.loop, daemon=True).start()
def wait(s):
    t=srv.t_ms
    while srv.t_ms<t+s*1000: time.sleep(0.02)
def rest(label):
    with srv.lock: r=srv.reply()
    print(f"  {label:34s} fwd {r['fwd']:.2f}  dn {r['raw']['dn']:6.0f} kc {r['kc']:.3f}", flush=True)
wait(2); rest("fresco, sin droga (t=2s)")
for nm, lv, dur in [("nicotina",1.0,4),("anfetamina",1.0,4)]:
    print(nm, lv)
    srv.set_drug(nm, lv)
    for k in range(dur):
        wait(1.0); rest(f"con {nm} +{k+1}s")
    srv.set_drug(None, 0)
    print("  pesos identicos a los originales:", np.array_equal(srv.b.data, srv.base_w), "| ruido:", float(srv.bg.max()), float(srv.b.rates.max()))
    for k in range(4):
        wait(1.0); rest(f"tras quitar +{k+1}s")
