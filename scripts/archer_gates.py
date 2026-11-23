"""Gates for the rebuilt archer (coordinator 2026-11-23, after Lemp: "ripped apart face, cut head, missing piece on
the hoody"). Run on every build; all must pass before anything is reported or uploaded.
  watertight   every part's shells are closed (no boundary or non-manifold edges)        (from the build)
  seam         no colour jump across texture seams (99th percentile <= 14/255)             (from the build)
  symmetry     the hood outline, front and back, matches its mirror image within 2 %
  notch        16 views round the hood: no dent in its outline deeper than 3 % of the head's width, except the
               ones in the spec: the curl under the hood's soft point at the back, and the face opening seen side-on
               (the trim standing proud of the recessed face, at most 6 %)
  face         from 60 degrees left to 60 degrees right: two eyes, two brows, one mouth; never doubled, split or gone
Run: python scripts/archer_gates.py tools/archer3/ranger_archer.fbx
Writes <dir>/gates.json and <dir>/gate_*.png."""
import json
import math
import os
import subprocess
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
OTHERS = "Body,ArmR,ArmL,Bow,Quiver"


def render(fbx, out, az, el=0, size=512, grey=False, skip=OTHERS, mode="ortho"):
    if not os.path.exists(out) or os.path.getmtime(out) < os.path.getmtime(fbx):
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out,
                        str(az), str(el), str(size), mode], capture_output=True,
                       env=dict(os.environ, HTD_GREY="1" if grey else "", HTD_SKIP=skip))
    return np.asarray(Image.open(out).convert("RGBA")).astype(float) / 255


def mask_of(im):
    return im[..., 3] > 0.5


def components(m, eight=False):
    H, W = m.shape
    lab = np.zeros(m.shape, int)
    steps = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (1, -1), (-1, 1), (-1, -1)] if eight else [])
    out = []
    for y, x in zip(*np.where(m)):
        if lab[y, x]:
            continue
        n = len(out) + 1
        q = deque([(y, x)])
        lab[y, x] = n
        pix = []
        while q:
            a, b = q.popleft()
            pix.append((a, b))
            for da, db in steps:
                c, d = a + da, b + db
                if 0 <= c < H and 0 <= d < W and m[c, d] and not lab[c, d]:
                    lab[c, d] = n
                    q.append((c, d))
        out.append(np.array(pix))
    return out


def symmetry(m):
    cols = np.where(m.any(0))[0]
    c = (cols.min() + cols.max()) / 2
    w = m.shape[1]
    mx = np.clip(np.round(2 * c - np.arange(w)).astype(int), 0, w - 1)
    return float((m ^ m[:, mx]).sum() / m.sum())


def hull_dents(m):
    """the outline's dents: inside its convex hull but outside the outline, each with its depth (distance in from
    the hull's edge) as a fraction of the width, and where it is (0..1 across and down the outline's box)"""
    rows = np.where(m.any(1))[0]
    cols = np.where(m.any(0))[0]
    width = cols.max() - cols.min() + 1
    pts = set()
    for y in rows:
        xs = np.where(m[y])[0]
        pts |= {(int(xs.min()), int(y)), (int(xs.max()), int(y))}
    P = sorted(pts)

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in P:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(P):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    hull = lower[:-1] + upper[:-1]
    im = Image.new("L", (m.shape[1], m.shape[0]), 0)
    ImageDraw.Draw(im).polygon(hull, fill=1)
    hm = np.asarray(im).astype(bool)
    depth = np.zeros(m.shape, int)
    cur = hm.copy()
    k = 0
    while cur.any() and k < 300:
        k += 1
        nxt = cur.copy()
        nxt[1:, :] &= cur[:-1, :]
        nxt[:-1, :] &= cur[1:, :]
        nxt[:, 1:] &= cur[:, :-1]
        nxt[:, :-1] &= cur[:, 1:]
        depth[cur & ~nxt] = k
        cur = nxt
    out = []
    for pix in components(hm & ~m):
        if len(pix) < 4:
            continue
        out.append({"depth": int(depth[pix[:, 0], pix[:, 1]].max()) / width,
                    "y": float((pix[:, 0].mean() - rows.min()) / (rows.max() - rows.min())),
                    "x": float((pix[:, 1].mean() - cols.min()) / width), "area": len(pix)})
    return out


