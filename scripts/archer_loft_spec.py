"""Measures the archer's bare model sheet (art/ref3d/archer/ranger_archer_bare.png: front, side, back, nothing
overlapping the body) into row profiles for the lofted build (art/blender/archer_loft.py). Rebuild after Lemp
2026-11-23 ("ripped apart face, cut head, a missing piece on the hoody"): every symmetric part is one closed solid,
lofted row by row: half-width from the symmetrised front outline, depth and forward offset from the side outline.
Writes art/ref3d/archer/ranger_archer_loft.json (units: Blender metres, Z up, front = -Y, ground at Z=0).
  python scripts/archer_loft_spec.py"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archer_classes import classes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "art", "ref3d", "archer")
SHEET = os.path.join(DIR, "ranger_archer_bare.png")

# the sheet's layout (pixels), measured once: front view centre column, side view torso centre, ground row, top row
FRONT = (170, 650)
SIDE = (838, 1238)
CX = 410          # front view centre line
SX = 1045         # side view: depth zero (the torso's middle)
GROUND, TOP = 711, 12
HEIGHT = 2.4      # the old archer's height: the towers' anchors stay right
S = HEIGHT / (GROUND - TOP)


def z(y):
    return round((GROUND - y) * S, 4)


def smooth(a, r):
    a = np.asarray(a, dtype=float)
    out = a.copy()
    for i in range(len(a)):
        lo, hi = max(0, i - r), min(len(a), i + r + 1)
        out[i] = np.median(a[lo:hi])
    return out


def gauss(a, sigma):
    a = np.asarray(a, dtype=float)
    k = np.exp(-0.5 * (np.arange(-3 * int(sigma + 1), 3 * int(sigma + 1) + 1) / sigma) ** 2)
    k /= k.sum()
    pad = len(k) // 2
    return np.convolve(np.pad(a, pad, mode="edge"), k, mode="valid")


def runs(row):
    """(start, end) of every foreground run in a boolean row"""
    out, start = [], None
    for i, v in enumerate(row):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i - 1))
            start = None
    if start is not None:
        out.append((start, len(row) - 1))
    return out


def main():
    cls, _ = classes(SHEET)
    fg = cls != "."
    green = cls == "g"
    spec = {"sheet": os.path.basename(SHEET), "height": HEIGHT, "scale": S, "cx": CX, "sx": SX, "ground": GROUND}

    # ---- hood / head: rows TOP..300 --------------------------------------------------------------------------
    ys = list(range(TOP + 2, 301, 5))
    hw, front, back, ow = [], [], [], []
    for y in ys:
        r = fg[y, FRONT[0]:FRONT[1]]
        xs = np.where(r)[0] + FRONT[0]
        left, right = xs.min(), xs.max()
        hw.append(((CX - left) + (right - CX)) / 2)
        sr = runs(fg[y, SIDE[0]:SIDE[1]])
        sr = [(a + SIDE[0], b + SIDE[0]) for a, b in sr if b - a > 6]
        front.append(max(b for a, b in sr))
        back.append(min(a for a, b in sr))
        # the hood opening: where the green ends going in from each side (the cream trim is the opening's edge)
        g = green[y, FRONT[0]:FRONT[1]]
        gx = np.where(g)[0] + FRONT[0]
        if len(gx) == 0:
            ow.append(None)
            continue
        lg = left
        while lg < CX and green[y, lg]:
            lg += 1
        rg = right
        while rg > CX and green[y, rg]:
            rg -= 1
        ow.append(((CX - lg) + (rg - CX)) / 2 if lg < CX and rg > CX else None)
    hw = gauss(smooth(hw, 1), 1.5)
    front = gauss(smooth(front, 5), 1.5)   # the nose and the hair spikes are paint, not shape
    # the back: the hood's soft point (the curl under it is the tail piece, art/blender/archer_loft.py), no ledge
    back = gauss(smooth(back, 6), 2.5)
    # below its furthest point the back eases round to the bottom (an egg, no ledge): the curl is the tail piece
    i0 = int(np.argmin(back))
    for i in range(i0 + 1, len(back)):
        t = (i - i0) / (len(back) - 1 - i0)
        back[i] = back[i0] + (back[-1] - back[i0]) * (1 - math.cos(t * math.pi / 2))
    spec["head"] = [{"z": z(y), "hw": round(w * S, 4), "front": round(-(f - SX) * S, 4), "back": round(-(b - SX) * S, 4)}
                    for y, w, f, b in zip(ys, hw, front, back)]
    # the opening: rows where the green ring is open in the middle (from the brow of the hood down to the chin)
    op = []
    for y, w, o in zip(ys, hw, ow):
        if o is not None and 0 < o < w - 4 and y > 60:
            op.append({"z": z(y), "ow": round(o * S, 4)})
    spec["opening"] = op

    # ---- torso: rows 290..532 (the top runs up inside the hood: no gap at the neck) ----------------------------
    # front half-widths by hand where the sleeves join (the arms are their own solids), measured below them
    ty = list(range(270, 533, 6))
    hand = [(270, 55), (290, 62), (306, 76), (322, 86), (350, 84), (380, 80), (400, 79), (445, 84), (470, 92), (500, 104), (532, 110)]
    hwt = np.interp(ty, [a for a, b in hand], [b for a, b in hand])
    tf, tb = [], []
    for y in ty:
        yy = max(y, 335)       # above the shoulder the side outline is the hood: carry the chest's on up
        sr = runs(fg[yy, SIDE[0]:SIDE[1]])
        sr = [(a + SIDE[0], b + SIDE[0]) for a, b in sr if b - a > 6]
        a, b = min(a for a, b in sr), max(b for a, b in sr)
        tf.append(b)
        tb.append(a)
    tf = gauss(smooth(tf, 6), 1.5)   # the buckle is its own solid
    tb = gauss(smooth(tb, 6), 1.5)
    spec["torso"] = [{"z": z(y), "hw": round(w * S, 4), "front": round(-(f - SX) * S, 4), "back": round(-(b - SX) * S, 4)}
                     for y, w, f, b in zip(ty, hwt, tf, tb)]

    # ---- legs (trousers) and boots: per leg, from the front run on that side and the side outline -------------
    def leg_rows(y0, y1, step=4):
        rows = []
        for y in range(y0, y1 + 1, step):
            rr = runs(fg[y, FRONT[0]:CX])
            a, b = max(rr, key=lambda t: t[1] - t[0])
            l, r = a + FRONT[0], b + FRONT[0]
            rr2 = runs(fg[y, CX:FRONT[1]])
            a2, b2 = max(rr2, key=lambda t: t[1] - t[0])
            l2, r2 = a2 + CX, b2 + CX
            # symmetrise: the mean of the two legs, mirrored
            c = ((CX - (l + r) / 2) + ((l2 + r2) / 2 - CX)) / 2
            w = ((r - l) + (r2 - l2)) / 4
            sr = runs(fg[y, SIDE[0]:SIDE[1]])
            sr = [(a + SIDE[0], b + SIDE[0]) for a, b in sr if b - a > 6]
            sa, sb = min(a for a, b in sr), max(b for a, b in sr)
            rows.append({"z": z(y), "cx": round(c * S, 4), "hw": round(w * S, 4), "front": round(-(sb - SX) * S, 4), "back": round(-(sa - SX) * S, 4)})
        return rows
    spec["leg"] = leg_rows(542, 604)
    spec["boot"] = leg_rows(598, GROUND - 1, 5)

    # ---- arms: centre line and radii (character's right arm = the viewer's left in the front view) -----------
    def p(x, y):
        return [round((x - CX) * S, 4), round(-(1030 - SX) * S, 4), z(y)]
    spec["arm"] = {
        "sleeve": {"path": [p(330, 322), p(306, 342), p(286, 364)], "r": [36 * S, 35 * S, 32 * S]},
        "cuff": {"at": p(283, 368), "dir": [-0.62, 0, -0.78], "r": 33 * S, "w": 14 * S},
        "upper": {"path": [p(288, 364), p(262, 392), p(244, 412)], "r": [25 * S, 24 * S, 24 * S]},
        "bracer": {"path": [p(258, 392), p(238, 418), p(222, 444)], "r": [31 * S, 32 * S, 30 * S]},
        "fist": {"at": p(207, 470), "r": [36 * S, 33 * S, 35 * S]},
    }
    spec["belt"] = {"z0": z(447), "z1": z(405)}
    spec["buckle"] = {"z0": z(445), "z1": z(403), "hw": 30 * S}
    spec["hem"] = {"z0": z(533), "z1": z(512)}
    spec["slit"] = {"z0": z(530), "z1": z(452), "w": 14 * S}
    spec["boot_cuff"] = {"z0": z(642), "z1": z(596)}

    # ---- palette (sampled from the painting, sRGB 0..1) --------------------------------------------------------
    im = np.asarray(__import__("PIL.Image", fromlist=["Image"]).open(SHEET).convert("RGB")).astype(float) / 255

    def col(x0, y0, x1, y1):
        return [round(float(v), 3) for v in np.median(im[y0:y1, x0:x1].reshape(-1, 3), axis=0)]
    spec["palette"] = {
        "hood": col(380, 30, 440, 55), "tunic": col(440, 470, 480, 500), "cream": col(337, 112, 343, 118),
        "skin": col(395, 240, 425, 260), "hair": col(355, 122, 365, 130), "leather": col(345, 415, 375, 430),
        "bracer": col(225, 405, 245, 420), "trousers": col(335, 560, 375, 585), "boot": col(300, 660, 340, 690),
        "gold": col(395, 412, 402, 432),
    }
    out = os.path.join(DIR, "ranger_archer_loft.json")
    json.dump(spec, open(out, "w"), indent=1)
    print("wrote", out, len(spec["head"]), "head rows,", len(spec["opening"]), "opening rows")
    print(json.dumps(spec["palette"]))


if __name__ == "__main__":
    main()
