"""Colour grade for a painted tower (docs/tower-pipeline.md): renders the model at the picture's angle, compares the
mean colour of each height band (12 bands, top to bottom) with the picture's, and multiplies the paint of every texel
by its band's gain (kept within 0.8-1.2, smoothed between bands), like a colourist matching a reference; then a light
unsharp mask gives back the crisp painted edges the projection softens.
Run: python scripts/tower_grade.py model.fbx picture.png [strength=0.8]   (rewrites <model>_paint.png, keeps
<model>_ungraded.png)"""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
BANDS = 12


def band_means(img, solid):
    w, h = img.size
    px = img.load()
    rows = [y for y in range(h) if any(solid(x, y) for x in range(0, w, 3))]
    top, bot = rows[0], rows[-1]
    sums = [[0.0, 0.0, 0.0, 0] for _ in range(BANDS)]
    for y in range(top, bot + 1, 2):
        b = min(BANDS - 1, (y - top) * BANDS // (bot - top + 1))
        for x in range(0, w, 2):
            if solid(x, y):
                r, g, bb = px[x, y][:3]
                s = sums[b]
                s[0] += (r / 255) ** 2.2
                s[1] += (g / 255) ** 2.2
                s[2] += (bb / 255) ** 2.2
                s[3] += 1
    return [[s[i] / max(1, s[3]) for i in range(3)] for s in sums]


def main():
    fbx, picture = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    strength = float(sys.argv[3]) if len(sys.argv) > 3 else 0.8
    paint = fbx[:-4] + "_paint.png"
    keep = fbx[:-4] + "_ungraded.png"
    shutil.copy(paint, keep)
    # crisp painted edges like the picture (the projection softens them a little): a light unsharp mask first, so
    # the grade below measures the sharpened paint
    from PIL import ImageFilter
    Image.open(keep).convert("RGB").filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2)).save(keep)
    shutil.copy(keep, paint)
    render = fbx[:-4] + "_grade_render.png"
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", fbx, render, "-75", "15", "512"],
                   capture_output=True)
    pic = Image.open(picture).convert("RGB")
    pp = pic.load()
    ren = Image.open(render).convert("RGBA")
    rp = ren.load()
    want = band_means(pic, lambda x, y: min(pp[x, y]) < 238)
    have = band_means(ren, lambda x, y: rp[x, y][3] > 200)
    gains = []
    for wv, hv in zip(want, have):
        gains.append([max(0.8, min(1.2, (wv[i] / max(1e-4, hv[i])) ** strength)) for i in range(3)])
    path = fbx[:-4] + "_gains.json"
    json.dump({"bands": gains}, open(path, "w"))
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "tower_project.py"), "--", "grade", fbx, keep, path, paint],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    print(next((ln for ln in r.stdout.splitlines() if ln.startswith("GRADED")), r.stdout[-1200:]))
    print("gains (top to bottom):", " ".join("%.2f/%.2f/%.2f" % tuple(g) for g in gains))
    os.remove(render)


if __name__ == "__main__":
    main()
