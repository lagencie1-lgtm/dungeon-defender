"""Offline estimate of the film's 'levels tell apart' overlap (scripts/tower_rules.py): fast builds of a tower's
levels drawn at the run camera's angle (Blender az -53, el 32, one fixed frame so the scale is the game's), lined up
by bottom and centre as on the placement spot, whole-outline IoU per pair.
  python scripts/level_overlap.py <kind> [fbx1 fbx2 fbx3]   (default: fast builds of the current params)"""
import itertools
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
kind = sys.argv[1]
fbxs = sys.argv[2:5]
tmp = os.path.join(ROOT, "tools", "lvl")
os.makedirs(tmp, exist_ok=True)
masks = {}
for l in (1, 2, 3):
    fbx = fbxs[l - 1] if fbxs else os.path.join(tmp, f"{kind}{l}.fbx")
    if not fbxs:
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", f"tower_{kind}_detail.py"), "--", fbx, str(l)],
                       capture_output=True, env=dict(os.environ, HTD_FAST="1"))
    out = os.path.join(tmp, f"{kind}{l}.png")
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out, "-53", "32", "512", "ortho"],
                   capture_output=True, env=dict(os.environ, HTD_GREY="1", HTD_FRAME="0,0,6,20"))
    m = np.asarray(Image.open(out).convert("RGBA"))[..., 3] > 40
    ys, xs = np.nonzero(m)
    c = np.zeros((800, 800), bool)
    c[ys + (760 - ys.max()), xs + (400 - int(xs.mean()))] = True
    masks[l] = c
for a, b in itertools.combinations((1, 2, 3), 2):
    print(f"{kind} {a}-{b}: {100 * (masks[a] & masks[b]).sum() / (masks[a] | masks[b]).sum():.1f}%")
