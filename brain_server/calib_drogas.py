#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""Calibra las drogas: mide fwd/giro/gf/kc del cerebro real en distintas situaciones, con cada droga y dosis. Uso: python calib_drogas.py [drogas...]"""
import sys, time, threading, json, numpy as np
import fly_server as fsv
srv = fsv.Server(speed=50.0)
threading.Thread(target=srv.loop, daemon=True).start()
CASES = {
    "reposo":      (0, 0, 0, 0, 0.0),
    "olor_dcha":   (0.1, 0.5, 0, 0, 0.0),
    "amenaza_dcha":(0, 0, 0.1, 0.6, 0.0),
}
def measure(settle=1.0, win=1.6):
    t = srv.t_ms
    while srv.t_ms < t + settle * 1000: time.sleep(0.02)
    acc = []; t1 = srv.t_ms
    while srv.t_ms < t1 + win * 1000:
        time.sleep(0.05)
        with srv.lock: r = srv.reply()
        acc.append([r["turn"], r["fwd"], r["gf"], r["kc"], r["raw"]["dn"]])
    a = np.array(acc)
    return a.mean(0), a[:, 0].std()
def run(name, level):
    srv.set_drug(None, 0); time.sleep(0.5)
    srv.set_drug(name, level)
    out = {}
    for cn, st in CASES.items():
        with srv.lock:
            srv.stim = (st[0], st[1], st[2], st[3], 0.0); srv.hunger = st[4] / 0.3
        m, sd = measure()
        out[cn] = m
    return out
names = sys.argv[1:] or ["base"] + list(fsv.DRUGS)
res = {}
for nm in names:
    levels = [0] if nm == "base" else [0.5, 1.0]
    for lv in levels:
        t0 = time.time()
        o = run(None if nm == "base" else nm, lv)
        res[f"{nm}@{lv}"] = {k: [round(float(x), 3) for x in v] for k, v in o.items()}
        r = o["reposo"]; od = o["olor_dcha"]; am = o["amenaza_dcha"]
        print(f"{nm:11s} dosis {lv:3.1f} | reposo turn {r[0]:+.2f} fwd {r[1]:.2f} gf {r[2]:.2f} kc {r[3]:.3f} dn {r[4]:7.0f} | olor_dcha turn {od[0]:+.2f} fwd {od[1]:.2f} | amenaza_dcha turn {am[0]:+.2f} fwd {am[1]:.2f} gf {am[2]:.2f} | {time.time()-t0:.0f}s", flush=True)
json.dump(res, open("calib_drogas.json", "w"), indent=1)
