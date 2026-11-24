"""Per-part scores of a painted archer against the front painting (coordinator round C, C5: "score each part (hair, face,
hood, tunic, arms, boots) against the painting, and if a part scores worse than in the round before, do not ship that
part's change"), and the round C face gate (C2).

The model is rendered straight from the front in neutral light (its flat paint, as the turntables) at the painting's
own scale and place (the build is measured from art/ref3d/archer/ranger_archer_elf.png, so the two line up pixel for
pixel). Bow and quiver are left out (the painting's front view carries nothing).

Per part (the painting's own pixels of that part, where the model also has paint):
  dE      mean colour difference (CIE Lab, delta E 76), pixel by pixel
  dE_mid  difference of the part's median colours (its overall colour)
  stroke  the brush-stroke number (scripts/archer_painterly.py) of the part in the model, and in the painting
Face gate (C2): on the face's skin (eyes, brows, mouth and the nose's shadow left out, 3 px in from its edges) the 99th percentile difference
  stays under delta E 12, and no connected dark patch (model darker than the painting by more than 12 in L*) is larger
  than 0.5 % of the face's skin.

  python scripts/archer_parts_score.py <archer.fbx> [--label "round C"] [--json out.json]"""
import json
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from archer_classes import classes  # noqa: E402

BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
SPEC = json.load(open(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_loft.json")))
SHEET = os.path.join(ROOT, "art", "ref3d", "archer", SPEC["sheet"])
X0, W, H = 0, 640, 880          # the painting's front view: x 0..640, y 0..880
NOSE = (306, 255, 350, 296)
# (the nose and its shadow in the front painting, x0 y0 x1 y1, above)
# round D: the trim dips under the chin; the face reaches rows 332-336 at the centre, the painting 344 (round C
# measured above row 318, where the old trim crossed the chin)
CHIN_ROW = int(os.environ.get("HTD_CHIN_ROW", "336"))
BX = 1448.5   # the back view's middle column


def render_front(fbx):
    S, CX, G = SPEC["scale"], SPEC["cx"], SPEC["ground"]
    out = fbx[:-4] + "_front_true.png"
    if not os.path.exists(out) or os.path.getmtime(out) < max(os.path.getmtime(p) for p in [fbx] + [
            os.path.join(os.path.dirname(fbx), f) for f in os.listdir(os.path.dirname(fbx)) if f.endswith("_paint.png")]):
        xc = ((X0 + W / 2) - CX) * S      # a square H x H round the painting's W columns
        zc = (G - H / 2) * S
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out, "-90", "0",
                        str(H), "ortho"], capture_output=True,
                       env=dict(os.environ, HTD_GREY="", HTD_SKIP="Bow,Quiver", HTD_FRAME=f"{xc},0,{zc},{H * S}"))
    im = np.asarray(Image.open(out).convert("RGBA")).astype(float) / 255
    off = (H - W) // 2                   # the render is H wide, centred on the painting's W columns
    return im[:, off:off + W]


