#!/usr/bin/env python3
"""
Esculpe cabezas de personajes con campos de distancia (SDF) y las convierte en malla
low-poly con marching cubes. Salida: assets/models/head_*.mdl (+ .json con los ojos).

Formato .mdl (texto):  v x y z r g b   /   f a b c   (índices desde 1, ya con el orden
de caras que usa Godot: sentido horario visto desde fuera).
Marco: +Y arriba, el personaje mira hacia -Z.  Origen = centro del cráneo.

Uso:  python tools/gen_models.py
"""
import json
import os
import numpy as np
from skimage import measure

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
os.makedirs(OUT, exist_ok=True)


# ----------------------------------------------------------------- primitivas
def V(*a):
    return np.array(a, np.float32)


def ell(P, c, r):
    c, r = V(*c), V(*r)
    return (np.linalg.norm((P - c) / r, axis=-1) - 1.0) * float(min(r))


def rcone(P, a, b, ra, rb):
    a, b = V(*a), V(*b)
    ba = b - a
    t = np.clip(((P - a) @ ba) / float(ba @ ba), 0, 1)
    return np.linalg.norm(P - (a + t[..., None] * ba), axis=-1) - (ra + (rb - ra) * t)


def box(P, c, h, r=0.0):
    q = np.abs(P - V(*c)) - V(*h) + r
    return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(axis=-1), 0) - r


