"""Archer phone-read pass (coordinator 2026-11-26): the hood and cloak greens go to one clear, saturated leaf green and
the bow to a lighter honey wood, so the archers read against the dark lookout at phone size.
  python scripts/archer_tone.py   (reads the untouched sheets from tools/archer_pre/, writes art/models/)"""
import colorsys
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "archer_pre")
DST = os.path.join(ROOT, "art", "models")


def hsv(a):
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, d / (mx + 1e-6), mx


def to_rgb(h, s, v):
    out = np.zeros(h.shape + (3,))
    c = v * s
    x = c * (1 - np.abs((h / 60) % 2 - 1))
    m = v - c
    k = (h // 60).astype(int) % 6
    z = np.zeros_like(h)
    table = [(c, x, z), (x, c, z), (z, c, x), (z, x, c), (x, z, c), (c, z, x)]
    for i, (r, g, b) in enumerate(table):
        sel = k == i
        out[sel] = np.stack([r[sel], g[sel], b[sel]], -1)
    return (out + m[..., None]) * 255


def green(name):
    im = Image.open(os.path.join(SRC, f"ranger_archer_{name}_paint.png")).convert("RGBA")
    a = np.asarray(im).astype(float)
    h, s, v = hsv(a)
    sel = (h > 48) & (h < 130) & (s > 0.3)
    h2 = np.where(sel, 100 + (h - 100) * 0.3, h)
    s2 = np.where(sel, np.clip(s * 1.25, 0.7, 0.9), s)
    v2 = np.where(sel, np.clip(v * 1.12, 0.5, 0.88), v)
    rgb = to_rgb(h2, s2, v2)
    a[..., :3] = np.where(sel[..., None], rgb, a[..., :3])
    Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(os.path.join(DST, f"ranger_archer_{name}_paint.png"))
    print(name, f"green {sel.mean() * 100:.0f}%")


def bow():
    im = Image.open(os.path.join(SRC, "ranger_archer_bow_paint.png")).convert("RGBA")
    a = np.asarray(im).astype(float)
    h, s, v = hsv(a)
    sel = (h > 10) & (h < 50) & (s > 0.3)
    v2 = np.where(sel, np.clip(v * 1.3 + 0.05, 0, 0.95), v)
    s2 = np.where(sel, s * 0.92, s)
    rgb = to_rgb(h, s2, v2)
    a[..., :3] = np.where(sel[..., None], rgb, a[..., :3])
    Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(os.path.join(DST, "ranger_archer_bow_paint.png"))
    print("bow", f"lightened {sel.mean() * 100:.0f}%")


if __name__ == "__main__":
    for n in ("head", "body", "arml", "armr"):
        green(n)
    bow()
