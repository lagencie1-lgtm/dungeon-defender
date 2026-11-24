"""Round D (coordinator D1-D3): the archer's cloth painted straight from his clean model sheet
(art/ref3d/archer/ranger_archer_elf.png: front, his right side, back; the side mirrored for his left side).

  python scripts/archer_sheet_paint.py <build dir> <painted dir> <out dir>

<build dir>: the plain build (its tags maps, its head_keep.png, and sheet/ from art/blender/archer_sheet_where.py).
<painted dir>: the painterly pass of that build: what fills where no painting sees the surface well.
For each texel of hood, tunic, sleeves, trousers and boots (by the build's tag maps; the face and hair stay as they
are), and for each of the four views that sees it (nothing in the way) within 50 degrees of square on: the sheet's
colour there, weighted by how squarely the texel faces that view (0 at 50 degrees, 1 square on). Blended over the
painterly fill by how well it is seen. D2: modelled details (trim, belt, strap, buckles, cuffs, hem, bracers, collar)
keep their own paint, and a cloth texel only takes cloth colour: where the painting shows a detail at that spot (it is
drawn a little elsewhere on the model), the colour comes from the painting's nearest cloth of the same kind, so
nothing shows twice."""
import json
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SPEC = json.load(open(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_loft.json")))
SHEET = os.path.join(ROOT, "art", "ref3d", "archer", SPEC["sheet"])
NAME = "ranger_archer"
S, CX, SX, G = SPEC["scale"], SPEC["cx"], SPEC["sx"], SPEC["ground"]
COS50 = np.cos(np.radians(50))
# which tags are cloth, and the painting's colour class each takes
CLOTH = {"hood": "green", "tunic": "green", "trousers": "brown", "boot": "brown", "boot_cuff": "brown"}
ARM_SKIN = "skin"     # the forearms and fists (not the face)
BANDS = {"front": (0, 620), "right": (620, 1100), "left": (620, 1100), "back": (1100, 1774)}


def classes(lab):
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    return {"green": (a < -8) & ~((L > 70) & (b > 55)),   # (lime trims are light and very yellow: not cloth)
            "brown": (a > 12) & (b > 20) & (L < 55),
            "skin": (L > 55) & (a > 15) & (b > 30)}


def filled(img, valid):
    """every pixel takes the colour of the nearest valid pixel (the painting's cloth spread over its details), and how
    far that pixel is (a colour from further than a few pixels is not used: it smeared into streaks)"""
    if not valid.any():
        return img, np.full(valid.shape, 1e9)
    dist, idx = ndimage.distance_transform_edt(~valid, return_indices=True)
    return img[idx[0], idx[1]], dist


def main():
    build, painted, out = (os.path.abspath(a) for a in sys.argv[1:4])
    os.makedirs(out, exist_ok=True)
    sheet_dir = os.path.join(build, "sheet")
    code = json.load(open(os.path.join(sheet_dir, "code.json")))
    lo, ext, BX, N = np.array(code["lo"]), code["ext"], code["bx"], code["n"]
    tags = json.load(open(os.path.join(build, "tags.json")))
    paint = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.float32) / 255
    lab = cv2.cvtColor(paint, cv2.COLOR_RGB2Lab)
    cls = classes(lab)
    fills = {}
    # inside the painted figure, 5 px in from its outline (its dark outline line and the outlines' small misfits stay out)
    # (a soft ramp, 0 at 4 px in, 1 at 16 px in: hard cut-offs left stepped lines where one view's colour gave way
    # to another's)
    inside = np.clip((ndimage.distance_transform_edt(paint.min(-1) < 0.92) - 4) / 12, 0, 1)
    for view, (c0, c1) in BANDS.items():
        for k, m in cls.items():
            band = np.zeros(m.shape, bool)
            band[:, c0:c1] = True
            img = paint.copy()
            img[:, :c0] = 0
            img[:, c1:] = 0
            f_img, f_dist = filled(img, m & band)
            fills[(view, k)] = (f_img, f_dist)
            # (the hood's own fills, softened: its painted folds land a little off on the model's hood, and sharp they
            # showed as bars on the back; soft they give the shading and the ridge without the bars)
            fills[(view, k, "soft")] = (cv2.GaussianBlur(f_img, (0, 0), float(os.environ.get("HTD_HOOD_SOFT", "5"))), f_dist)
    where = {v: np.load(os.path.join(sheet_dir, f"{v}_where.npy")) for v in ("front", "back", "right", "left")}
    keep_head = np.asarray(Image.open(os.path.join(build, f"{NAME}_head_keep.png")).convert("L")).astype(float) / 255
    report = {}
    for part, size in (("head", 1024), ("body", 1024), ("arml", 512), ("armr", 512)):
        base = np.asarray(Image.open(os.path.join(painted, f"{NAME}_{part}_paint.png")).convert("RGB")).astype(np.float32) / 255
        pos = np.load(os.path.join(sheet_dir, f"{part}_pos.npy"))
        nrm = np.load(os.path.join(sheet_dir, f"{part}_nrm.npy"))
        tg = np.load(os.path.join(build, f"{NAME}_{part}_tags.npy"))
        tagname = np.array(tags + ["?"] * 64)[np.clip(tg, 0, len(tags))]
        valid = pos[..., :3].sum(-1) > 0   # (the bake fills alpha everywhere; a texel of the model has a position)
        kind = np.full(tg.shape, "", dtype="<U8")
        for t, k in CLOTH.items():
            kind[tagname == t] = k
        if part in ("arml", "armr"):
            kind[tagname == "skin"] = ARM_SKIN
        if part == "head":
            kind[keep_head > 0.1] = ""        # the face and hair are the front painting already
        todo = valid & (kind != "")
        p = pos[..., :3][todo] * ext + lo
        n = nrm[..., :3][todo] * 2 - 1
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
        k_of = kind[todo]
        acc = np.zeros((len(p), 3), np.float32)
        wsum = np.zeros(len(p), np.float32)
        X, Y, Z = p[:, 0], p[:, 1], p[:, 2]
        py = G - Z / S
        for view, toward, px, rcol in (("front", (0, -1, 0), CX + X / S, N / 2 + X / S),
                                       ("back", (0, 1, 0), BX - X / S, N / 2 - X / S),
                                       ("right", (-1, 0, 0), SX - Y / S, N / 2 - Y / S),
                                       ("left", (1, 0, 0), SX - Y / S, N / 2 + Y / S)):
            f = n @ np.array(toward, dtype=float)
            w = np.clip((f - COS50) / (1 - COS50), 0, 1)
            ri, ci = np.clip(py.astype(int), 0, N - 1), np.clip(rcol.astype(int), 0, N - 1)
            wm = where[view][ri, ci]
            q = wm[:, :3] * ext + lo
            seen = (wm[:, 3] > 0.5) & (np.linalg.norm(q - p, axis=1) < 0.05)
            w = np.where(seen, w, 0)
            pxi, pyi = np.clip(px.astype(int), 0, paint.shape[1] - 1), np.clip(py.astype(int), 0, paint.shape[0] - 1)
            col = np.zeros((len(p), 3), np.float32)
            near = np.zeros(len(p), np.float32)
            for k in ("green", "brown", "skin"):
                sel = k_of == k
                img, dist = fills[(view, k, "soft")] if part == "head" else fills[(view, k)]
                col[sel] = img[pyi[sel], pxi[sel]]
                near[sel] = np.clip(1 - dist[pyi[sel], pxi[sel]] / 12, 0, 1)   # (a detail over the cloth: cloth from at most 8 px, fading)
            w = w * near * inside[pyi, pxi]
            acc += col * w[:, None]
            wsum += w
            if os.environ.get("HTD_SHEET_DEBUG") and part == "head":
                dbg = np.zeros(tg.shape + (3,), np.float32)
                dbg[todo, 0] = w
                dbg[todo, 1] = seen.astype(np.float32)
                Image.fromarray((dbg * 255).astype(np.uint8)).save(os.path.join(out, f"dbg_{view}.png"))
            report.setdefault(part, {})[view] = int((w > 0.3).sum())
        alpha = np.clip(wsum / float(os.environ.get("HTD_SHEET_FULL", "0.3")), 0, 1)   # (seen this well or better: all from the sheet)
        # (the edge between sheet colour and fill, softened over the texture: unsoftened it followed the views' pixel
        # steps and showed as stepped lines on the hood's back)
        a_img = np.zeros(tg.shape, np.float32)
        a_img[todo] = alpha
        a_img = cv2.GaussianBlur(a_img, (0, 0), 8)
        alpha = np.minimum(alpha, a_img[todo] * 1.5)
        c_img = np.zeros(base.shape, np.float32)
        c_img[todo] = acc / np.maximum(wsum, 1e-6)[:, None]
        wimg = np.zeros(tg.shape, np.float32)
        wimg[todo] = (wsum > 0).astype(np.float32)
        c_blur = cv2.GaussianBlur(c_img, (0, 0), 2) / np.maximum(cv2.GaussianBlur(wimg, (0, 0), 2), 1e-3)[..., None]
        acc = np.where((wsum > 0)[:, None], c_blur[todo] * wsum[:, None], acc)
        res = base.copy()
        sub = base[todo]
        sub = sub * (1 - alpha[:, None]) + (acc / np.maximum(wsum, 1e-6)[:, None]) * alpha[:, None]
        res[todo] = sub
        report[part]["painted_share"] = round(float((alpha > 0.5).mean()) if len(alpha) else 0, 3)
        Image.fromarray((np.clip(res, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, f"{NAME}_{part}_paint.png"))
    for f in (NAME + ".fbx", f"{NAME}_bow_paint.png", f"{NAME}_quiver_paint.png", "gates_build.json"):
        shutil.copy(os.path.join(painted, f), os.path.join(out, f))
    json.dump(report, open(os.path.join(out, "sheet_paint.json"), "w"), indent=1)
    print("SHEET PAINT", json.dumps(report))


if __name__ == "__main__":
    main()