def smin(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def sub(d, s, k=0.01):
    return smax(d, -s, k)


# --------------------------------------------------------------------- cabezas
def wolf(P):
    d = ell(P, (0, 0, .02), (.125, .115, .135))
    d = smin(d, rcone(P, (0, -.015, -.09), (0, -.035, -.30), .072, .040), .05)
    d = smin(d, rcone(P, (0, -.07, -.07), (0, -.088, -.27), .045, .026), .03)
    d = smin(d, ell(P, (0, -.022, -.325), (.04, .032, .035)), .02)
    d = smin(d, ell(P, (0, -.11, .06), (.13, .085, .12)), .05)
    for s in (-1, 1):
        d = smin(d, ell(P, (s * .105, -.045, -.025), (.05, .05, .075)), .05)
        d = smin(d, rcone(P, (s * .035, .06, -.115), (s * .105, .078, -.04), .022, .018), .02)
        d = smin(d, rcone(P, (s * .07, .085, .04), (s * .125, .30, .075), .04, .008), .03)
        d = sub(d, ell(P, (s * .085, .17, .015), (.026, .095, .03)), .012)
        d = sub(d, ell(P, (s * .072, .03, -.105), (.03, .022, .03)), .012)
    return d


def wolf_color(p):
    x, y, z = p
    fur = V(.40, .52, .42)
    if z < -.285 and y > -.07:
        return V(.07, .06, .07)
    if y < -.065 and z < -.04:
        return V(.62, .70, .62)
    if y > .13 and abs(x) > .05 and z > -.02:
        return V(.62, .50, .50) if abs(x) < .125 and z < .075 and y < .27 else V(.16, .2, .18)
    return fur * (0.85 + 0.25 * np.clip((y + .1) / .3, 0, 1))


def owl(P):
    d = ell(P, (0, 0, 0), (.15, .145, .14))
    for s in (-1, 1):
        d = smin(d, ell(P, (s * .07, 0, -.1), (.085, .095, .04)), .03)
        d = smin(d, rcone(P, (s * .02, .085, -.12), (s * .12, .06, -.09), .02, .02), .02)
        d = smin(d, rcone(P, (s * .09, .1, 0), (s * .13, .27, .01), .03, .008), .03)
        d = sub(d, ell(P, (s * .07, .01, -.125), (.042, .042, .03)), .012)
    d = smin(d, rcone(P, (0, -.025, -.13), (0, -.09, -.195), .03, .006), .015)
    d = smin(d, ell(P, (0, -.12, .02), (.13, .06, .11)), .05)
    return d


def owl_color(p):
    x, y, z = p
    if z < -.15 and y < -.02 and abs(x) < .04:
        return V(.2, .15, .1)
    if z < -.085 and (np.hypot(abs(x) - .07, y) < .095):
        return V(.86, .84, .78)
    if y > .13:
        return V(.35, .32, .3)
    return V(.62, .6, .56) * (0.85 + 0.25 * np.clip((y + .1) / .3, 0, 1))


def goat(P):
    d = ell(P, (0, 0, 0), (.10, .105, .12))
    d = smin(d, rcone(P, (0, -.02, -.08), (0, -.045, -.27), .065, .045), .05)
    d = smin(d, ell(P, (0, -.035, -.285), (.05, .04, .035)), .02)
    d = smin(d, rcone(P, (0, -.075, -.08), (0, -.085, -.26), .04, .026), .03)
    d = smin(d, rcone(P, (0, -.085, -.2), (0, -.2, -.19), .018, .006), .02)
    for s in (-1, 1):
        d = smin(d, ell(P, (s * .19, .035, .03), (.10, .014, .045)), .02)
        pts = [(s * (.06 + .1 * np.sin(t * 1.9)), .08 + .22 * t, .03 + .16 * t * t) for t in np.linspace(0, 1, 7)]
        for i in range(6):
            d = smin(d, rcone(P, pts[i], pts[i + 1], .034 - .004 * i, .034 - .004 * (i + 1)), .01)
        d = smin(d, rcone(P, (s * .03, .08, -.09), (s * .09, .09, -.05), .018, .016), .02)
        d = sub(d, ell(P, (s * .07, .035, -.075), (.028, .02, .03)), .01)
    return d


def goat_color(p):
    x, y, z = p
    if z < -.3 and y > -.08:
        return V(.1, .09, .09)
    if y > .1 and z > -.05 and abs(x) > .04 and y > .1 + 0.0:
        if p[1] > .1 and np.hypot(x, p[2]) > .07 and y > .12:
            return V(.82, .78, .64)
    if y < -.1:
        return V(.58, .56, .52)
    return V(.80, .80, .78) * (0.85 + 0.2 * np.clip((y + .1) / .3, 0, 1))


def ogre(P):
    d = ell(P, (0, 0, 0), (.22, .20, .22))
    d = smin(d, rcone(P, (-.2, .1, -.14), (.2, .1, -.14), .05, .05), .04)
    d = smin(d, ell(P, (0, -.14, -.10), (.17, .09, .14)), .05)
    d = smin(d, ell(P, (0, -.02, -.23), (.07, .06, .07)), .03)
    for s in (-1, 1):
        d = smin(d, ell(P, (s * .14, -.04, -.12), (.07, .07, .08)), .04)
        d = smin(d, rcone(P, (s * .2, .04, 0), (s * .5, .16, 0), .05, .01), .03)
        d = smin(d, rcone(P, (s * .09, -.13, -.2), (s * .1, -.01, -.22), .02, .006), .01)
        d = sub(d, ell(P, (s * .09, .055, -.185), (.05, .04, .04)), .012)
        d = sub(d, ell(P, (s * .028, -.035, -.285), (.014, .012, .014)), .005)
    d = sub(d, box(P, (0, -.118, -.2), (.06, .008, .06), 0.004), .006)
    for wx, wy, wz in [(.12, .1, -.15), (-.18, -.02, -.14), (.05, .17, -.1)]:
        d = smin(d, ell(P, (wx, wy, wz), (.02, .02, .02)), .01)
    return d


def ogre_color(p):
    x, y, z = p
    g = V(.36, .46, .13)
    if abs(x) > .085 and y < .0 and y > -.14 and z < -.19 and np.hypot(abs(x) - .095, y + .07) < .07:
        return V(.92, .87, .7)
    if y > .17:
        return V(.20, .5, .15)
    if abs(x) > .27:
        return g * .8
    if y < -.1:
        return g * .78
    return g * (0.85 + 0.25 * np.clip((y + .1) / .3, 0, 1))


HEADS = {
    "head_wolf": dict(fn=wolf, col=wolf_color, lo=(-.22, -.19, -.42), hi=(.22, .36, .20), step=.013,
                      eyes=[[-.072, .03, -.105, .03], [.072, .03, -.105, .03]], eye_color=[0.85, 0.95, 1.0], eye_emit=3.2),
    "head_owl": dict(fn=owl, col=owl_color, lo=(-.20, -.19, -.26), hi=(.20, .33, .18), step=.012,
                     eyes=[[-.07, .01, -.125, .045], [.07, .01, -.125, .045]], eye_color=[1.0, 0.55, 0.05], eye_emit=2.6),
    "head_goat": dict(fn=goat, col=goat_color, lo=(-.34, -.26, -.34), hi=(.34, .40, .20), step=.013,
                      eyes=[[-.07, .035, -.075, .03], [.07, .035, -.075, .03]], eye_color=[1.0, 0.75, 0.15], eye_emit=2.2),
    "head_ogre": dict(fn=ogre, col=ogre_color, lo=(-.58, -.30, -.40), hi=(.58, .30, .26), step=.018,
                      eyes=[[-.09, .055, -.185, .042], [.09, .055, -.185, .042]], eye_color=[0.2, 0.95, 0.8], eye_emit=2.6),
}


def build(name, h):
    lo, hi, st = np.array(h["lo"], np.float32), np.array(h["hi"], np.float32), h["step"]
    ax = [np.arange(lo[i], hi[i] + st, st, dtype=np.float32) for i in range(3)]
    X, Y, Z = np.meshgrid(*ax, indexing="ij")
    P = np.stack([X, Y, Z], axis=-1)
    d = h["fn"](P)
    d[0, :, :] = d[-1, :, :] = d[:, 0, :] = d[:, -1, :] = d[:, :, 0] = d[:, :, -1] = 1.0
    verts, faces, _, _ = measure.marching_cubes(d, 0.0, spacing=(st, st, st), gradient_direction="ascent")
    verts = verts + lo
    # skimage con gradient_direction="ascent" ya da el orden horario que usa Godot
    cols = np.array([h["col"](v) for v in verts], np.float32)
    path = os.path.join(OUT, name + ".mdl")
    with open(path, "w") as f:
        for v, c in zip(verts, cols):
            f.write("v %.4f %.4f %.4f %.3f %.3f %.3f\n" % (v[0], v[1], v[2], c[0], c[1], c[2]))
        for tri in faces:
            f.write("f %d %d %d\n" % (tri[0] + 1, tri[1] + 1, tri[2] + 1))
    meta = {"eyes": h["eyes"], "eye_color": h["eye_color"], "eye_emit": h["eye_emit"]}
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(meta, f)
    print(f"{name}: {len(verts)} vértices, {len(faces)} triángulos")


if __name__ == "__main__":
    for n, h in HEADS.items():
        build(n, h)
