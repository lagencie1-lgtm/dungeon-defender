"""The painterly number (coordinator 2026-11-23, gate of the painterly pass): the pets' own "detail" measure from
scripts/pet_match.py (mean edge strength inside the outline at 256 px, as a percent of the target painting's), for
the archer seen like his main painting (art/ref3d/archer/ranger_archer_34.png). It must sit within BAND points of
the Baby Dragon's latest value (reviews/pets/match.csv), the pet Lemp's painterly choice was made on.

  python scripts/archer_painterly.py <archer.fbx> [round note]    -> prints the number, appends to reviews/archer/rounds.md
"""
import csv
import datetime
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import pet_match  # noqa: E402  (its cutout and stats, used as they are; nothing written to the pets' files)

BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
BAND = 20
GREY = (41, 41, 46)


def baby_dragon():
    rows = [r for r in csv.reader(open(os.path.join(ROOT, "reviews", "pets", "match.csv"), encoding="utf-8")) if len(r) > 6 and r[1] == "babydragon"]
    return float(rows[-1][6])


def detail_of(fbx, az=-125):
    out = os.path.join(os.path.dirname(fbx), f"painterly_{az}.png")
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out, str(az), "4", "768", "ortho"],
                   capture_output=True, env=dict(os.environ, HTD_GREY="", HTD_SKIP=""))
    im = Image.open(out).convert("RGBA")
    bg = Image.new("RGB", im.size, GREY)
    bg.paste(im, (0, 0), im)
    flat = out[:-4] + "_grey.png"
    bg.save(flat)
    target = pet_match.cutout(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_34.png"), (255, 255, 255))
    model = pet_match.cutout(flat, GREY)
    global STROKE
    STROKE = (stroke(model), stroke(target))
    ts, te = pet_match.stats(target)
    ms, me = pet_match.stats(model)
    return 100 * me / te, 100 * ms / ts


def stroke(img):
    """brush-stroke texture: mean small-scale light change (image minus a 3 px blur) inside the outline, leaving out
    the strongest 15 % of edges (part borders, outline): what the pets' edge measure cannot tell from geometry"""
    import numpy as np
    from PIL import ImageFilter
    a = np.asarray(img.split()[3].filter(ImageFilter.MinFilter(9))) > 128
    g = img.convert("RGB").convert("L")
    hp = np.abs(np.asarray(g, dtype=float) - np.asarray(g.filter(ImageFilter.GaussianBlur(3)), dtype=float))
    edge = np.asarray(g.filter(ImageFilter.FIND_EDGES), dtype=float)
    m = a & (edge < np.percentile(edge[a], 85))
    return float(hp[m].mean())


def main():
    fbx = os.path.abspath(sys.argv[1])
    note = sys.argv[2] if len(sys.argv) > 2 else ""
    detail, rich = detail_of(fbx)
    ref = baby_dragon()
    dragon = pet_match.cutout(os.path.join(ROOT, "art", "models", "pets2", "_v_babydragon_0.png"), GREY)
    ds = stroke(dragon)
    ok = abs(detail - ref) <= BAND
    line = (f"{datetime.datetime.now():%Y-%m-%d %H:%M}  painterly (pets' detail measure) {detail:.0f}%  rich {rich:.0f}%  "
            f"Baby Dragon {ref:.0f}%  band +-{BAND}: {'PASS' if ok else 'FAIL'}  |  stroke texture {STROKE[0]:.2f} "
            f"(painting {STROKE[1]:.2f}, Baby Dragon {ds:.2f})  {os.path.relpath(fbx, ROOT)}  {note}")
    print(line)
    log = os.path.join(ROOT, "reviews", "archer", "rounds.md")
    with open(log, "a", encoding="utf-8") as f:
        f.write("\n- " + line)
    print("PAINTERLY", "PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
