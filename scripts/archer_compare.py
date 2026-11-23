"""Painting beside model, same size: front, both three-quarter views, side and back from the archer's model sheets
(art/ref3d/archer/ranger_archer_elf.png and _elf34.png, carrying nothing), and the main painting
(ranger_archer_34.png) beside the model with its bow and quiver. Each model view is the flat painted albedo (what the
texture holds), orthographic.
Run: python scripts/archer_compare.py tools/archer4/ranger_archer.fbx reviews/archer/compare.png"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
REF = os.path.join(ROOT, "art", "ref3d", "archer")
H = 560


def crop_fg(im, bg_white=True):
    a = np.asarray(im.convert("RGBA")).astype(int)
    if bg_white:
        m = (a[..., :3].min(axis=2) < 235) & (a[..., 3] > 0)
    else:
        m = a[..., 3] > 20
    ys, xs = np.where(m)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    out = Image.new("RGB", im.size, (255, 255, 255))
    out.paste(im.convert("RGBA"), (0, 0), im.convert("RGBA"))
    c = out.crop(box)
    return c.resize((max(1, int(c.width * H / c.height)), H), Image.LANCZOS)


def view(sheet, idx):
    im = Image.open(os.path.join(REF, sheet)).convert("RGB")
    a = np.asarray(im).min(axis=2) < 235
    cols = np.where(a.any(0))[0]
    groups, s, p = [], cols[0], cols[0]
    for c in cols[1:]:
        if c - p > 20:
            groups.append((s, p))
            s = c
        p = c
    groups.append((s, p))
    x0, x1 = groups[idx]
    return crop_fg(im.crop((x0, 0, x1 + 1, im.height)))


def render(fbx, out, az, skip):
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out, str(az), "4", "1024", "ortho"],
                   capture_output=True, env=dict(os.environ, HTD_SKIP=skip, HTD_GREY=""))
    return crop_fg(Image.open(out), bg_white=False)


def main():
    fbx, out = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    tmp = os.path.join(os.path.dirname(fbx), "cmp")
    os.makedirs(tmp, exist_ok=True)
    pairs = [("front", view("ranger_archer_elf.png", 0), -90, "Bow,Quiver"),
             ("3/4 front-left", view("ranger_archer_elf34.png", 0), -45, "Bow,Quiver"),
             ("3/4 front-right", view("ranger_archer_elf34.png", 1), -135, "Bow,Quiver"),
             ("side", view("ranger_archer_elf.png", 1), 180, "Bow,Quiver"),
             ("back", view("ranger_archer_elf.png", 2), 90, "Bow,Quiver"),
             ("main painting", crop_fg(Image.open(os.path.join(REF, "ranger_archer_34.png"))), -125, "")]
    cols = []
    for name, paint, az, skip in pairs:
        model = render(fbx, os.path.join(tmp, f"cmp_{az}.png"), az, skip)
        w = max(paint.width, model.width)
        col = Image.new("RGB", (w + 20, H * 2 + 70), (255, 255, 255))
        col.paste(paint, ((w - paint.width) // 2 + 10, 30))
        col.paste(model, ((w - model.width) // 2 + 10, H + 60))
        d = ImageDraw.Draw(col)
        d.text((10, 8), f"{name}: painting", fill=(40, 40, 40))
        d.text((10, H + 38), "model", fill=(40, 40, 40))
        cols.append(col)
    sheet = Image.new("RGB", (sum(c.width for c in cols), cols[0].height), (255, 255, 255))
    x = 0
    for c in cols:
        sheet.paste(c, (x, 0))
        x += c.width
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
