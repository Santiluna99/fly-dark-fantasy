#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""
Servidor del cerebro real de la mosca para Godot (conectoma FlyWire v783, 138.639 neuronas).

Protocolo: TCP en localhost, un JSON por linea (UTF-8).
  Godot -> servidor:  {"orn":[izq,der], "loom":[izq,der], "hunger":h, "reset":false}
        orn  = intensidad de olor de fruta en cada antena (0..0.8)    loom = amenaza a cada lado (0..0.9)   hunger = 0..1
        opcionales: "drug":{"name","level"} o null | "lesion":[ids] (lista vacia = cerebro sano) | "map":true (pide el mapa)
  servidor -> Godot:  {"turn":-1..1, "fwd":0..1, "gf":0..1, "kc":fraccion, "view":[80 valores], "t_ms":tiempo del cerebro,
                       "hz":disparos/s de todo el cerebro, "px":"actividad por casilla del mapa", "lv":version de las lesiones}
        turn > 0 = girar a la DERECHA.   view = actividad agrupada para el panel neuronal (mismo orden que FlyBrain).
        px = una letra por casilla del mapa (0-9a-z = 36 niveles). Con "map":true la respuesta trae ademas
        "grid":{"w","h","dens":"densidad de neuronas por casilla","les":"casillas lesionadas","ids":[lesiones activas]}.

