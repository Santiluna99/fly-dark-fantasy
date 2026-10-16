#!/usr/bin/env python3
"""
Reentrena SOLO el lector olfativo con las condiciones reales del juego: intensidades de olor distintas (10-90 Hz de media) y
asimetrias entre antenas de -80% a +80%, incluidas las simetricas (objetivo 0, para que no haya giro fantasma).
Ajusta una regresion ridge sobre las neuronas descendentes: asimetria = f(actividad de las DN). Valida con ensayos no usados.
Mantiene el lector de vision de decoders.npz.
"""
import numpy as np, os, sys, time, fly_sim as fs
HERE = os.path.dirname(os.path.abspath(__file__))
b = fs.Brain(os.path.join(HERE, "datos", "Drosophila_brain_model"), os.path.join(HERE, "datos", "flywire_annotations", "supplemental_files", "Supplemental_file1_neuron_annotations.tsv"))
m = b.meta; cls = m.cell_class.fillna("").values; side = m.side.fillna("").values
orn = {sd: np.nonzero((cls == "olfactory") & (side == sd))[0] for sd in ("left", "right")}
dec = dict(np.load(os.path.join(HERE, "decoders.npz")))
dn = dec["dn_idx"]
for s in orn.values(): b.nref[s] = 0
WIN = 300.0
LEV = [10, 25, 45, 70, 90]                 # Hz medios por antena
ASY = [-0.8, -0.4, -0.2, -0.1, -0.05, 0.0, 0.0, 0.05, 0.1, 0.2, 0.4, 0.8]   # (der-izq)/(der+izq)
REP = int(sys.argv[1]) if len(sys.argv) > 1 else 6

def trial(rl, rr):
    b.v[:] = b.P["v0"]; b.g[:] = 0; b.ref[:] = 0; b.rates[:] = 0
    b.rates[orn["left"]] = rl; b.rates[orn["right"]] = rr
    tot = np.zeros(b.n)
    for _ in range(int(WIN // 10)): tot += b.advance(10)
    return tot[dn] / (WIN / 1000)

X, Y, L = [], [], []
t0 = time.time()
for r in range(REP):
    for lv in LEV:
        for a in ASY:
            rl, rr = lv * (1 - a), lv * (1 + a)
            X.append(trial(min(rl, 100), min(rr, 100))); Y.append(a / 0.8); L.append(lv)
    print(f"ronda {r+1}/{REP} ({time.time()-t0:.0f}s)", flush=True)
X, Y, L = np.array(X), np.array(Y), np.array(L)
np.savez(os.path.join(HERE, "olfato_train.npz"), X=X, Y=Y, L=L)
# validacion: ultima ronda = test, resto = entrenamiento
n_per = len(LEV) * len(ASY); te = np.arange(len(Y)) >= len(Y) - n_per; tr = ~te
mu = X[tr].mean(0); sd = X[tr].std(0) + 1e-3
def fit(lam, idx):
    Z = (X[idx] - mu) / sd; A = Z.T @ Z + lam * np.eye(Z.shape[1])
    ybar = Y[idx].mean(); beta = np.linalg.solve(A, Z.T @ (Y[idx] - ybar)); return beta, ybar
best = None
for lam in (30, 100, 300, 1000, 3000, 10000):
    beta, yb = fit(lam, tr)
    p = ((X[te] - mu) / sd) @ beta + yb
    err = np.sqrt(np.mean((p - Y[te]) ** 2)); r_ = np.corrcoef(p, Y[te])[0, 1]
    print(f"lambda {lam}: RMSE {err:.3f} correlacion {r_:.2f}", flush=True)
    if best is None or err < best[0]: best = (err, lam)
lam = best[1]
beta, yb = fit(lam, tr)
p = ((X[te] - mu) / sd) @ beta + yb
Yt = Y[te]; Lt = L[te]
print("--- validacion (lambda %d) ---" % lam)
print("simetrico (a=0): media %+.2f sd %.2f" % (p[Yt == 0].mean(), p[Yt == 0].std()))
for lv in LEV:
    s = (Yt == 0) & (Lt == lv); print(f"   nivel {lv:2d} Hz simetrico: {p[s].mean():+.2f}")
for a in (0.1, 0.2, 0.4, 0.8):
    pr, pl = p[np.isclose(Yt, a / 0.8)], p[np.isclose(Yt, -a / 0.8)]
    acc = 0.5 * ((pr > 0).mean() + (pl < 0).mean())
    print(f"asimetria {a:.1f}: der {pr.mean():+.2f} izq {pl.mean():+.2f} | signo correcto {100*acc:.0f}%")
# reentrena con todo y guarda (pred = x@w - bo, scale = 1)
beta, yb = fit(lam, np.ones(len(Y), bool))
mu = X.mean(0); sd = X.std(0) + 1e-3
beta, yb = fit(lam, np.ones(len(Y), bool))
w = beta / sd
dec["olfato_w"] = w.astype(np.float32); dec["olfato_scale"] = np.float32(1.0)
dec["olfato_bias"] = np.float32(-(yb - mu @ w))
np.savez(os.path.join(HERE, "decoders.npz"), **dec)
print("decoders.npz actualizado", flush=True)
