"""Measures the archer's elf model sheet (art/ref3d/archer/ranger_archer_elf.png: the main painting's own character,
front, side, back, nothing overlapping the body) into the shape spec for art/blender/archer_loft.py.
Art pass after the coordinator's review (2026-11-23, 5/10): pointed elf hood with a peak, a ridge and a hanging tip,
a collar roll, a wide flat trim band, big hair locks, chest strap, short sleeves with wide cuffs, big bracers, fists,
a big gold buckle, the tunic's front split, boots with a folded cuff.
Writes art/ref3d/archer/ranger_archer_loft.json (Blender metres, Z up, front = -Y, ground at Z=0).
  python scripts/archer_elf_spec.py"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archer_classes import classes  # noqa: E402
from archer_loft_spec import gauss, runs, smooth  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "art", "ref3d", "archer")
SHEET = os.path.join(DIR, "ranger_archer_elf.png")

# the sheet's layout (pixels), measured from its outline runs: front view centre (the legs' and the hood's middle),
# side view depth zero (the torso's middle), ground and top rows
FRONT = (30, 615)
SIDE = (630, 1040)
CX = 321
SX = 888
GROUND, TOP = 868, 21
HEIGHT = 2.4
S = HEIGHT / (GROUND - TOP)
HOOD_BOTTOM = 338    # the hood's lower edge at the sides (the collar roll starts below it)


def z(y):
    return round((GROUND - y) * S, 4)


def X(x):
    return round((x - CX) * S, 4)


def Y(x):
    return round(-(x - SX) * S, 4)


def main():
    cls, im = classes(SHEET)
    fg = cls != "."
    green = cls == "g"
    spec = {"sheet": os.path.basename(SHEET), "height": HEIGHT, "scale": S, "cx": CX, "sx": SX, "ground": GROUND,
            "side_view": [SIDE[0], 25, SIDE[1], HOOD_BOTTOM + 7]}

    def side_runs(y):
        rr = runs(fg[y, SIDE[0]:SIDE[1]])
        return [(a + SIDE[0], b + SIDE[0]) for a, b in rr if b - a > 2]

    # ---- the hood: one solid, rows TOP..HOOD_BOTTOM -------------------------------------------------------------
    ys = list(range(33, HOOD_BOTTOM + 1, 5))   # (the side view starts at row 30)
    hw, front, back, ow = [], [], [], []
    for y in ys:
        xs = np.where(fg[y, FRONT[0]:FRONT[1]])[0] + FRONT[0]
        left, right = xs.min(), xs.max()
        hw.append(((CX - left) + (right - CX)) / 2)
        sr = side_runs(y)
        main_run = max(sr, key=lambda t: t[1])       # the run with the face in it (the hanging tip is the other one)
        front.append(main_run[1])
        back.append(main_run[0])
        lg = left
        while lg < CX and green[y, lg]:
            lg += 1
        rg = right
        while rg > CX and green[y, rg]:
            rg -= 1
        ow.append(((CX - lg) + (rg - CX)) / 2 if lg < CX - 3 and rg > CX + 3 else None)
    hw = gauss(smooth(hw, 1), 1.0)
    front = gauss(smooth(front, 5), 1.5)      # nose and hair are paint and locks, not the hood's shape
    back = gauss(smooth(back, 3), 1.5)
    # below its furthest point the back eases round to the bottom (no ledge): the hanging tip is its own piece
    i0 = int(np.argmin(back))
    for i in range(i0 + 1, len(back)):
        t = (i - i0) / (len(back) - 1 - i0)
        back[i] = min(back[i], back[i0] + (back[-1] - back[i0]) * (1 - math.cos(t * math.pi / 2)))
    spec["head"] = [{"z": z(y), "hw": round(w * S, 4), "front": Y(f), "back": Y(b)} for y, w, f, b in zip(ys, hw, front, back)]
    # the opening: the green ring's inner edge = the trim band's outer edge
    op = [{"z": z(y), "ow": round(o * S, 4)} for y, w, o in zip(ys, hw, ow) if o is not None and 0 < o < w - 4 and y > 60]
    spec["opening"] = op
    spec["trim_w"] = round(26 * S, 4)          # the band's width in the painting (about 26 px)
    # the hanging tip: the side view's separate run behind the head (rows where it is its own run)
    tip = []
    for y in range(150, 300, 6):
        sr = side_runs(y)
        back_runs = [t for t in sr if t[1] < 720]      # behind the head, not a gap in the face
        if len(sr) > 1 and back_runs:
            a, b = min(back_runs, key=lambda t: t[0])
            tip.append((y, (a + b) / 2, (b - a) / 2))
    spec["tip"] = [{"z": z(y), "y": Y(c), "r": round(r * S, 4)} for y, c, r in tip]

    # ---- the collar roll where the hood meets the shoulders --------------------------------------------------------
    spec["collar"] = {"z": z(358), "hw": round(112 * S, 4), "r": round(15 * S, 4)}

    # ---- torso: rows 330..640 (its top runs up inside the hood) -------------------------------------------------
    ty = list(range(330, 641, 6))
    hand = [(330, 62), (345, 70), (365, 82), (390, 88), (430, 89), (470, 88), (500, 93), (540, 99), (580, 108),
            (610, 120), (628, 125), (640, 120)]
    hwt = np.interp(ty, [a for a, b in hand], [b for a, b in hand])
    tf, tb = [], []
    for y in ty:
        sr = side_runs(max(y, 395))     # above the shoulder the side outline is the collar and hood
        tf.append(max(b for a, b in sr))
        tb.append(min(a for a, b in sr))
    tf = gauss(smooth(tf, 6), 1.5)
    tb = gauss(smooth(tb, 6), 1.5)
    spec["torso"] = [{"z": z(y), "hw": round(w * S, 4), "front": Y(f), "back": Y(b)} for y, w, f, b in zip(ty, hwt, tf, tb)]

    # ---- legs and boots, per leg (mirrored mean of both) -------------------------------------------------------
    def leg_rows(y0, y1, step):
        rows = []
        for y in range(y0, y1 + 1, step):
            l = max(runs(fg[y, FRONT[0]:CX]), key=lambda t: t[1] - t[0])
            r = max(runs(fg[y, CX:FRONT[1]]), key=lambda t: t[1] - t[0])
            l = (l[0] + FRONT[0], l[1] + FRONT[0])
            r = (r[0] + CX, r[1] + CX)
            c = ((CX - (l[0] + l[1]) / 2) + ((r[0] + r[1]) / 2 - CX)) / 2
            w = ((l[1] - l[0]) + (r[1] - r[0])) / 4
            sr = side_runs(y)
            sa, sb = min(a for a, b in sr), max(b for a, b in sr)
            rows.append({"z": z(y), "cx": round(c * S, 4), "hw": round(w * S, 4), "front": Y(sb), "back": Y(sa)})
        return rows
    spec["leg"] = leg_rows(652, 712, 6)
    spec["boot"] = leg_rows(706, GROUND - 2, 6)
    spec["boot_cuff"] = {"z0": z(762), "z1": z(706)}
    spec["sole"] = {"z1": z(848)}

    # ---- arms: centre lines and radii (character's right arm = the viewer's left) ----------------------------------
    ay = (812 + 905) / 2      # the arm's depth in the side view

    def p(x, y):
        return [X(x), Y(ay), z(y)]
    spec["arm"] = {
        "sleeve": {"path": [p(240, 388), p(214, 408), p(190, 432)], "r": [34 * S, 34 * S, 32 * S]},
        "cuff": {"at": p(184, 438), "dir": [-0.7, 0, -0.7], "r": 35 * S, "w": 20 * S},
        "fore": {"path": [p(190, 440), p(160, 466), p(132, 492)], "r": [25 * S, 24 * S, 24 * S]},
        "bracer": {"path": [p(146, 482), p(122, 510), p(98, 538)], "r": [36 * S, 37 * S, 35 * S]},
        "fist": {"at": p(80, 580), "size": [40 * S, 34 * S, 40 * S]},
    }
    spec["belt"] = {"z0": z(548), "z1": z(500)}
    spec["buckle"] = {"z0": z(556), "z1": z(502), "hw": 36 * S, "bar": 11 * S}
    spec["hem"] = {"z0": z(642), "z1": z(616)}
    spec["split"] = {"z0": z(640), "z1": z(556), "top_w": 4 * S, "bottom_w": 30 * S, "w": 12 * S}
    spec["strap"] = {"from": [X(404), z(372)], "to": [X(236), z(508)], "w": 24 * S, "buckle": [X(348), z(414)]}

    # ---- palette (sRGB 0..1), medians of the painting's own patches ------------------------------------------------
    def col(x0, y0, x1, y1):
        return [round(float(v), 3) for v in np.median(im[y0:y1, x0:x1].reshape(-1, 3), axis=0)]
    spec["palette"] = {
        "hood": [125 / 255, 155 / 255, 39 / 255],   # (the median of all the hood's green pixels)
        "hood_inner": col(194, 286, 202, 292), "tunic": col(250, 430, 280, 470),
        "cream": col(330, 92, 345, 100), "lime": col(260, 622, 300, 632), "skin": col(300, 290, 340, 300),
        "hair": col(330, 160, 350, 170), "leather": col(240, 515, 260, 530), "strap": col(300, 435, 312, 445),
        "bracer": col(100, 505, 120, 520), "trousers": col(230, 670, 270, 690), "boot": col(200, 800, 240, 830),
        "sole": col(200, 856, 240, 864), "gold": col(300, 500, 308, 506), "collar": col(250, 352, 270, 360),
    }
    # the face's marks in the front painting (eyes, brows, mouth; x0 y0 x1 y1): kept exactly by the painterly pass and
    # looked for by the face gate (scripts/archer_gates.py)
    spec["marks"] = {"eye": [[252, 215, 300, 267], [352, 217, 400, 267]], "brow": [[242, 192, 303, 220], [348, 192, 410, 223]],
                     "mouth": [[287, 293, 365, 307]]}
    out = os.path.join(DIR, "ranger_archer_loft.json")
    json.dump(spec, open(out, "w"), indent=1)
    print("wrote", out, len(spec["head"]), "head rows,", len(spec["opening"]), "opening rows,", len(spec["tip"]), "tip rows")
    for k, v in spec["palette"].items():
        print(" ", k, [int(c * 255) for c in v])


if __name__ == "__main__":
    main()