El cerebro corre en un hilo propio y continuo (no espera a Godot); cada mensaje solo cambia los estimulos y lee el estado.
Uso:  python fly_server.py [--port 9009] [--speed 1.0]
"""
import argparse, json, socket, threading, time
import numpy as np
import fly_sim as fs, fly_circuits as fc, os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "datos", "Drosophila_brain_model")
ANN = os.path.join(HERE, "datos", "flywire_annotations", "supplemental_files", "Supplemental_file1_neuron_annotations.tsv")
SLICE_MS = 10.0          # cada cuanto se leen las salidas
RATE_MAX = 150.0         # Hz Poisson con amenaza maxima (looming)
RATE_ORN = 100.0         # Hz Poisson con olor maximo en todas las neuronas olfativas de esa antena
ALPHA = 0.06              # suavizado de las tasas (constante ~100 ms de cerebro)
OLF_STEER = 1.8          # fuerza del giro hacia el olor (lector aprendido; derecha = girar a la derecha)
DN_NORM_HZ, GF_NORM_HZ = 5500.0, 250.0
PX_FULL_HZ = 80.0        # tasa media de una casilla del mapa que se pinta al maximo (escala de raiz: lo debil tambien se ve)

# ---- DROGAS (simulacion cualitativa, reversible) -------------------------------------------------------------
# Cada droga cambia la fuerza de las sinapsis segun el NEUROTRANSMISOR de la neurona presinaptica (anotaciones FlyWire, top_nt)
# y/o anade un ruido Poisson de fondo a todas las neuronas. "level" 0..1 (dosis x curva de efecto): factor = 1 + level*(f-1).
# En level 0 se restauran EXACTAMENTE los pesos originales (copia base) y el ruido a 0: la mosca vuelve a su actividad normal.
NT_CLASS = {"acetylcholine": "ach", "glutamate": "glu", "gaba": "gaba", "dopamine": "da", "serotonin": "ser", "octopamine": "oct"}
DRUGS = {
    # nombre: (factores por neurotransmisor a dosis 1, ruido de fondo Poisson en Hz a dosis 1)
    # El ruido de fondo es la palanca de la actividad motora: sin estimulos el cerebro esta en silencio (fwd 0), y 0.2 Hz ya da fwd ~0.5.
    "alcohol":    ({"gaba": 1.8, "ach": 0.8, "glu": 0.85}, 0.12),
    "cafeina":    ({"ach": 1.08, "gaba": 0.92, "da": 1.2}, 0.20),
    "cocaina":    ({"da": 2.5, "oct": 2.5, "ser": 1.6}, 0.45),
    "anfetamina": ({"da": 3.0, "oct": 3.0}, 0.80),
    "nicotina":   ({"ach": 1.15}, 0.25),
    "sedante":    ({"gaba": 2.2}, 0.0),
    "lsd":        ({"ser": 3.0, "glu": 1.1}, 0.20),
    "anestesico": ({"gaba": 2.8, "ach": 0.6}, 0.0),
}


# ---- LESIONES (reversibles) ------------------------------------------------------------------------------------
# Una lesion SILENCIA un grupo de neuronas: no pueden disparar (se las mantiene en periodo refractario y sin estimulo),
# asi que para el resto del cerebro es como si no estuvieran. No se toca ninguna sinapsis: al quitar la lesion las
# neuronas vuelven a su potencial de reposo y el cerebro queda EXACTAMENTE como antes. Se pueden combinar varias,
# y tambien con un compuesto.
# id: (nombre, selector sobre las anotaciones FlyWire)
LESIONS = {
    "orn_l":   ("Antena izquierda", lambda cls, typ, sup, side: (cls == "olfactory") & (side == "left")),
    "orn_r":   ("Antena derecha", lambda cls, typ, sup, side: (cls == "olfactory") & (side == "right")),
    "alpn":    ("Relevo olfativo", lambda cls, typ, sup, side: cls == "ALPN"),
    "loom_l":  ("Detector de amenaza izq.", lambda cls, typ, sup, side: (typ == "LPLC2") & (side == "left")),
    "loom_r":  ("Detector de amenaza der.", lambda cls, typ, sup, side: (typ == "LPLC2") & (side == "right")),
    "kc":      ("Cuerpos de hongo", lambda cls, typ, sup, side: cls == "Kenyon_Cell"),
    "cx":      ("Complejo central", lambda cls, typ, sup, side: cls == "CX"),
    "gf":      ("Fibra gigante", lambda cls, typ, sup, side: typ == "DNp01"),
    "dn":      ("Todas las descendentes", lambda cls, typ, sup, side: sup == "descending"),
}
GRID_W, GRID_H = 60, 26      # mapa del cerebro (vista frontal) para el panel "cerebro en vivo"
B36 = np.array(list("0123456789abcdefghijklmnopqrstuvwxyz"))


class Server:
    def __init__(self, speed=1.0):
        self.b = fs.Brain(REPO, ANN)
        m = self.b.meta
        cls = m.cell_class.fillna("").values; typ = m.cell_type.fillna("").values; side = m.side.fillna("").values
        S = lambda types, sd: np.nonzero(np.isin(typ, types) & (side == sd))[0]
        self.orn = [np.nonzero((cls == "olfactory") & (side == "left"))[0], np.nonzero((cls == "olfactory") & (side == "right"))[0]]
        self.loom = [S(["LPLC2"], "left"), S(["LPLC2"], "right")]
        self.dn = lambda name, sd: S([name], sd)
        d = {k: [S([k], "left"), S([k], "right")] for k in ["DNa01", "DNa02", "DNa03", "DNp01"]}
        self.d = d
        isdn = (m.super_class == "descending").values
        self.all_dn = np.nonzero(isdn)[0]
        for sets in (self.orn, self.loom):
            for s in sets: self.b.nref[s] = 0
        # grupos para el panel (80 casillas, mismo orden que FlyBrain)
        gid = np.full(self.b.n, -1, np.int16)
        gid[self.orn[0]] = 0; gid[self.orn[1]] = 1; gid[self.loom[0]] = 2; gid[self.loom[1]] = 3
        alpn = np.nonzero(cls == "ALPN")[0]; gid[alpn] = 5 + (np.arange(len(alpn)) % 8)
        kc = np.nonzero(cls == "Kenyon_Cell")[0]; self.kc = kc; gid[kc] = 13 + (np.arange(len(kc)) % 60)
        mb = np.nonzero(cls == "MBON")[0]
        gid[mb[side[mb] == "left"]] = 73; gid[mb[side[mb] == "right"]] = 74
        for k in ("DNa01", "DNa02"):
            gid[d[k][0]] = 75; gid[d[k][1]] = 76
        gid[self.all_dn[gid[self.all_dn] < 0]] = 77
        gid[d["DNp01"][0]] = 78; gid[d["DNp01"][1]] = 79
        self.gid = gid
        self.gsize = np.maximum(1, np.bincount(gid[gid >= 0], minlength=80)).astype(np.float32)
        # lectores de giro aprendidos con calibrate.py (pesos sobre las neuronas descendentes)
        dec = np.load(os.path.join(os.path.dirname(os.path.abspath(__file__)), "decoders.npz"))
        self.dn_idx = dec["dn_idx"]; self.wv, self.wo = dec["vision_w"], dec["olfato_w"]
        self.sv, self.so = float(dec["vision_scale"]), float(dec["olfato_scale"])
        self.bv, self.bo = float(dec["vision_bias"]), float(dec["olfato_bias"])
        # --- drogas: indices de sinapsis por neurotransmisor presinaptico + copia base de los pesos ---
        nt = m.top_nt.fillna("").map(NT_CLASS).fillna("").values if "top_nt" in m.columns else np.full(self.b.n, "")
        rows = np.repeat(np.arange(self.b.n, dtype=np.int32), np.diff(self.b.indptr).astype(np.int64))
        self.base_w = self.b.data.copy()
        self.nt_syn = {k: np.nonzero(nt[rows] == k)[0] for k in set(NT_CLASS.values())}
        del rows
        self.bg = np.zeros(self.b.n, np.float32)
        self.drug = None
        self.drug_level = 0.0
        # --- lesiones: indices de cada grupo ---
        sup = m.super_class.fillna("").values
        self.les_idx = {k: np.nonzero(sel(cls, typ, sup, side))[0] for k, (_, sel) in LESIONS.items()}
        self.les = np.zeros(0, np.int64)       # neuronas silenciadas ahora mismo
        self.lesion = []                       # ids activos
        self.les_v = 1                         # version (sube con cada cambio; el juego la usa para pedir el mapa)
        # --- mapa del cerebro: cada neurona cae en una casilla segun su posicion real (vista frontal: x = lado, y = altura) ---
        px = m.pos_x.astype(float).values; py = m.pos_y.astype(float).values
        ok = np.isfinite(px) & np.isfinite(py)
        x0, x1 = np.percentile(px[ok], [0.2, 99.8]); y0, y1 = np.percentile(py[ok], [0.2, 99.8])
        gx = np.clip(np.nan_to_num((px - x0) / (x1 - x0) * GRID_W), 0, GRID_W - 1).astype(np.int64)
        gy = np.clip(np.nan_to_num((py - y0) / (y1 - y0) * GRID_H), 0, GRID_H - 1).astype(np.int64)
        cell = np.where(ok, gy * GRID_W + gx, -1)
        self.cell = cell
        self.cell_b = np.where(ok, cell, GRID_W * GRID_H)      # las (pocas) neuronas sin posicion van a una casilla aparte que no se pinta
        self.cell_n = np.bincount(cell[cell >= 0], minlength=GRID_W * GRID_H).astype(np.float32)
        print("mapa: ancho/alto real del cerebro = %.2f" % ((x1 - x0) / (y1 - y0)), flush=True)
        self.pxv = np.zeros(GRID_W * GRID_H, np.float32)
        self.hz_all = 0.0
        self.view = np.zeros(80, np.float32)
        self.est = {"va": 0.0, "oa": 0.0, "dn": 0.0, "gf": 0.0, "kc": 0.0}
        self.stim = (0.0, 0.0, 0.0, 0.0, 0.0)
        self.hunger = 0.0
        self.reset_flag = False
        self.speed = speed
        self.lock = threading.Lock()
        self.t_ms = 0.0
        self.run = True

    def set_drug(self, name, level):
        """Aplica (o retira) una droga. level<=0 o nombre desconocido -> pesos y ruido EXACTAMENTE como al inicio."""
        level = float(max(0.0, min(1.5, level)))
        spec = DRUGS.get(name) if name else None
        if spec is None or level <= 0.001:
            if self.drug is not None:
                self.b.data[:] = self.base_w
                self.bg[:] = 0.0
                self.b.rates[:] = 0.0          # el bucle vuelve a fijar los estimulos de olor/amenaza en el siguiente paso
                self.reset_flag = True         # apaga la actividad que haya quedado: el cerebro arranca limpio, como sin droga
            self.drug, self.drug_level = None, 0.0
            return
        facs, noise = spec
        self.b.data[:] = self.base_w
        for k, f in facs.items():
            idx = self.nt_syn.get(k)
            if idx is not None and len(idx):
                self.b.data[idx] = self.base_w[idx] * np.float32(1.0 + level * (f - 1.0))
        self.bg[:] = np.float32(noise * level)
        self.drug, self.drug_level = name, level

    def set_lesion(self, ids):
        """Fija las lesiones activas (lista de ids de LESIONS). Lista vacia = cerebro sano, exactamente como al inicio."""
        ids = sorted(set(str(i) for i in (ids or []) if str(i) in self.les_idx))
        if ids == self.lesion:
            return
        new = np.unique(np.concatenate([self.les_idx[i] for i in ids])) if ids else np.zeros(0, np.int64)
        libres = np.setdiff1d(self.les, new)
        b = self.b
        b.ref[libres] = 0; b.v[libres] = b.P["v0"]; b.g[libres] = 0     # las neuronas liberadas vuelven al reposo
        self.les, self.lesion = new, ids
        self.les_v += 1
        if not ids:
            self.reset_flag = True          # cerebro sano: arranca limpio, sin restos de la actividad alterada

    def grid(self):
        """Mapa para el panel: densidad de neuronas por casilla y casillas lesionadas (una letra 0-9a-z por casilla)."""
        dens = np.clip(np.log1p(self.cell_n) / np.log1p(600.0), 0, 1)
        lm = np.zeros(GRID_W * GRID_H, np.float32)
        if len(self.les):
            c = self.cell[self.les]; c = c[c >= 0]
            lm = np.bincount(c, minlength=GRID_W * GRID_H) / np.maximum(1.0, self.cell_n)
        enc = lambda a: "".join(B36[np.round(np.clip(a, 0, 1) * 35).astype(int)])
        return {"w": GRID_W, "h": GRID_H, "dens": enc(dens), "les": enc(np.sqrt(lm)), "ids": list(self.lesion)}

    def hz(self, counts, idx):
        return float(counts[idx].sum()) / max(1, len(idx)) / (SLICE_MS / 1000.0)

    def loop(self):
        """Hilo del cerebro: avanza SLICE_MS, actualiza estimulos y salidas suavizadas; limita a 'speed' x tiempo real."""
        b = self.b
        while self.run:
            t0 = time.time()
            with self.lock:
                ol, orr, ll, lr, h = self.stim; hunger = self.hunger
                if self.reset_flag:
                    b.v[:] = b.P["v0"]; b.g[:] = 0; b.ref[:] = 0; b.ring[:] = 0; b.ring_n[:] = 0; self.reset_flag = False   # (tambien vacia los spikes en transito: si no, la actividad se auto-mantiene)
            gain = 1.0 + 0.5 * hunger          # hambrienta: responde mas al olor
            if self.drug is not None: b.rates[:] = self.bg      # ruido de fondo de la droga (solo si hay droga activa)
            b.rates[self.orn[0]] = RATE_ORN * min(1.0, gain * ol / 0.8)
            b.rates[self.orn[1]] = RATE_ORN * min(1.0, gain * orr / 0.8)
            b.rates[self.loom[0]] = RATE_MAX * min(1.0, ll / 0.9)
            b.rates[self.loom[1]] = RATE_MAX * min(1.0, lr / 0.9)
            les = self.les
            if len(les):                          # lesion: esas neuronas no reciben estimulo ni pueden disparar
                b.rates[les] = 0; b.ref[les] = 30000; b.v[les] = b.P["vrst"]; b.g[les] = 0
            c = b.advance(SLICE_MS)
            self.t_ms += SLICE_MS
            d = self.d
            # lectores de giro: puntuacion > 0 = el estimulo esta a la derecha (calibrados con el propio conectoma)
            cdn = c[self.dn_idx] / (SLICE_MS / 1000.0)
            va = float(cdn @ self.wv) / self.sv - self.bv
            oa = float(cdn @ self.wo) / self.so - self.bo
            dn = float(c[self.all_dn].sum()) / (SLICE_MS / 1000.0)
            gf = 0.5 * (self.hz(c, d["DNp01"][0]) + self.hz(c, d["DNp01"][1]))
            kc = float((c[self.kc] > 0).mean())
            e = self.est
            for k, v in (("va", va), ("oa", oa), ("dn", dn), ("gf", gf), ("kc", kc)):
                e[k] += ALPHA * (v - e[k])
            gs = np.bincount(self.gid[self.gid >= 0], weights=c[self.gid >= 0], minlength=80) / self.gsize / (SLICE_MS / 1000.0)
            self.view += ALPHA * (np.clip(gs / 200.0, 0, 1) * 0.2 - self.view)
            # mapa del cerebro: tasa media (Hz) de las neuronas de cada casilla, y disparos/s de todo el cerebro
            pr = np.bincount(self.cell_b, weights=c, minlength=GRID_W * GRID_H + 1)[:-1] / np.maximum(1.0, self.cell_n) / (SLICE_MS / 1000.0)
            self.pxv += 0.12 * (pr - self.pxv)
            self.hz_all += 0.12 * (float(c.sum()) / (SLICE_MS / 1000.0) - self.hz_all)
            used = time.time() - t0
            wait = SLICE_MS / 1000.0 / self.speed - used
            if wait > 0: time.sleep(wait)

    def reply(self):
        e = self.est
        # Giro = huida de la amenaza (el lector da amenaza a la derecha -> se gira a la izquierda) + acercamiento al olor. El acercamiento compara la intensidad en las dos antenas
        # (tropotaxis) y solo actua si el cerebro real esta activado (fwd): el lector olfativo (calibrate_olfato.py) se entreno con las intensidades y asimetrias reales del juego.
        ol, orr, ll, lr = self.stim[0], self.stim[1], self.stim[2], self.stim[3]
        gv = min(1.0, max(ll, lr) / 0.3)          # el lector visual solo cuenta si hay amenaza
        go = min(1.0, max(ol, orr) / 0.15)        # el lector olfativo solo cuenta si hay olor
        act = min(1.0, e["dn"] / 150.0)           # sin actividad en las neuronas descendentes no hay orden de giro (los lectores solo darian su sesgo)
        turn = float(np.clip(-gv * np.clip(e["va"], -1, 1) + go * OLF_STEER * np.clip(e["oa"], -1, 1), -1, 1)) * act
        v = self.view.copy(); v[4] = self.hunger * 0.1
        px = "".join(B36[np.round(np.clip(np.sqrt(self.pxv / PX_FULL_HZ), 0, 1) * 35).astype(int)])
        return {"turn": turn, "fwd": float(np.clip(e["dn"] / DN_NORM_HZ, 0, 1)), "gf": float(np.clip(e["gf"] / GF_NORM_HZ, 0, 1)),
                "kc": e["kc"], "raw": {k: round(float(v), 2) for k, v in e.items()}, "view": [round(float(x), 4) for x in v], "t_ms": self.t_ms,
                "hz": round(self.hz_all), "px": px, "lv": self.les_v}

    def handle(self, conn):
        f = conn.makefile("rwb")
        for line in f:
            try:
                q = json.loads(line)
            except Exception:
                continue
            with self.lock:
                o = q.get("orn", [0, 0]); l = q.get("loom", [0, 0])
                self.stim = (float(o[0]), float(o[1]), float(l[0]), float(l[1]), 0.0)
                self.hunger = float(q.get("hunger", 0.0))
                if q.get("reset"): self.reset_flag = True
                if "drug" in q:
                    dq = q["drug"]
                    if dq: self.set_drug(str(dq.get("name", "")), float(dq.get("level", 0.0)))
                    else: self.set_drug(None, 0.0)
                if "lesion" in q:
                    self.set_lesion(q["lesion"])
                r = self.reply()
                if q.get("map"): r["grid"] = self.grid()
            f.write((json.dumps(r) + "\n").encode()); f.flush()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9009)
    ap.add_argument("--speed", type=float, default=1.0, help="velocidad del cerebro respecto al tiempo real (max segun tu CPU)")
    a = ap.parse_args()
    srv = Server(a.speed)
    threading.Thread(target=srv.loop, daemon=True).start()
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", a.port)); s.listen(4)
    s.settimeout(1.0)     # en Windows un accept() sin limite de tiempo no deja pasar Ctrl+C; asi vuelve a Python cada segundo
    print(f"Cerebro listo: {srv.b.n} neuronas. Escuchando en 127.0.0.1:{a.port}  (Ctrl+C para cerrar)", flush=True)
    try:
        while True:
            try:
                c, _ = s.accept()
            except socket.timeout:
                continue
            c.settimeout(None)
            threading.Thread(target=srv.handle, args=(c,), daemon=True).start()
    except KeyboardInterrupt:
        print("\nCerrando el cerebro...", flush=True)
    finally:
        srv.run = False
        s.close()


if __name__ == "__main__":
    main()