PAINT = os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_bare.png")
# the face's marks in the front painting (pixels, x0 y0 x1 y1)
TEMPLATES = {"eye": [(342, 175, 383, 223), (445, 175, 485, 223)], "brow": [(333, 150, 388, 180), (440, 158, 495, 180)],
             "mouth": [(378, 240, 450, 259)]}
PAINT_HEAD_W = 350     # the hood's width in the front painting


def face_features(im, head_w_px):
    """find the painting's own eyes, brows and mouth in a view (normalised cross-correlation, the marks squeezed
    sideways as the head turns): how many of each, and how sure"""
    import cv2
    ref = cv2.cvtColor(cv2.imread(PAINT), cv2.COLOR_BGR2GRAY).astype(np.float32)
    rgb = (im[..., :3] * im[..., 3:4] + (1 - im[..., 3:4])) * 255
    gray = cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
    k = PAINT_HEAD_W / head_w_px
    gray = cv2.resize(gray, None, fx=k, fy=k, interpolation=cv2.INTER_AREA)
    out, maps = {}, {}

    def peaks(m, th, tw, thr):
        found = []
        work = m.copy()
        while True:
            y, x = np.unravel_index(np.argmax(work), work.shape)
            v = float(work[y, x])
            if v < thr:
                return found
            found.append((x, y, v))
            work[max(0, y - th // 2):y + th // 2 + 1, max(0, x - int(tw * 0.5)):x + int(tw * 0.5) + 1] = -1
    for name, boxes in TEMPLATES.items():
        best = np.full(gray.shape, -1.0, np.float32)
        th, tw = 0, 0
        for (x0, y0, x1, y1) in boxes:
            t = ref[y0:y1, x0:x1]
            th, tw = t.shape
            for f in np.linspace(0.3, 1.1, 17):
                ts = cv2.resize(t, (max(4, int(tw * f)), th), interpolation=cv2.INTER_AREA)
                if ts.std() < 1:
                    continue
                r = cv2.matchTemplate(gray, ts, cv2.TM_CCOEFF_NORMED)
                # put the score at the template's centre
                full = np.full(gray.shape, -1.0, np.float32)
                oy, ox = ts.shape[0] // 2, ts.shape[1] // 2
                full[oy:oy + r.shape[0], ox:ox + r.shape[1]] = r
                best = np.maximum(best, full)
        maps[name] = (best, th, tw)
    # eyes: the painting's own eyes match at 0.95+ (anything else on the head stays under 0.85)
    eyes = peaks(*maps["eye"], 0.9)
    mouth = peaks(*maps["mouth"], 0.7)
    brows = []
    bm, bth, btw = maps["brow"]
    _, eth, etw = maps["eye"]
    for ex, ey, _v in eyes:   # one brow over each eye (a dark bar alone also matches the hair, so look only there)
        y0, y1 = max(0, ey - 60), max(0, ey - 15)
        x0, x1 = max(0, ex - int(etw * 0.6)), ex + int(etw * 0.6)
        region = np.full(bm.shape, -1.0, np.float32)
        region[y0:y1, x0:x1] = bm[y0:y1, x0:x1]
        found = peaks(region, bth, btw * 2, 0.6)   # (a brow is long: its two ends are one brow)
        if found:
            best = found[0][2]
            # a second bar nearly as good in the same place = a doubled or split brow
            brows += [found[0]] + [f for f in found[1:] if f[2] >= max(0.85, best * 0.95)]
    for name, found in (("eye", eyes), ("brow", brows), ("mouth", mouth)):
        out[name] = [{"x": int(x / k), "y": int(y / k), "score": round(v, 2)} for x, y, v in found]
    return out


def main():
    fbx = os.path.abspath(sys.argv[1])
    d = os.path.dirname(fbx)
    res = {"fails": []}
    bp = os.path.join(d, "gates_build.json")
    build = json.load(open(bp)) if os.path.exists(bp) else {"watertight": {}, "seam": {}}
    if not os.path.exists(bp):
        res["fails"].append("no build gates (watertight, seam): not built by archer_loft.py")
    res["watertight"] = build["watertight"]
    for part, bad in build["watertight"].items():
        if bad:
            res["fails"].append(f"watertight {part}: {bad} open edges")
    res["seam"] = build["seam"]
    for part, s in build["seam"].items():
        if s["p99"] > 14:
            res["fails"].append(f"seam {part}: {s['p99']}/255")
    res["symmetry"] = {}
    for name, az in (("front", -90), ("back", 90)):
        a = symmetry(mask_of(render(fbx, os.path.join(d, f"gate_sym_{name}.png"), az, grey=True)))
        res["symmetry"][name] = round(a * 100, 2)
        if a > 0.02:
            res["fails"].append(f"symmetry {name}: {a * 100:.1f}% (limit 2%)")
    res["notch"] = []
    for k in range(16):
        turn = k * 22.5
        comps = hull_dents(mask_of(render(fbx, os.path.join(d, f"gate_notch_{k:02d}.png"), -90 + turn, grey=True)))
        worst = None
        for c in comps:
            s = math.sin(math.radians(turn))
            # in the spec: the curl under the soft point, at the back, in the lower half, in side-on views
            spec = abs(s) > 0.5 and (c["x"] > 0.55 if s > 0 else c["x"] < 0.45) and c["y"] > 0.4
            bottom = c["y"] > 0.92        # under the hood's hem (it sits on the shoulders), not its outline
            # in the spec too: the face opening at the front, the trim standing proud of the recessed face (<= 6 %)
            opening = abs(s) > 0.3 and (c["x"] < 0.15 if s > 0 else c["x"] > 0.85) and 0.25 < c["y"] < 0.95 and c["depth"] <= 0.06
            if not spec and not bottom and not opening and (worst is None or c["depth"] > worst["depth"]):
                worst = c
        dep = worst["depth"] if worst else 0.0
        res["notch"].append(round(dep * 100, 2))
        if dep > 0.03:
            res["fails"].append(f"notch frame {k:02d}: {dep * 100:.1f}% of the head's width (x {worst['x']:.2f}, y {worst['y']:.2f})")
    res["face"] = {}
    front = mask_of(render(fbx, os.path.join(d, "gate_face_width.png"), -90, el=5, size=1024))
    cols = np.where(front.any(0))[0]
    head_w = cols.max() - cols.min() + 1
    for ang in range(-60, 61, 15):
        im = render(fbx, os.path.join(d, f"gate_face{ang:+03d}_1024.png"), -90 + ang, el=5, size=1024)
        f = face_features(im, head_w)
        n = {k: len(v) for k, v in f.items()}
        res["face"][str(ang)] = f
        two = abs(ang) <= 45
        ok = ((n["eye"] == 2 if two else n["eye"] in (1, 2)) and (n["brow"] == 2 if two else n["brow"] in (1, 2))
              and n["mouth"] == 1)
        print(f"face {ang:+3d}: eyes {n['eye']} brows {n['brow']} mouth {n['mouth']}  " +
              " ".join(f"{k}:" + ",".join(str(p['score']) for p in v) for k, v in f.items()), flush=True)
        if not ok:
            res["fails"].append(f"face {ang:+d} deg: eyes {n['eye']}, brows {n['brow']}, mouth {n['mouth']}")
    res["pass"] = not res["fails"]
    json.dump(res, open(os.path.join(d, "gates.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in res.items() if k not in ("watertight", "face")}, indent=1))
    print("GATES", "PASS" if res["pass"] else "FAIL")


if __name__ == "__main__":
    main()
