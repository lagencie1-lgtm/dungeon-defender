"""Ballista bow gates (coordinator 2026-11-24, round 5), on a fast build (HTD_FAST=1, parts keep their names):
  covers   from the painting's camera (az -75, el 15) the bow alone, lined up with the painting the way
           scripts/match_score.py lines up outlines, covers at least 70 % of the area the bow covers in the painting
           (BOWS below: the painting's bow traced by hand on a 50 px grid, the strings left out)
  arc      from the 32-degree run camera, in 16 directions round the tower, the bow reads as an arc: its centre line
           (written by the builder, <fbx>_bow.json) bends away from the chord between its tips by at least 0.3 of the
           chord (sagitta), in at least 12 of the 16 (every weapon of the level)
  python scripts/bow_gate.py <fast.fbx> <level>        -> prints BOW covers / arc and GATE PASS or FAIL; exit 1 on a fail"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import match_score as M  # noqa: E402

BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
BOW_PARTS = r"re:^W-?\d?(Arm\d+|Cap|Lash|BowBlock)"
# the paintings' bows (outer edge out from one tip, inner edge back), pixels of art/ref3d/tower_ballista_l<n>.png
BOWS = {
    1: [[(205, 275), (240, 266), (290, 274), (340, 293), (375, 318), (398, 350), (406, 385), (396, 420), (382, 450), (362, 472),
         (346, 448), (366, 420), (374, 385), (366, 352), (344, 326), (310, 306), (270, 296), (236, 296), (212, 302)]],
    2: [[(240, 175), (300, 170), (360, 180), (410, 198), (455, 228), (485, 263), (497, 300), (491, 336), (472, 366), (450, 390),
         (428, 366), (448, 342), (460, 312), (455, 284), (440, 258), (410, 234), (370, 214), (330, 202), (290, 199), (255, 205)]],
    3: [[(255, 50), (310, 44), (360, 57), (400, 80), (425, 110), (437, 150), (420, 152), (410, 122), (386, 96), (350, 78), (310, 70), (270, 73)],
        [(500, 45), (560, 40), (610, 54), (650, 80), (676, 115), (682, 160), (672, 200), (652, 242),
         (630, 236), (650, 200), (656, 160), (646, 126), (620, 96), (586, 76), (546, 66), (510, 69)]],
}


def render(fbx, out, az, el, only=None):
    env = dict(os.environ)
    if only:
        env["HTD_ONLY_PART"] = only
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", fbx, out, str(az), str(el), "512"],
                   capture_output=True, env=env)
    return Image.open(out)


def covers(fbx, level, tmp):
    full = render(fbx, tmp + "_full.png", -75, 15)
    bow = render(fbx, tmp + "_bow.png", -75, 15, BOW_PARTS)
    _, f_m = M.mask_render(full)
    _, b_m = M.mask_render(bow)
    box = f_m.getbbox()
    W = max(1, round((box[2] - box[0]) * M.H / (box[3] - box[1])))
    b_m = b_m.crop(box).resize((W, M.H))
    pic = Image.open(os.path.join(ROOT, "art", "ref3d", f"tower_ballista_l{level}.png"))
    _, t_m = M.mask_target(pic)
    poly = Image.new("L", pic.size, 0)
    for pts in BOWS[level]:
        ImageDraw.Draw(poly).polygon(pts, fill=255)
    tb = t_m.getbbox()
    TW = max(1, round((tb[2] - tb[0]) * M.H / (tb[3] - tb[1])))
    poly = poly.crop(tb).resize((TW, M.H))
    width = max(W, TW) + 20
    a = np.asarray(M.centred(b_m, width, "L", 0)) > 0
    p = np.asarray(M.centred(poly, width, "L", 0)) > 0
    # (a picture of the two for the review: painting's bow red, the model's bow blue, both purple)
    vis = np.full(a.shape + (3,), 255, np.uint8)
    vis[p] = (230, 80, 80)
    vis[a] = (80, 80, 230)
    vis[a & p] = (150, 60, 170)
    Image.fromarray(vis).save(tmp + "_covers.png")
    return float((a & p).sum() / max(1, p.sum()))


def sagitta(m):
    ys, xs = np.nonzero(m)
    if len(xs) < 30:
        return 0.0
    pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0)
    u = np.linalg.svd(pts - c, full_matrices=False)[2][0]
    t = (pts - c) @ u
    n = (pts - c) @ np.array([-u[1], u[0]])
    lo, hi = t.min(), t.max()
    bins = np.linspace(lo, hi, 21)
    cen = []
    for i in range(20):
        sel = (t >= bins[i]) & (t <= bins[i + 1])
        if sel.sum():
            cen.append(((bins[i] + bins[i + 1]) / 2, float(np.median(n[sel]))))
    cen = np.array(cen)
    (t0, n0), (t1, n1) = cen[0], cen[-1]
    chord = np.hypot(t1 - t0, n1 - n0)
    line_n = n0 + (cen[:, 0] - t0) * (n1 - n0) / max(1e-6, t1 - t0)
    return float(np.abs(cen[:, 1] - line_n).max() / max(1e-6, chord))


def main():
    fbx, level = os.path.abspath(sys.argv[1]), int(sys.argv[2])
    tmp = fbx[:-4] + "_bowgate"
    cov = covers(fbx, level, tmp)
    # (the arc from the bow's own centre line, which the builder writes next to the model: a mask's centre line
    # gets pulled about by the caps and the bow block, and from some sides two arms fall in one column)
    lines = json.load(open(fbx[:-4] + "_bow.json"))
    arcs = []
    for k in range(16):
        az, el = math.radians(-75 + k * 22.5), math.radians(32)
        f = np.array([math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)])
        r = np.cross([0, 0, 1], f)
        r /= np.linalg.norm(r)
        u = np.cross(f, r)
        worst = 9.0
        for ln in lines:
            q = np.array(ln)
            p2 = np.stack([q @ r, q @ u], 1)
            (x0, y0), (x1, y1) = p2[0], p2[-1]
            ch = math.hypot(x1 - x0, y1 - y0)
            d = np.abs((x1 - x0) * (p2[:, 1] - y0) - (y1 - y0) * (p2[:, 0] - x0)) / max(ch, 1e-9)
            worst = min(worst, float(d.max() / max(ch, 1e-9)))
        arcs.append(worst)
    n_arc = sum(a >= 0.3 for a in arcs)
    print(f"BOW covers {100 * cov:.0f}% of the painting's bow (needs 70)")
    print("BOW arc sagitta/chord by direction: " + " ".join(f"{a:.2f}" for a in arcs) + f"  -> {n_arc} of 16 read as an arc (needs 12)")
    ok = cov >= 0.7 and n_arc >= 12
    print("GATE", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
