"""The coordinator's round C trial (Flame Cannon level 2 only): the painterly pass with 12 views (8 round the tower, 4
from above) instead of the pets' 4, and where no view sees a spot straight on, the current paint stays (no painter's
tone). Tells whether the pass can beat the current paint once most of the surface gets direct paint.
  python scripts/tower_painterly12.py <kind> <level> [--reuse]
Needs tools/towers_paint/<kind>_l<level>/paint (pack.fbx, pack_base.png, cells.json from scripts/tower_painterly.py).
Out: tools/towers_paint/<kind>_l<level>_v12/ (views, sheet, painted sheet, the parts' pictures, score.txt)."""
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import tower_painterly as TP  # noqa: E402
from tower_paint import codex_paint  # noqa: E402

BLENDER = TP.BLENDER
PROMPT = """Image 1 is a model sheet: the same 3D defense tower model seen from twelve sides in a 4 by 4 grid on a white
ground (rows 1 and 2: eight views round the tower; row 3: four views from above; row 4 is empty). Image 2 is the concept
painting of this tower.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
soft painterly strokes, rich warm shading with light from the top left, small painted details (stone edges and gaps,
wood grain, metal rims and rivets, flames and glow, leaves, as image 2 shows them), matte, no shine.

Hard rules: keep the 4 by 4 layout. Every view stays in exactly the same place, at the same size, with exactly the
same outline as in image 1: do not move, turn, resize, add or remove any part. Paint only what each view shows. Row 4
stays empty white. Plain pure white background, no ground, no shadows, no text, no border, no extra objects. Square
image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


def main():
    kind, level = sys.argv[1], int(sys.argv[2])
    name = f"tower_{kind}_l{level}"
    src = os.path.join(ROOT, "tools", "towers_paint", f"{kind}_l{level}")
    pack, base = os.path.join(src, "paint", "pack.fbx"), os.path.join(src, "paint", "pack_base.png")
    out = src + "_v12"
    os.makedirs(out, exist_ok=True)
    if not os.path.exists(os.path.join(out, "cams.json")):
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "project12.py"), "--", "views", pack, base, out], capture_output=True)
    A = Image.open(base).convert("RGB")
    if not os.path.exists(os.path.join(out, "atlas_pos.npy")):
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "project12.py"), "--", "bake", pack, out, str(A.width)], capture_output=True)
    cams = json.load(open(os.path.join(out, "cams.json")))
    C = cams["cell"]
    views = cams["views"]
    # the sheet
    sheet = Image.new("RGB", (C * 4, C * 4), "white")
    alphas = []
    for i, v in enumerate(views):
        im = Image.open(os.path.join(out, v["name"] + ".png")).convert("RGBA")
        alphas.append(np.asarray(im)[..., 3] > 127)
        sheet.paste(im, ((i % 4) * C, (i // 4) * C), im)
    sheet_path = os.path.join(out, "views12.png")
    sheet.save(sheet_path)
    painted = os.path.join(out, "painted12.png")
    if "--reuse" not in sys.argv or not os.path.exists(painted):
        if os.path.exists(painted):
            os.remove(painted)
        codex_paint(PROMPT.format(name=os.path.basename(painted)), os.path.basename(painted), out,
                    [sheet_path, os.path.join(ROOT, "art", "ref3d", f"{name}.png")])
    P = np.asarray(Image.open(painted).convert("RGB").resize((C * 4, C * 4), Image.LANCZOS)).astype(float) / 255
    # the atlas' texels: where they are on the model and which way they face
    code = json.load(open(os.path.join(out, "atlas_code.json")))
    lo, ext = np.array(code["lo"]), code["ext"]
    pos = np.load(os.path.join(out, "atlas_pos.npy"))
    nrm = np.load(os.path.join(out, "atlas_nrm.npy"))
    valid = pos[..., 3] > 0.5
    p = pos[..., :3][valid] * ext + lo
    n = nrm[..., :3][valid] * 2 - 1
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    acc = np.zeros((len(p), 3))
    wsum = np.zeros(len(p))
    centre, span = np.array(cams["centre"]), cams["span"]
    used, skipped = [], []
    for i, v in enumerate(views):
        cell = P[(i // 4) * C:(i // 4 + 1) * C, (i % 4) * C:(i % 4 + 1) * C]
        pm = cell.min(-1) < 0.93
        iou = (pm & alphas[i]).sum() / max(1, (pm | alphas[i]).sum())
        if iou < 0.62:          # (the pets' rule: a view whose outline moved is left out)
            skipped.append(f"{v['name']} ({iou:.0%})")
            continue
        used.append(v["name"])
        d, r, u = np.array(v["d"]), np.array(v["right"]), np.array(v["up"])
        rel = p - centre
        x = (rel @ r) / span * C + C / 2
        y = C / 2 - (rel @ u) / span * C
        xi, yi = np.clip(x.astype(int), 0, C - 1), np.clip(y.astype(int), 0, C - 1)
        where = np.load(os.path.join(out, v["name"] + "_where.npy"))
        q = where[yi, xi, :3] * ext + lo
        seen = (where[yi, xi, 3] > 0.5) & (np.linalg.norm(q - p, axis=1) < 0.04 * ext / 4) & (x >= 0) & (x < C) & (y >= 0) & (y < C)
        facing = np.clip(-(n @ d), 0, 1)
        w = np.where(seen, facing ** 4, 0)
        acc += cell[yi, xi] * w[:, None]
        wsum += w
    # straight-on paint where a view sees the texel well; the current paint where none does (no painter's tone)
    alpha = np.clip(wsum / 0.25, 0, 1)
    base_px = np.asarray(A).astype(float)[valid] / 255
    mix = base_px * (1 - alpha[:, None]) + (acc / np.maximum(wsum, 1e-6)[:, None]) * alpha[:, None]
    atlas = np.asarray(A).astype(float) / 255
    atlas[valid] = mix
    direct = float((alpha > 0.5).mean())
    atlas_path = os.path.join(out, "pack_painted12.png")
    Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8)).save(atlas_path)
    # cut back into the parts' pictures; the model and the rest of its files from the "before" copy
    before = os.path.join(src, "before")
    for f in os.listdir(before):
        shutil.copy(os.path.join(before, f), os.path.join(out, f))
    cells = json.load(open(os.path.join(src, "paint", "cells.json")))
    a = Image.open(atlas_path).convert("RGB")
    c = a.width // cells["n"]
    for part, info in cells["parts"].items():
        a.crop((info["cx"] * c, info["cy"] * c, (info["cx"] + 1) * c, (info["cy"] + 1) * c)).resize(
            (info["size"], info["size"]), Image.LANCZOS).save(os.path.join(out, os.path.basename(info["texture"])))
    picture = os.path.join(ROOT, "art", "ref3d", f"{name}.png")
    sb = TP.score(os.path.join(before, name + ".fbx"), picture, os.path.join(out, "score_before.png"))
    sa = TP.score(os.path.join(out, name + ".fbx"), picture, os.path.join(out, "score_after.png"))
    txt = (f"{name} (12 views)\nbefore: {sb[0] if sb else '?'}\nafter:  {sa[0] if sa else '?'}\n"
           f"direct paint on {direct:.0%} of the surface (4 views gave 20-37%)\nviews used: {', '.join(used)}\n"
           f"skipped: {', '.join(skipped) or 'none'}\n")
    open(os.path.join(out, "score.txt"), "w").write(txt)
    print(txt)


if __name__ == "__main__":
    main()
