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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tower_stage import AZIMUTH, kind_of  # noqa: E402

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
    import glob
    for skin in glob.glob(fbx[:-4] + "_paint_*.png"):   # the other parts (tower kit atlases), sharpened the same way
        other = fbx[:-4] + "_ungraded_" + skin[len(fbx[:-4] + "_paint_"):]
        from PIL import ImageFilter as _F
        Image.open(skin).convert("RGB").filter(_F.UnsharpMask(radius=2, percent=55, threshold=2)).save(other)
        shutil.copy(other, skin)
    # crisp painted edges like the picture (the projection softens them a little): a light unsharp mask first, so
    # the grade below measures the sharpened paint
    from PIL import ImageFilter
    Image.open(keep).convert("RGB").filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2)).save(keep)
    shutil.copy(keep, paint)
    render = fbx[:-4] + "_grade_render.png"
    kind = kind_of(fbx)
    scored = fbx
    if kind == "barricade":   # graded on the centre section the picture shows (scripts/tower_round.py)
        import tower_round
        from tower_stage import stage
        scored = tower_round.centre_model(stage(kind, os.path.basename(fbx)[:-4].split("_")[2]), fbx)
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", scored, render,
                    str(AZIMUTH.get(kind, -75.0)), "15", "512"], capture_output=True)
    pic = Image.open(picture).convert("RGB")
    pp = pic.load()
    ren = Image.open(render).convert("RGBA")
    rp = ren.load()
    want = band_means(pic, lambda x, y: min(pp[x, y]) < 238)
    have = band_means(ren, lambda x, y: rp[x, y][3] > 200)
    gains = []
    # HTD_GRADE_CHROMA: how far one colour channel's gain may stray from the band's mean gain (unset = free); the
    # barricade's grade tinted the parts the picture never shows (log ends pink, bands purple, rope green) at 0.2
    spread = float(os.environ["HTD_GRADE_CHROMA"]) if os.environ.get("HTD_GRADE_CHROMA") else None
    for wv, hv in zip(want, have):
        lo, hi = (float(v) for v in os.environ.get("HTD_GRADE_RANGE", "0.8,1.2").split(","))
        g = [max(lo, min(hi, (wv[i] / max(1e-4, hv[i])) ** strength)) for i in range(3)]
        if spread is not None:
            m = sum(g) / 3
            g = [max(m - spread, min(m + spread, x)) for x in g]
        gains.append(g)
    path = fbx[:-4] + "_gains.json"
    json.dump({"bands": gains}, open(path, "w"))
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "tower_project.py"), "--", "grade", fbx, keep, path, paint],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    print(next((ln for ln in r.stdout.splitlines() if ln.startswith("GRADED")), r.stdout[-1200:]))
    print("gains (top to bottom):", " ".join("%.2f/%.2f/%.2f" % tuple(g) for g in gains))
    os.remove(render)


if __name__ == "__main__":
    main()
