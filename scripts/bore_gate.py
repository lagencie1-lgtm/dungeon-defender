"""Flame Cannon bore gate (coordinator 2026-11-25): the fire is the bore's own lit inside, so a muzzle must not read
as a black hole: from the painting's angle and the run camera's, with one-sided faces as the game draws them
(render_match HTD_CULL), at most 30 % of the bore opening may be near-black (value under 15 %).
The opening is where the bore's own parts show (their glow-part names: the colours set in tower_flame_detail.barrel).
  python scripts/bore_gate.py <baked model.fbx>       -> BORE near-black share per view, GATE PASS/FAIL"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
# the bore rings, the plug and the core (c_R_G_B of their colours)
BORE = r"re:^c_(230_87_18|158_36_13|92_18_13|255_199_77)"


def render(fbx, out, el, only=None):
    env = dict(os.environ, HTD_CULL="1")
    if only:
        env["HTD_ONLY_PART"] = only
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", fbx, out, "-75", str(el), "512"],
                   capture_output=True, env=env)
    return np.asarray(Image.open(out).convert("RGBA")).astype(float)


fbx = os.path.abspath(sys.argv[1])
worst = 0.0
for el in (15, 32):
    full = render(fbx, fbx[:-4] + f"_bore_full{el}.png", el)
    only = render(fbx, fbx[:-4] + f"_bore_only{el}.png", el, BORE)
    m = only[..., 3] > 40
    if m.sum() < 30:
        print(f"BORE el {el}: no bore visible")
        continue
    v = full[..., :3].max(-1) / 255
    share = float((v[m] < 0.15).mean())
    worst = max(worst, share)
    print(f"BORE el {el}: {100 * share:.0f}% of the opening near-black ({int(m.sum())} px)")
print("GATE", "PASS" if worst <= 0.3 else "FAIL", f"(worst {100 * worst:.0f}%, needs 30% or less)")
sys.exit(0 if worst <= 0.3 else 1)
