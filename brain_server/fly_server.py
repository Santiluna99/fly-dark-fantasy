#!/usr/bin/env python3
"""
Servidor del cerebro real de la mosca para Godot (conectoma FlyWire v783, 138.639 neuronas).

Protocolo: TCP en localhost, un JSON por linea (UTF-8).
  Godot -> servidor:  {"orn":[izq,der], "loom":[izq,der], "hunger":h, "reset":false}
        orn  = intensidad de olor de fruta en cada antena (0..0.8)    loom = amenaza a cada lado (0..0.9)   hunger = 0..1
  servidor -> Godot:  {"turn":-1..1, "fwd":0..1, "gf":0..1, "kc":fraccion, "view":[80 valores], "t_ms":tiempo del cerebro}
        turn > 0 = girar a la DERECHA.   view = actividad agrupada para el panel neuronal (mismo orden que FlyBrain).

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
        self.view = np.zeros(80, np.float32)
        self.est = {"va": 0.0, "oa": 0.0, "dn": 0.0, "gf": 0.0, "kc": 0.0}
        self.stim = (0.0, 0.0, 0.0, 0.0, 0.0)
        self.hunger = 0.0
        self.reset_flag = False
        self.speed = speed
        self.lock = threading.Lock()
        self.t_ms = 0.0
        self.run = True

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
                    b.v[:] = b.P["v0"]; b.g[:] = 0; b.ref[:] = 0; self.reset_flag = False
            gain = 1.0 + 0.5 * hunger          # hambrienta: responde mas al olor
            b.rates[self.orn[0]] = RATE_ORN * min(1.0, gain * ol / 0.8)
            b.rates[self.orn[1]] = RATE_ORN * min(1.0, gain * orr / 0.8)
            b.rates[self.loom[0]] = RATE_MAX * min(1.0, ll / 0.9)
            b.rates[self.loom[1]] = RATE_MAX * min(1.0, lr / 0.9)
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
        turn = float(np.clip(-gv * np.clip(e["va"], -1, 1) + go * OLF_STEER * np.clip(e["oa"], -1, 1), -1, 1))
        v = self.view.copy(); v[4] = self.hunger * 0.1
        return {"turn": turn, "fwd": float(np.clip(e["dn"] / DN_NORM_HZ, 0, 1)), "gf": float(np.clip(e["gf"] / GF_NORM_HZ, 0, 1)),
                "kc": e["kc"], "raw": {k: round(float(v), 2) for k, v in e.items()}, "view": [round(float(x), 4) for x in v], "t_ms": self.t_ms}

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
            f.write((json.dumps(self.reply()) + "\n").encode()); f.flush()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9009)
    ap.add_argument("--speed", type=float, default=1.0, help="velocidad del cerebro respecto al tiempo real (max segun tu CPU)")
    a = ap.parse_args()
    srv = Server(a.speed)
    threading.Thread(target=srv.loop, daemon=True).start()
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", a.port)); s.listen(4)
    print(f"Cerebro listo: {srv.b.n} neuronas. Escuchando en 127.0.0.1:{a.port}", flush=True)
    while True:
        c, _ = s.accept()
        threading.Thread(target=srv.handle, args=(c,), daemon=True).start()


if __name__ == "__main__":
    main()
