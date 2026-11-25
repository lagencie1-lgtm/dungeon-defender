"""Two towers' tops compared offline, as scripts/tower_rules.py compares them in the film (top 40 % of the outline,
IoU), from the 32-degree run camera at several sides; outlines lined up by their bottoms and centres at one scale
(the same studs per pixel for both, like the game).
  python scripts/top40_check.py a.fbx b.fbx"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
SCRIPT = os.path.join(ROOT, "art", "blender", "parts_render.py")


def mask(fbx, az, out):
    subprocess.run([BLENDER, "-b", "-P", SCRIPT, "--", fbx, out, str(az), "32", "512", "ortho"], capture_output=True,
                   env=dict(os.environ, HTD_GREY="1", HTD_FRAME="0,0,3.5,14"))   # (one fixed frame: both at one scale)
    return np.asarray(Image.open(out).convert("RGBA"))[..., 3] > 40


def top40(m):
    rows = np.where(m.any(1))[0]
    out = m.copy()
    out[rows.min() + int(0.4 * (rows.max() - rows.min() + 1)):] = False
    return out


def align(m):
    ys, xs = np.nonzero(m)
    canvas = np.zeros((700, 700), bool)
    dy, dx = 650 - ys.max(), 350 - int(xs.mean())
    canvas[ys + dy, xs + dx] = True
    return canvas


a, b = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
vals = []
for az in (-75, -30, 15, 60, 105, 150):
    ma, mb = align(mask(a, az, a[:-4] + "_t40a.png")), align(mask(b, az, b[:-4] + "_t40b.png"))
    ta, tb = top40(ma), top40(mb)
    v = 100 * (ta & tb).sum() / max(1, (ta | tb).sum())
    vals.append(v)
    print(f"az {az}: top-40 overlap {v:.1f}%")
print(f"TOP40 mean {np.mean(vals):.1f}%  max {np.max(vals):.1f}%")
