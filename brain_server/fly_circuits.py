#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""
Prueba de circuitos de olfato y visión sobre el conectoma real de FlyWire (v783).

Modelo: LIF con sinapsis alfa, mismos parámetros que Shiu et al. 2023
(github.com/philshiu/Drosophila_brain_model), reimplementado en numpy/scipy
(sin Brian2) para poder ejecutarlo en cualquier máquina.

Datos necesarios (git clone):
  --repo  Drosophila_brain_model/   (Completeness_783.csv, Connectivity_783.parquet)
  --ann   flywire_annotations/supplemental_files/Supplemental_file1_neuron_annotations.tsv

Uso:  python fly_circuits.py --exp all --T 300 --trials 2
"""
import argparse, json, time
import numpy as np, pandas as pd, scipy.sparse as sp

P = dict(dt=0.1, v0=-52.0, vth=-45.0, vrst=-52.0, tmbr=20.0, tau=5.0,
         trfc=2.2, tdly=1.8, wsyn=0.275, rpoi=150.0, fpoi=250.0)  # ms, mV, Hz


def load(repo, ann):
    comp = pd.read_csv(f"{repo}/Completeness_783.csv", index_col=0)
    con = pd.read_parquet(f"{repo}/Connectivity_783.parquet")
    n = len(comp)
    w = con["Excitatory x Connectivity"].values.astype(np.float32) * P["wsyn"]
    W = sp.csr_matrix((w, (con["Presynaptic_Index"].values, con["Postsynaptic_Index"].values)),
                      shape=(n, n))
    a = pd.read_csv(ann, sep="\t", low_memory=False).drop_duplicates("root_id").set_index("root_id")
    meta = a.reindex(comp.index.values).reset_index()
    return W, meta


def simulate(W, stim, T=300.0, seed=0, vth=None):
    """Devuelve (spikes por neurona, latencia del primer spike en ms)."""
    rng = np.random.default_rng(seed)
    n = W.shape[0]
    vth = P["vth"] if vth is None else vth
    dt = P["dt"]
    steps = int(T / dt)
    dly = int(round(P["tdly"] / dt))
    v = np.full(n, P["v0"], np.float32)
    g = np.zeros(n, np.float32)
    ref = np.zeros(n, np.int16)
    nref = np.full(n, int(round(P["trfc"] / dt)), np.int16)
    nref[stim] = 0  # sin refractario en neuronas estimuladas (como en el paper)
    counts = np.zeros(n, np.int32)
    first = np.full(n, -1.0, np.float32)
    buf = [np.empty(0, np.int64) for _ in range(dly)]
    kick = P["wsyn"] * P["fpoi"]
    lam = P["rpoi"] * dt / 1000.0
    for t in range(steps):
        arr = buf[t % dly]
        if arr.size:
            g += np.asarray(W[arr].sum(axis=0)).ravel()
        if len(stim):
            v[stim] += rng.poisson(lam, len(stim)) * kick
        act = ref <= 0
        v[act] += dt * (P["v0"] - v[act] + g[act]) / P["tmbr"]
        g[act] -= dt * g[act] / P["tau"]
        ref[~act] -= 1
        spk = np.nonzero(v > vth)[0]
        buf[t % dly] = spk
        if spk.size:
            v[spk] = P["vrst"]
            g[spk] = 0.0
            ref[spk] = nref[spk]
            counts[spk] += 1
            new = spk[first[spk] < 0]
            first[new] = t * dt
    return counts, first


def sel(meta, types=None, side=None, cls=None):
    m = np.ones(len(meta), bool)
    if types is not None:
        m &= meta.cell_type.isin(types).values
    if cls is not None:
        m &= (meta.cell_class == cls).values
    if side is not None:
        m &= (meta.side == side).values
    return np.nonzero(m)[0]


EXPERIMENTS = {
    # --- olfato ---
    "olf_fruta":   lambda m: sel(m, ["ORN_DM1", "ORN_DM2"]),   # ésteres frutales (atractivo)
    "olf_geosmina": lambda m: sel(m, ["ORN_DA2"]),              # geosmina (repulsivo)
    "olf_cVA":     lambda m: sel(m, ["ORN_DA1"]),               # feromona cVA
    # --- visión ---
    "vis_loom_ambos":  lambda m: sel(m, ["LPLC2"]),             # detectores de looming
    "vis_loom_izq":    lambda m: sel(m, ["LPLC2"], side="left"),
    "vis_LC4":         lambda m: sel(m, ["LC4"]),               # otra vía a la fibra gigante
    "vis_control_LC12": lambda m: sel(m, ["LC12"]),             # control: no es looming
    "vis_ojo_izq":     lambda m: sel(m, ["R1-6"], side="left"), # fotorreceptores del ojo izquierdo
}


def report(name, stim, counts, first, meta, T):
    rate = counts / (T / 1000.0)
    mask = np.ones(len(meta), bool)
    mask[stim] = False
    resp = mask & (counts > 0)
    out = {"experimento": name, "n_estimuladas": int(len(stim)),
           "n_respondieron": int(resp.sum()), "pct_cerebro": round(100 * resp.sum() / len(meta), 2)}
    cls = meta.cell_class.fillna(meta.super_class).fillna("?")
    df = pd.DataFrame({"cls": cls[resp], "rate": rate[resp]})
    g = df.groupby("cls").agg(n=("rate", "size"), hz=("rate", "mean")).sort_values("n", ascending=False)
    out["por_clase"] = {k: [int(r.n), round(float(r.hz), 1)] for k, r in g.head(8).iterrows()}
    dn = (meta.super_class == "descending").values
    d = pd.DataFrame({"tipo": meta.cell_type[dn], "lado": meta.side[dn], "hz": rate[dn], "lat": first[dn]})
    top = d[d.hz > 0].sort_values("hz", ascending=False).head(6)
    out["descendentes_top"] = [f"{r.tipo} ({r.lado}) {r.hz:.0f} Hz" for r in top.itertuples()]
    out["DN_activas"] = int((d.hz > 0).sum())
    out["DN_hz_izq"] = round(float(d[d.lado == "left"].hz.mean()), 2)
    out["DN_hz_der"] = round(float(d[d.lado == "right"].hz.mean()), 2)
    gf = d[d.tipo == "DNp01"]
    out["DNp01_fibra_gigante_hz"] = [round(float(x), 1) for x in gf.hz]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default="Drosophila_brain_model")
    ap.add_argument("--ann", default="flywire_annotations/supplemental_files/Supplemental_file1_neuron_annotations.tsv")
    ap.add_argument("--exp", default="all")
    ap.add_argument("--T", type=float, default=300.0)
    ap.add_argument("--trials", type=int, default=2)
    ap.add_argument("--rate", type=float, default=150.0, help="Hz de estimulacion Poisson")
    ap.add_argument("--out", default="resultados.json")
    a = ap.parse_args()
    P["rpoi"] = a.rate
    t0 = time.time()
    W, meta = load(a.repo, a.ann)
    print(f"Cargado: {W.shape[0]} neuronas, {W.nnz} conexiones ({time.time()-t0:.0f}s)", flush=True)
    names = list(EXPERIMENTS) if a.exp == "all" else a.exp.split(",")
    res = []
    for nm in names:
        stim = EXPERIMENTS[nm](meta)
        cs, fs = [], []
        for s in range(a.trials):
            c, f = simulate(W, stim, a.T, seed=s)
            cs.append(c); fs.append(f)
        counts = np.mean(cs, axis=0)
        first = np.where(np.min(fs, axis=0) < 0, -1, np.mean(fs, axis=0))
        r = report(nm, stim, counts, first, meta, a.T)
        res.append(r)
        print(json.dumps(r, ensure_ascii=False, indent=1), flush=True)
        json.dump(res, open(a.out, "w"), ensure_ascii=False, indent=1)
    print(f"Listo en {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