def render_view(fbx, view):
    """round D: the side (his right, camera at -X) and the back at the sheet's scale and place, as render_front;
    returns the render and the painting's 640 columns round that view's middle"""
    S, SX, G = SPEC["scale"], SPEC["sx"], SPEC["ground"]
    col = {"side": 860, "back": int(BX)}[view]
    out = fbx[:-4] + f"_{view}_true.png"
    if not os.path.exists(out) or os.path.getmtime(out) < max(os.path.getmtime(p) for p in [fbx] + [
            os.path.join(os.path.dirname(fbx), f) for f in os.listdir(os.path.dirname(fbx)) if f.endswith("_paint.png")]):
        zc = (G - H / 2) * S
        frame = f"0,{-(col - SX) * S},{zc},{H * S}" if view == "side" else f"{-(col - BX) * S},0,{zc},{H * S}"
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out,
                        "180" if view == "side" else "90", "0", str(H), "ortho"], capture_output=True,
                       env=dict(os.environ, HTD_GREY="", HTD_SKIP="Bow,Quiver", HTD_FRAME=frame))
    im = np.asarray(Image.open(out).convert("RGBA")).astype(float) / 255
    off = (H - W) // 2
    paint = np.asarray(Image.open(SHEET).convert("RGB")).astype(float)[:H] / 255
    return im[:, off:off + W], paint[:, col - W // 2:col + W // 2]


def view_parts(paint, view):
    """hood, tunic, arms, boots in the side and back paintings (by colour and rows, as the front's)"""
    Lp = lab(paint)
    yy, xx = np.mgrid[0:H, 0:W]
    fg = paint.min(-1) < 0.92
    green = Lp[..., 1] < -15
    out = {"hood": green & (yy < 345), "tunic": green & (yy >= 345) & (yy < 650), "boots": fg & (yy > 706) & (yy < GROUND_ROW())}
    if view == "back":
        out["tunic"] &= abs(xx - W / 2) < 125
        out["arms"] = fg & (yy > 380) & (yy < 620) & (abs(xx - W / 2) > 135)
    return out


def score_view(fbx, view):
    model, paint = render_view(fbx, view)
    alpha = model[..., 3] > 0.5
    Lm, Lp = lab(model[..., :3]), lab(paint)
    dE = np.sqrt(((Lm - Lp) ** 2).sum(-1))
    res = {}
    for name, m in view_parts(paint, view).items():
        k = m & alpha
        if k.sum() >= 50:
            # (the 99th percentile 5 px in from the part's edges: outlines line up only to a few pixels)
            ki = (cv2.erode(m.astype(np.uint8), np.ones((11, 11), np.uint8)) > 0) & alpha
            res[name] = {"dE": round(float(dE[k].mean()), 1), "pixels": int(k.sum()),
                         "p99": round(float(np.percentile(dE[ki], 99)), 1) if ki.sum() > 50 else None}
    return res, model, paint


def runs_of(mask_line):
    m = np.concatenate([[False], mask_line, [False]])
    return int((np.diff(m.astype(int)) == 1).sum())


def doubled(fbx):
    """round D gate: no strap, belt or trim shows twice. Leather (dark brown) and cream bands are counted along lines
    across the chest, the belt and the brow in the front view, in the painting and in the model; the model may not
    have more (thin runs of 3 px or less are noise)"""
    model = render_front(fbx)
    paint = masks()[1]
    out = {}
    for name, (axis, at, a0, a1, kind) in {"strap (chest, rows 400 and 440)": ("row", (400, 440), 225, 420, "leather"),
                                          "belt (columns 250 and 390)": ("col", (250, 390), 470, 600, "leather"),
                                          "trim (column 321, over the brow)": ("col", (321,), 60, 200, "cream")}.items():
        cnt = []
        for img in (paint, np.where(model[..., 3:4] > 0.5, model[..., :3], 1)):
            L = lab(img)
            if kind == "leather":
                # (leather by its colour, light or dark: a painted highlight along the strap is still the strap; the
                # gold buckles count as part of it)
                m = (L[..., 0] < 72) & (L[..., 1] > 8) & (L[..., 2] > 10) | ((L[..., 1] > -2) & (L[..., 2] > 45) & (L[..., 0] < 85))
            else:
                m = (L[..., 0] > 78) & (abs(L[..., 1]) < 8) & (L[..., 2] > 15)
            m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
            # (a light painted stroke across a band splits it by a few pixels; a second band drawn elsewhere is a band
            # width away: gaps up to 6 px are closed)
            m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)) > 0
            c = 0
            for v in at:
                line = m[v, a0:a1] if axis == "row" else m[a0:a1, v]
                c = max(c, runs_of(line))
            cnt.append(c)
        out[name] = {"painting": cnt[0], "model": cnt[1], "ok": cnt[1] <= cnt[0]}
    return out


def lab(rgb):
    return cv2.cvtColor(rgb.astype(np.float32), cv2.COLOR_RGB2Lab)


def masks():
    cls, im = classes(SHEET)
    cls, im = cls[:H, X0:X0 + W], im[:H, X0:X0 + W]
    L = lab(im)
    yy, xx = np.mgrid[0:H, 0:W]
    CX = SPEC["cx"] - X0
    fg = cls != "."
    hair = np.zeros((H, W), bool)
    for r in SPEC["fringe"]:
        for a, b in r["runs"]:
            x0 = int(round(a / SPEC["scale"] + SPEC["cx"])) - X0
            x1 = int(round(b / SPEC["scale"] + SPEC["cx"])) - X0
            hair[r["y"]:r["y"] + 2, x0:x1 + 1] = True
    skin = (L[..., 0] > 55) & (L[..., 1] > 7) & (L[..., 2] > 20) & fg
    # (above row 318: below it the model's trim crosses the chin about 20 px higher than painted, a shape difference
    # since round A that is reported on its own, not a mark in the paint)
    face = skin & (yy > 100) & (yy < CHIN_ROW) & (abs(xx - CX) < 130) & ~hair
    marks = np.zeros((H, W), bool)
    for boxes in SPEC["marks"].values():
        for x0, y0, x1, y1 in boxes:
            marks[y0 - 4:y1 + 4, x0 - X0 - 4:x1 - X0 + 4] = True
    nose = np.zeros((H, W), bool)
    nose[NOSE[1]:NOSE[3], NOSE[0] - X0:NOSE[2] - X0] = True
    green = cls == "g"
    hood = green & (yy < 345)
    tunic = green & (yy >= 345) & (yy < 650) & (abs(xx - CX) < 125)
    arms = fg & (yy > 380) & (yy < 620) & (abs(xx - CX) > 135)
    boots = fg & (yy > 706) & (yy < GROUND_ROW())
    return dict(hair=hair, face=face & ~marks & ~nose, hood=hood, tunic=tunic, arms=arms, boots=boots), im, face, marks, nose


