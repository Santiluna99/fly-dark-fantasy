#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""
Calibra los LECTORES de giro del cerebro real. Para cada estimulo (amenaza visual, olor) corre N ensayos con el estimulo mas
fuerte a la izquierda y a la derecha, y aprende pesos sobre las neuronas descendentes (DN):  w = media(der) - media(izq).
El lector da puntuacion > 0 cuando el estimulo esta a la derecha. Se valida con ensayos que NO se usaron para aprender.
 - vision: LPLC2 (looming) 150 Hz en un lado y 0 en el otro
 - olfato: neuronas olfativas 50 Hz en un lado y 15 Hz en el otro (diferencias realistas de las antenas en el juego)
Salida: decoders.npz (indices de DN, pesos, escala y nivel base con estimulo simetrico).
"""
import numpy as np, fly_sim as fs
import os
HERE = os.path.dirname(os.path.abspath(__file__))
b = fs.Brain(os.path.join(HERE, "datos", "Drosophila_brain_model"), os.path.join(HERE, "datos", "flywire_annotations", "supplemental_files", "Supplemental_file1_neuron_annotations.tsv"))
m = b.meta; cls = m.cell_class.fillna("").values; side = m.side.fillna("").values; typ = m.cell_type.fillna("").values
dn = np.nonzero((m.super_class == "descending").values)[0]
orn = {sd: np.nonzero((cls == "olfactory") & (side == sd))[0] for sd in ("left", "right")}
lp = {sd: np.nonzero((typ == "LPLC2") & (side == sd))[0] for sd in ("left", "right")}
for s in list(orn.values()) + list(lp.values()): b.nref[s] = 0
WIN, N = 200.0, 16          # ventana de lectura en ms y ensayos por condicion

def trial(sets, rl, rr):
    b.v[:] = b.P["v0"]; b.g[:] = 0; b.ref[:] = 0; b.rates[:] = 0
    b.rates[sets["left"]] = rl; b.rates[sets["right"]] = rr
    tot = np.zeros(b.n)
    for _ in range(int(WIN // 10)): tot += b.advance(10)
    return tot[dn] / (WIN / 1000)

def learn(L, R, h):
    w = R[:h].mean(0) - L[:h].mean(0)
    sd = np.sqrt(0.5 * (R[:h].var(0) + L[:h].var(0))) / np.sqrt(h) + 1e-6
    w = np.where(np.abs(w) > 2 * sd, w, 0.0)
    return w / (np.abs(w).sum() + 1e-9)

out = {}
for name, sets, (hi, lo), sym in (("vision", lp, (150.0, 0.0), 150.0), ("olfato", orn, (50.0, 15.0), 32.0)):
    L = np.array([trial(sets, hi, lo) for _ in range(N)]); R = np.array([trial(sets, lo, hi) for _ in range(N)])
    S = np.array([trial(sets, sym, sym) for _ in range(N)])
    h = N // 2
    w = learn(L, R, h)
    sL, sR = L[h:] @ w, R[h:] @ w
    thr = 0.5 * ((L[:h] @ w).mean() + (R[:h] @ w).mean())
    acc = 0.5 * ((sL < thr).mean() + (sR > thr).mean())
    auc = float(np.mean([a < b_ for a in sL for b_ in sR]))
    w = learn(L, R, N)                                  # reentrena con todos los ensayos
    scale = 0.5 * ((R @ w).mean() - (L @ w).mean())
    bias = float((S @ w).mean() / scale)                # nivel base con estimulo simetrico (se resta al leer)
    print(f"{name}: DN con peso {int((w != 0).sum())}/{len(dn)} | validacion: precision {100*acc:.0f}% AUC {auc:.2f} | "
          f"izq {(L@w).mean()/scale-bias:+.2f} der {(R@w).mean()/scale-bias:+.2f} simetrico 0 (sd {(S@w).std()/scale:.2f})", flush=True)
    out[name + "_w"] = w.astype(np.float32); out[name + "_scale"] = np.float32(scale); out[name + "_bias"] = np.float32(bias)
out["dn_idx"] = dn
np.savez(os.path.join(HERE, "decoders.npz"), **out)
