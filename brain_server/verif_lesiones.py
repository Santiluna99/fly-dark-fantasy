#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""Mide que cambia en las salidas del cerebro real con cada lesion, y comprueba que al quitarla todo vuelve a ser igual.
Uso: python verif_lesiones.py [lesion ...]      (sin argumentos: todas)"""
import sys, time, threading, numpy as np, fly_server as fsv
srv = fsv.Server(speed=50.0); threading.Thread(target=srv.loop, daemon=True).start()
def wait(s):
    t = srv.t_ms
    while srv.t_ms < t + s * 1000: time.sleep(0.01)
def medir(stim, seg=1.2):
    """Estimulo fijo: deja 0.8 s para que se asiente y promedia 'seg' s."""
    with srv.lock: srv.stim = stim; srv.reset_flag = True
    wait(0.8)
    acc = []
    t0 = srv.t_ms
    while srv.t_ms < t0 + seg * 1000:
        with srv.lock: r = srv.reply()
        acc.append((r["turn"], r["fwd"], r["gf"], r["kc"], r["hz"])); time.sleep(0.01)
    return np.mean(acc, 0)
ESC = [("olor izq", (0.6, 0.15, 0, 0, 0)), ("olor der", (0.15, 0.6, 0, 0, 0)), ("amenaza izq", (0, 0, 0.8, 0, 0)), ("amenaza der", (0, 0, 0, 0.8, 0))]
def fila(nombre):
    out = [medir(st) for _, st in ESC]
    print(f"{nombre:26s}" + " | ".join(f"giro {o[0]:+.2f} av {o[1]:.2f} esc {o[2]:.2f} kc {o[3]:.3f}" for o in out), flush=True)
    return out
wait(1.0)
print(" " * 26 + " | ".join(f"{n:^38s}" for n, _ in ESC))
base = fila("SANO")
ids = sys.argv[1:] or list(fsv.LESIONS)
for k in ids:
    with srv.lock: srv.set_lesion(k.split("+"))
    fila(f"{k} ({len(srv.les)} n.)")
with srv.lock: srv.set_lesion([])
post = fila("SANO (tras quitar todo)")
print("neuronas silenciadas al final:", len(srv.les), "| refractario pendiente:", int((srv.b.ref > 100).sum()),
      "| pesos intactos:", bool(np.array_equal(srv.b.data, srv.base_w)))
