#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""
Arreglos sobre fly_circuits.py (mismo modelo LIF, conectoma FlyWire v783):

1) OLFATO (activación densa de células de Kenyon):
   - DAN->KC y KC->KC a 0: la dopamina es modulatoria (no sinapsis rápida) y las
     sinapsis KC-KC son débiles/axo-axónicas; en el modelo base forman una
     recurrencia enorme (+379.000 de peso neto KC->KC).
   - Solo en el módulo olfativo (olfactory, ALPN, ALLN, ALON, LHLN, LHCENT): inhibición x5
     y excitación x0.7. NO se toca el resto del cerebro: un ajuste global rompía la
     fibra gigante (DNp01 bajaba de ~250 Hz a ~0-60 Hz).
2) LATERALIZACIÓN: busca neuronas descendentes (DN) que sepan de qué lado vino el estímulo
   y genera un "readout de giro" = tasa DN derecha - tasa DN izquierda.

Uso: python fly_fixes.py --trials 3
"""
import argparse, json
import numpy as np, scipy.sparse as sp, pandas as pd
import fly_circuits as fc

OLF_CLASSES = ["olfactory", "ALPN", "ALLN", "ALON", "LHLN", "LHCENT"]
G_INH, G_EXC, G_APL = 5.0, 0.7, 1.0


def olfactory_profile(W, meta, g_inh=G_INH, g_exc=G_EXC, g_apl=G_APL):
    cls = meta.cell_class.fillna("").values
    typ = meta.cell_type.fillna("").values
    kc, dan, apl = cls == "Kenyon_Cell", cls == "DAN", typ == "APL"
    olf = np.isin(cls, OLF_CLASSES)
    C = W.tocoo()
    d = C.data.copy()
    d[dan[C.row] & kc[C.col]] = 0
    d[kc[C.row] & kc[C.col]] = 0
    d[apl[C.row] & kc[C.col]] *= g_apl
    m, neg = olf[C.col], d < 0
    d[m & neg] *= g_inh
    d[m & ~neg] *= g_exc
    return sp.csr_matrix((d, (C.row, C.col)), shape=W.shape)


ODORS = {"DM1+DM2": ["ORN_DM1", "ORN_DM2"], "DA2": ["ORN_DA2"], "DA1": ["ORN_DA1"], "VA2": ["ORN_VA2"],
         "DL1": ["ORN_DL1"], "VM4": ["ORN_VM4"], "DL3": ["ORN_DL3"]}


def olfaction_panel(W, meta, T=200):
    kc = (meta.cell_class == "Kenyon_Cell").values
    sets, info = {}, {}
    for k, types in ODORS.items():
        s = fc.sel(meta, types)
        c, _ = fc.simulate(W, s, T=T, seed=0)
        sets[k] = set(np.nonzero(c[kc] > 0)[0])
        a = c > 0
        a[s] = False
        info[k] = {"KC_activas": len(sets[k]), "neuronas_respondieron": int(a.sum())}
    ks = [k for k in sets if sets[k]]
    js = [len(sets[a] & sets[b]) / len(sets[a] | sets[b]) for i, a in enumerate(ks) for b in ks[i + 1:]]
    return {"KC_medio": float(np.mean([v["KC_activas"] for v in info.values()])),
            "pct_KC": round(100 * np.mean([v["KC_activas"] for v in info.values()]) / kc.sum(), 1),
            "jaccard_entre_olores": round(float(np.mean(js)), 2), "por_olor": info}


def side_rates(W, meta, types, cls, side, T, trials):
    s = fc.sel(meta, types, side=side, cls=cls)
    return np.mean([fc.simulate(W, s, T=T, seed=k)[0] for k in range(trials)], axis=0) / (T / 1000.0)


def dn_hz(meta, r, name, side):
    m = ((meta.cell_type == name) & (meta.side == side)).values
    return float(r[m].mean()) if m.any() else 0.0


def lateral(W, meta, types, cls, T, trials, dn_name):
    out = {}
    for side in ["left", "right"]:
        r = side_rates(W, meta, types, cls, side, T, trials)
        L, R = dn_hz(meta, r, dn_name, "left"), dn_hz(meta, r, dn_name, "right")
        out[side] = {"DN_izq_Hz": round(L, 1), "DN_der_Hz": round(R, 1), "giro(der-izq)": round(R - L, 1)}
    ok = out["left"]["giro(der-izq)"] > 0 > out["right"]["giro(der-izq)"]
    out["consistente"] = bool(ok)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default="Drosophila_brain_model")
    ap.add_argument("--ann", default="flywire_annotations/supplemental_files/Supplemental_file1_neuron_annotations.tsv")
    ap.add_argument("--trials", type=int, default=3)
    ap.add_argument("--out", default="resultados_v2.json")
    a = ap.parse_args()
    W, meta = fc.load(a.repo, a.ann)
    Wol = olfactory_profile(W, meta)
    res = {"parametros": {"g_inh": G_INH, "g_exc": G_EXC, "g_apl": G_APL}}
    print("Olfato: modelo base vs arreglado", flush=True)
    res["olfato_base"] = olfaction_panel(W, meta)
    res["olfato_arreglado"] = olfaction_panel(Wol, meta)
    for k in ("olfato_base", "olfato_arreglado"):
        print(k, res[k]["pct_KC"], "% KC | Jaccard", res[k]["jaccard_entre_olores"], flush=True)
    print("Fibra gigante con los nuevos pesos (vision sin tocar):", flush=True)
    s = fc.sel(meta, ["LPLC2"])
    c, f = fc.simulate(W, s, T=300, seed=0)
    res["vision_GF_Hz"] = [round(float(x), 0) for x in c[(meta.cell_type == "DNp01").values] / 0.3]
    print(res["vision_GF_Hz"], flush=True)
    print("Lateralización (readout de giro = DN der - DN izq):", flush=True)
    res["giro_vision_LPLC2_DNa02"] = lateral(W, meta, ["LPLC2"], None, 300, a.trials, "DNa02")
    res["giro_vision_LPLC2_DNa03"] = lateral(W, meta, ["LPLC2"], None, 300, a.trials, "DNa03")
    res["giro_olfato_ORN_DNa01"] = lateral(Wol, meta, None, "olfactory", 300, a.trials, "DNa01")
    res["giro_olfato_ORN_DNa02"] = lateral(Wol, meta, None, "olfactory", 300, a.trials, "DNa02")
    for k in [k for k in res if k.startswith("giro_")]:
        print(k, res[k], flush=True)
    json.dump(res, open(a.out, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
