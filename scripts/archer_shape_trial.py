"""Shape trial for the hood (round C): build without paint, then the side gates and the three-quarter overlaps.
  python scripts/archer_shape_trial.py <out dir> [ENV=value ...]"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import archer_compare as C  # noqa: E402
import archer_gates as G  # noqa: E402


def three_quarter(fbx, d, save=None):
    """whole figure (no bow, no quiver) against the elf 3/4 sheet, boxes fitted: overlap per side, as round B"""
    out, ims = {}, []
    # (the sheet's left figure faces the viewer's right: it is the model turned to -135, not -45; round B had the two
    # swapped, which put the hood's back on the wrong side of the painting's)
    for nm, idx, az in (("left", 0, -135), ("right", 1, -45)):
        p = C.view("ranger_archer_elf34.png", idx)
        path = os.path.join(d, f"q_{idx}_{az}.png")
        G.render(fbx, path, az, el=4, grey=True, skip="Bow,Quiver", mode="ortho")
        m = Image.open(path)

        def fit(im, white):
            a = np.asarray(im.convert("RGBA")).astype(int)
            msk = (a[..., :3].min(-1) < 235) & (a[..., 3] > 0) if white else a[..., 3] > 20
            ys, xs = np.where(msk)
            c = msk[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8) * 255
            return np.asarray(Image.fromarray(c).resize((400, 560), Image.NEAREST)) > 127
        a, b = fit(m, False), fit(p, True)
        out[nm] = round(float(100 * (a & b).sum() / (a | b).sum()), 1)
        ov = np.zeros((560, 400, 3), np.uint8) + 255
        ov[b] = (120, 170, 255)
        ov[a & ~b] = (255, 140, 120)
        ov[a & b] = (90, 90, 90)
        ims.append(Image.fromarray(ov))
    if save:
        s = Image.new("RGB", (820, 560), (255, 255, 255))
        s.paste(ims[0], (0, 0))
        s.paste(ims[1], (420, 0))
        s.save(save)
    return out


def main():
    d = os.path.join(ROOT, sys.argv[1])
    env = dict(os.environ, HTD_NO_BAKE="1")
    for a in sys.argv[2:]:
        k, v = a.split("=", 1)
        env[k] = v
    r = subprocess.run([G.BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "archer_loft.py"), "--", d],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore", env=env)
    if "EXPORTED" not in r.stdout:
        print(r.stdout[-2000:])
        raise SystemExit("build failed")
    fbx = os.path.join(d, "ranger_archer.fbx")
    hs = G.hood_side(fbx, d)
    print("SIDE", hs)
    print("3/4", three_quarter(fbx, d, os.path.join(d, "three_quarter_overlays.png")))


if __name__ == "__main__":
    main()
