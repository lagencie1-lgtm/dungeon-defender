"""Paints the Magma Fortress sky box: a smouldering orange horizon fading up into deep ash red.
Only vertical gradients with soft ash bands, so the four sides join without seams.
Run: python art/make_sky.py  -> art/sky/sky_magma_side.png, _up, _down"""
import math
import os
import random

from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sky")
S = 512


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def side(top, mid, horizon, bottom):
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        f = y / (S - 1)  # 0 top .. 1 bottom; the horizon is the middle
        if f < 0.5:
            t = (f / 0.5) ** 1.6
            c = lerp(top, mid, t) if t < 0.7 else lerp(mid, horizon, (t - 0.7) / 0.3)
        else:
            c = lerp(horizon, bottom, min(1, (f - 0.5) / 0.15))
        for x in range(S):
            px[x, y] = c
    # soft ash bands, the same at both edges so the sides tile
    rnd = random.Random(4)
    overlay = Image.new("RGB", (S, S), (0, 0, 0))
    op = overlay.load()
    for _ in range(5):
        cy = rnd.uniform(0.18, 0.45) * S
        amp = rnd.uniform(4, 14)
        thick = rnd.uniform(6, 16)
        k = rnd.choice([1, 2, 3])
        phase = rnd.uniform(0, math.pi * 2)
        strength = rnd.uniform(18, 34)
        for x in range(S):
            yc = cy + math.sin(x / S * math.pi * 2 * k + phase) * amp
            for y in range(int(yc - thick * 2), int(yc + thick * 2)):
                if 0 <= y < S:
                    w = math.exp(-((y - yc) / thick) ** 2) * strength
                    r, g, b = op[x, y]
                    op[x, y] = (min(255, r + int(w)), min(255, g + int(w * 0.45)), min(255, b + int(w * 0.25)))
    overlay = overlay.filter(ImageFilter.GaussianBlur(3))
    from PIL import ImageChops
    return ImageChops.add(img, overlay)


def flat(color):
    return Image.new("RGB", (S, S), color)


os.makedirs(OUT, exist_ok=True)
TOP = (96, 52, 70)
MID = (205, 98, 62)
HORIZON = (255, 178, 100)
BOTTOM = (60, 30, 24)
side(TOP, MID, HORIZON, BOTTOM).save(os.path.join(OUT, "sky_magma_side.png"))
flat(TOP).save(os.path.join(OUT, "sky_magma_up.png"))
flat(BOTTOM).save(os.path.join(OUT, "sky_magma_down.png"))
print("sky done")
