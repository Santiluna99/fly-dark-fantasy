#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""
Motor del cerebro real (conectoma FlyWire v783, 138.639 neuronas) con estado persistente y bucle compilado con numba.

Mismo modelo LIF que fly_circuits.py (parametros de Shiu et al. 2023) pero:
  - el estado (voltajes, conductancias, spikes pendientes) se conserva entre llamadas: es un cerebro que "vive" continuamente
  - la estimulacion es un array de tasas Poisson por neurona (Hz), que cambia en cualquier momento
  - paso de 0.5 ms (el original usa 0.1 ms) para ir mas rapido; el retardo sinaptico y el refractario se redondean a ese paso
"""
import numpy as np, numba as nb
import fly_circuits as fc, fly_fixes as ff

DT = 0.5   # ms por paso

@nb.njit(cache=True)
def _run(nsteps, v, g, ref, nref, rates_hz, indptr, indices, data, ring, ring_n, pos, dly, counts, seed_state,
         v0, vth, vrst, tmbr, tau, kick, dt):
    """Avanza nsteps pasos. ring[slot, :ring_n[slot]] = indices de neuronas que dispararon hace 'dly' pasos."""
    n = v.shape[0]
    stim_idx = np.nonzero(rates_hz > 0)[0]
    for _ in range(nsteps):
        slot = pos % dly
        # 1) entrega los spikes con retardo: suma sus pesos a la conductancia de las postsinapticas
        for q in range(ring_n[slot]):
            a = ring[slot, q]
            for k in range(indptr[a], indptr[a + 1]):
                g[indices[k]] += data[k]
        ring_n[slot] = 0
        # 2) estimulacion Poisson
        for q in range(stim_idx.shape[0]):
            i = stim_idx[q]
            lam = rates_hz[i] * dt / 1000.0
            if np.random.random() < lam:
                v[i] += kick
        # 3) integra, decae, dispara
        for i in range(n):
            if ref[i] <= 0:
                v[i] += dt * (v0 - v[i] + g[i]) / tmbr
                g[i] -= dt * g[i] / tau
            else:
                ref[i] -= 1
            if v[i] > vth:
                ring[slot, ring_n[slot]] = i
                ring_n[slot] += 1
                v[i] = vrst
                g[i] = 0.0
                ref[i] = nref[i]
                counts[i] += 1
        pos += 1
    return pos


class Brain:
    def __init__(self, repo, ann, profile=True, seed=0):
        W, self.meta = fc.load(repo, ann)
        if profile:
            W = ff.olfactory_profile(W, self.meta)   # arreglo de olfato (ver fly_fixes.py)
        W = W.tocsr()
        self.n = W.shape[0]
        self.indptr = W.indptr.astype(np.int64); self.indices = W.indices.astype(np.int32); self.data = W.data.astype(np.float32)
        P = fc.P
        self.v = np.full(self.n, P["v0"], np.float32); self.g = np.zeros(self.n, np.float32)
        self.ref = np.zeros(self.n, np.int16)
        self.nref = np.full(self.n, int(round(P["trfc"] / DT)), np.int16)
        self.dly = max(1, int(round(P["tdly"] / DT)))
        self.ring = np.zeros((self.dly, 40000), np.int32); self.ring_n = np.zeros(self.dly, np.int64)
        self.pos = 0
        self.counts = np.zeros(self.n, np.int32)
        self.rates = np.zeros(self.n, np.float32)
        np.random.seed(seed)
        self.P = P

    def set_stim(self, idx, rate_hz):
        """Fija la tasa Poisson (Hz) de las neuronas idx (el resto de estimulos no se toca)."""
        self.rates[idx] = rate_hz
        self.nref[idx] = 0     # sin refractario en neuronas estimuladas (como en el paper)

    def clear_stim(self):
        self.rates[:] = 0

    def advance(self, ms):
        """Avanza 'ms' milisegundos del cerebro. Devuelve el numero de spikes por neurona en ese intervalo."""
        self.counts[:] = 0
        P = self.P
        self.pos = _run(int(round(ms / DT)), self.v, self.g, self.ref, self.nref, self.rates, self.indptr, self.indices,
                        self.data, self.ring, self.ring_n, self.pos, self.dly, self.counts, 0,
                        P["v0"], P["vth"], P["vrst"], P["tmbr"], P["tau"], P["wsyn"] * P["fpoi"], DT)
        return self.counts
