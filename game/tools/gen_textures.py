#!/usr/bin/env python3
# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""
Genera texturas 'pintadas' tileables (256x256) para Hollowfly.
Todas son periódicas (se repiten sin costuras): el ruido se filtra en frecuencia.

Uso:  python tools/gen_textures.py        -> assets/textures/*.png
"""
import os
import numpy as np
from PIL import Image

N = 256
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)


def fbm(beta=2.0, seed=0, aniso=(1.0, 1.0)):
    """Ruido periódico 1/f^beta (aniso: estira el ruido en x/y)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(N)[:, None] * aniso[1], np.fft.fftfreq(N)[None, :] * aniso[0]
    r = np.sqrt(f[0] ** 2 + f[1] ** 2)
    r[0, 0] = 1.0
    spec = (rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N))) / r ** (beta / 2.0)
    spec[0, 0] = 0
    a = np.real(np.fft.ifft2(spec))
    a = (a - a.min()) / (a.max() - a.min() + 1e-9)
    return a


def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    t = t[..., None] if t.ndim == 2 else t
    return a + (b - a) * t


def col(r, g, b):
    return np.array([r, g, b], np.float32) / 255.0


AGED = {"stone_brick", "rock", "grass", "dirt", "bark", "leaf", "plank", "slate"}   # texturas a las que se aplica el envejecido
CHUNKY = {"stone_brick", "rock", "dirt", "plank", "slate", "grass"}                  # se bajan a 128 px (píxel más grueso, estilo PS1)


def age(img, seed):
    """Envejecido dark fantasy: desatura, oscurece, añade churretes de suciedad (más abajo), manchas y moteado."""
    g = img.mean(axis=2, keepdims=True)
    img = g + (img - g) * 0.62                                  # menos saturación
    img = img * np.array([0.92, 1.0, 0.95], np.float32)         # tinte ceniza-verdoso
    streak = smooth(fbm(1.6, seed + 500, aniso=(7.0, 0.25)), 0.45, 0.85) * (0.35 + 0.65 * (yy / N))[..., None].squeeze()
    img = img * (1 - 0.55 * streak[..., None])                   # churretes verticales
    blot = smooth(fbm(2.4, seed + 600), 0.6, 0.85)
    img = img * (1 - 0.4 * blot[..., None])                      # manchas de humedad
    sp = (np.random.default_rng(seed).random((N, N)) > 0.97).astype(np.float32)
    img = img * (1 - 0.25 * sp[..., None])                       # moteado oscuro
    return img * 1.3


def save(name, img):
    if name in AGED:
        img = age(img, abs(sum(map(ord, name))) % 997)
    img = np.clip(img, 0, 1)
    im = Image.fromarray((img * 255).astype(np.uint8))
    if name in CHUNKY:
        im = im.resize((128, 128), Image.NEAREST)
    im.save(os.path.join(OUT, name + ".png"))
    print("ok", name)


def gray(a):
    return np.repeat(a[..., None], 3, axis=2)


yy, xx = np.mgrid[0:N, 0:N]


# --------------------------------------------------------------------- piedra
def stone_brick():
    rng = np.random.default_rng(3)
    img = np.zeros((N, N, 3), np.float32)
    pal = [col(120, 108, 74), col(98, 96, 78), col(132, 118, 84), col(86, 88, 76), col(110, 100, 90)]
    big = fbm(2.6, 11)
    fine = fbm(1.2, 12)
    rows = 8
    rh = N // rows
    shade = np.zeros((N, N), np.float32)
    mortar = np.zeros((N, N), np.float32)
    bevel = np.zeros((N, N), np.float32)
    for r in range(rows):
        # partición aleatoria del ancho en 3-4 ladrillos (suma = N, tileable)
        k = int(rng.integers(3, 5))
        cuts = np.sort(rng.choice(np.arange(24, N - 24, 8), k - 1, replace=False))
        edges = np.concatenate([[0], cuts, [N]])
        shift = int(rng.integers(0, N))
        y0, y1 = r * rh, (r + 1) * rh
        for i in range(k):
            x0, x1 = edges[i], edges[i + 1]
            c = pal[int(rng.integers(0, len(pal)))] * rng.uniform(0.8, 1.15)
            xs = (np.arange(x0, x1) + shift) % N
            for yy_ in range(y0, y1):
                img[yy_, xs] = c
            w = x1 - x0
            lx = np.arange(w)[None, :]
            ly = np.arange(rh)[:, None]
            m = (lx < 3) | (lx > w - 3) | (ly < 3) | (ly > rh - 3)
            b = np.clip(1 - np.minimum(np.minimum(lx, w - 1 - lx), np.minimum(ly, rh - 1 - ly)) / 8.0, 0, 1)
            top = (ly < 8).astype(np.float32) * 0.18 - (ly > rh - 9).astype(np.float32) * 0.22
            side = (lx < 6).astype(np.float32) * 0.1 - (lx > w - 7).astype(np.float32) * 0.1
            for j, yv in enumerate(range(y0, y1)):
                mortar[yv, xs] = m[j]
                bevel[yv, xs] = (top + side)[j] if top.shape[1] == w else 0
                shade[yv, xs] = b[j] * 0.25
    img = img * (0.62 + 0.75 * big[..., None]) * (0.85 + 0.3 * fine[..., None])
    img += bevel[..., None]
    img *= (1 - shade[..., None] * 0.6)
    # grietas
    cr = np.zeros((N, N), np.float32)
    for _ in range(14):
        x, y = rng.integers(0, N), rng.integers(0, N)
        for _ in range(int(rng.integers(20, 60))):
            cr[y % N, x % N] = 1
            x += int(rng.integers(-1, 2))
            y += int(rng.integers(0, 2)) if rng.random() < 0.7 else int(rng.integers(-1, 1))
    img *= (1 - 0.55 * cr[..., None])
    mo = col(34, 30, 24) * (0.7 + 0.6 * fine[..., None])
    img = np.where(mortar[..., None] > 0.5, mo, img)
    # musgo
    mg = smooth(fbm(2.2, 21) * 0.6 + (1 - yy / N) * 0.35 * (fbm(2.4, 22)), 0.62, 0.8)
    moss = col(44, 70, 36) * (0.6 + 0.8 * fine[..., None])
    img = lerp(img, moss, mg * 0.8)
    save("stone_brick", img)


def rock():
    warp = fbm(3.0, 31)
    band = np.sin((yy / N * 14 + warp * 4.0) * np.pi) * 0.5 + 0.5
    band2 = np.sin((yy / N * 33 + fbm(2.4, 32) * 3.0) * np.pi) * 0.5 + 0.5
    a = col(70, 68, 82)
    b = col(128, 104, 70)
    c = col(46, 46, 58)
    img = lerp(a, b, band)
    img = lerp(img, c, smooth(band2, 0.6, 0.9) * 0.5)
    n = fbm(1.8, 33)
    img *= (0.7 + 0.6 * n[..., None])
    # fisuras verticales
    cr = smooth(np.abs(fbm(2.6, 34, aniso=(2.5, 0.6)) - 0.5), 0.0, 0.03)
    img *= (0.45 + 0.55 * cr[..., None])
    save("rock", img)


def grass():
    base = fbm(2.2, 41)
    img = lerp(col(34, 62, 24), col(88, 108, 40), smooth(base, 0.3, 0.8))
    blades = fbm(1.4, 42, aniso=(2.0, 0.5))
    img *= (0.65 + 0.7 * blades[..., None])
    dark = smooth(fbm(2.8, 43), 0.6, 0.8)
    img = lerp(img, col(20, 36, 18), dark * 0.5)
    sprinkle = (np.random.default_rng(5).random((N, N)) > 0.996).astype(np.float32)
    img = lerp(img, col(190, 170, 70), sprinkle * 0.8)
    save("grass", img)


def dirt():
    n = fbm(2.0, 51)
    img = lerp(col(70, 52, 36), col(116, 92, 62), n)
    peb = fbm(0.9, 52)
    p = smooth(peb, 0.8, 0.9)
    img = lerp(img, col(120, 118, 112), p * 0.7)
    img *= (0.75 + 0.5 * fbm(1.4, 53)[..., None])
    save("dirt", img)


def bark():
    s = fbm(1.8, 61, aniso=(4.0, 0.35))
    img = lerp(col(34, 24, 18), col(92, 68, 46), smooth(s, 0.25, 0.75))
    groove = smooth(fbm(2.0, 62, aniso=(5.0, 0.3)), 0.62, 0.74)
    img = lerp(img, col(14, 10, 8), groove * 0.7)
    img = lerp(img, col(56, 92, 40), smooth(fbm(2.6, 63), 0.72, 0.85) * 0.45)
    save("bark", img)


def leaf():
    n = fbm(1.3, 71)
    img = lerp(col(18, 52, 32), col(54, 110, 54), smooth(n, 0.3, 0.8))
    strokes = fbm(1.0, 72, aniso=(1.5, 1.5))
    img *= (0.6 + 0.8 * strokes[..., None])
    img = lerp(img, col(110, 120, 40), smooth(fbm(2.2, 73), 0.78, 0.9) * 0.4)
    save("leaf", img)


def plank():
    rows = 8
    rh = N // rows
    rng = np.random.default_rng(81)
    img = np.zeros((N, N, 3), np.float32)
    grain = fbm(1.6, 82, aniso=(5.0, 0.4))
    for r in range(rows):
        c = lerp(col(70, 48, 30), col(120, 86, 54), np.full((1, 1), rng.uniform(0, 1), np.float32))[0, 0]
        img[r * rh:(r + 1) * rh] = c
    img *= (0.6 + 0.8 * grain[..., None])
    gap = (yy % rh) < 3
    img = np.where(gap[..., None], col(14, 10, 8), img)
    for _ in range(40):
        y = int(rng.integers(0, N))
        x = int(rng.integers(0, N))
        img[y:y + 1, x:x + int(rng.integers(6, 30))] *= 0.5
    save("plank", img)


def slate():
    img = np.zeros((N, N, 3), np.float32)
    rows = 8
    rh = N // rows
    rng = np.random.default_rng(91)
    n = fbm(1.8, 92)
    for r in range(rows):
        sh = (r % 2) * 16
        for xk in range(0, N, 32):
            x0 = xk + sh
            c = lerp(col(48, 56, 62), col(84, 92, 98), np.full((1, 1), rng.uniform(0, 1), np.float32))[0, 0]
            for yv in range(r * rh, (r + 1) * rh):
                w = 32
                for xv in range(w):
                    shape = 1.0 - ((yv - r * rh) / rh) ** 3
                    img[yv, (x0 + xv) % N] = c * (0.8 + 0.3 * shape)
    img *= (0.7 + 0.6 * n[..., None])
    edge = (xx + (yy // rh % 2) * 16) % 32 < 2
    img = np.where(edge[..., None], img * 0.4, img)
    save("slate", img)


# ------------------------------------------------------------- escala de grises
def fur():
    s = fbm(1.2, 101, aniso=(0.6, 4.0))
    s2 = fbm(2.0, 102, aniso=(0.8, 3.0))
    a = 0.30 + 0.55 * s * 0.7 + 0.35 * s2 * 0.5
    a = a / a.mean() * 0.5
    save("fur", gray(a))


def cloth():
    wx = (np.sin(xx / N * np.pi * 64) * 0.5 + 0.5) * 0.12
    wy = (np.sin(yy / N * np.pi * 64) * 0.5 + 0.5) * 0.12
    folds = np.sin((xx / N * 10 + fbm(2.6, 111) * 2.5) * np.pi) * 0.5 + 0.5
    a = 0.35 + 0.45 * folds + wx + wy + 0.25 * fbm(1.6, 112)
    a = a / a.mean() * 0.5
    save("cloth", gray(a))


def metal():
    s = fbm(1.4, 121, aniso=(5.0, 0.5))
    scr = smooth(fbm(0.8, 122, aniso=(8.0, 0.2)), 0.8, 0.9)
    a = 0.45 + 0.35 * s + 0.2 * scr + 0.2 * fbm(2.4, 123)
    a = a / a.mean() * 0.5
    save("metal", gray(a))


def skin():
    a = 0.4 + 0.5 * fbm(2.2, 131) + 0.2 * smooth(fbm(0.9, 132), 0.8, 0.9)
    a = a / a.mean() * 0.5
    save("skin", gray(a))


if __name__ == "__main__":
    for f in (stone_brick, rock, grass, dirt, bark, leaf, plank, slate, fur, cloth, metal, skin):
        f()