def GROUND_ROW():
    return SPEC["ground"] - 4


def stroke(rgb, m):
    """the brush-stroke number of scripts/archer_painterly.py on one part: mean small-scale light change inside it,
    strongest 15 % of edges left out"""
    g = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(float)
    hp = np.abs(g - cv2.GaussianBlur(g, (0, 0), 3))
    edge = np.abs(cv2.Laplacian(g, cv2.CV_64F))
    inner = cv2.erode(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    if inner.sum() < 50:
        return None
    k = inner & (edge < np.percentile(edge[inner], 85))
    return round(float(hp[k].mean()), 2)


def score(fbx):
    model = render_front(fbx)
    parts, paint, face_all, marks, nose = masks()
    alpha = model[..., 3] > 0.5
    mrgb = model[..., :3]
    Lm, Lp = lab(mrgb), lab(paint)
    dE = np.sqrt(((Lm - Lp) ** 2).sum(-1))
    out = {}
    for name, m in parts.items():
        k = m & alpha
        if k.sum() < 50:
            out[name] = None
            continue
        mid = float(np.sqrt(((np.median(Lm[k], axis=0) - np.median(Lp[k], axis=0)) ** 2).sum()))
        out[name] = {"dE": round(float(dE[k].mean()), 1), "dE_mid": round(mid, 1), "pixels": int(k.sum()),
                     "stroke": stroke(mrgb, k), "stroke_painting": stroke(paint, k)}
    # the face gate, on the face's skin 3 px in from its edges (where the trim, the hair and the hood's inside meet the
    # skin, outlines line up only to a pixel or two)
    k = (cv2.erode(parts["face"].astype(np.uint8), np.ones((7, 7), np.uint8)) > 0) & alpha
    p99 = float(np.percentile(dE[k], 99))
    dark = k & (Lm[..., 0] < Lp[..., 0] - 12)
    n, lab_im, stats, _ = cv2.connectedComponentsWithStats(dark.astype(np.uint8), connectivity=8)
    biggest = int(stats[1:, cv2.CC_STAT_AREA].max()) if n > 1 else 0
    share = biggest / max(1, k.sum())
    out["face_gate"] = {"p99": round(p99, 1), "biggest_dark_patch": round(100 * share, 2), "ok": bool(p99 < 12 and share <= 0.005)}
    # round D: hood, tunic, arms and boots in the side and back views too; the hood's back against the back painting
    out["side"], _, _ = score_view(fbx, "side")
    out["back"], _, _ = score_view(fbx, "back")
    out["three_views"] = {}
    for part in ("hood", "tunic", "arms", "boots"):
        vals = [v[part]["dE"] for v in (out.get(part) or {}, out["side"].get(part) or {}, out["back"].get(part) or {}) if v and "dE" in v]             if False else [x for x in ((out.get(part) or {}).get("dE"), (out["side"].get(part) or {}).get("dE"), (out["back"].get(part) or {}).get("dE")) if x is not None]
        out["three_views"][part] = round(float(np.mean(vals)), 1) if vals else None
    out["hood_back_p99"] = (out["back"].get("hood") or {}).get("p99")
    out["doubled"] = doubled(fbx)
    # a picture: painting | model | difference on the face, for the review
    y0, y1, x0, x1 = 90, 340, 170, 470
    diff = np.clip(dE / 30, 0, 1)
    heat = np.dstack([diff, 1 - diff, np.zeros_like(diff)])
    heat[~k] = 1
    row = np.hstack([paint[y0:y1, x0:x1], np.where(alpha[y0:y1, x0:x1, None], mrgb[y0:y1, x0:x1], 1), heat[y0:y1, x0:x1]])
    Image.fromarray((row * 255).astype(np.uint8)).resize((row.shape[1] * 2, row.shape[0] * 2), Image.NEAREST).save(fbx[:-4] + "_face_gate.png")
    return out


def main():
    fbx = os.path.abspath(sys.argv[1])
    res = score(fbx)
    for k, v in res.items():
        print(k, v)
    if "--json" in sys.argv:
        json.dump(res, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)


if __name__ == "__main__":
    main()
