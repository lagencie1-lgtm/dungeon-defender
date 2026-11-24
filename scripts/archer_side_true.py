"""The hood seen from the side at the painting's own scale and place (no box fitting): model outline over the side
painting's outline. Blue = painting only, red = model only, grey = both.
  python scripts/archer_side_true.py <archer.fbx> <out.png>"""
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
SPEC = json.load(open(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_loft.json")))
X0, Y0, N = 630, 20, 420          # the painting's square: x 630..1050, y 20..440 (the hood and the collar)


def main():
    fbx, out = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    S, SX, G = SPEC["scale"], SPEC["sx"], SPEC["ground"]
    yc = -((X0 + N / 2) - SX) * S
    zc = (G - (Y0 + N / 2)) * S
    tmp = out[:-4] + "_render.png"
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, tmp, "180", "0",
                    str(N), "ortho"], capture_output=True,
                   env=dict(os.environ, HTD_GREY="1", HTD_SKIP=sys.argv[3] if len(sys.argv) > 3 else "Body,ArmR,ArmL,Bow,Quiver",
                            HTD_FRAME=f"0,{yc},{zc},{N * S}"))
    m = np.asarray(Image.open(tmp).convert("RGBA"))[..., 3] > 127
    p = np.asarray(Image.open(os.path.join(ROOT, "art", "ref3d", "archer", SPEC["sheet"])).convert("RGB"))[Y0:Y0 + N, X0:X0 + N].min(axis=2) < 235
    ov = np.zeros((N, N, 3), np.uint8) + 255
    ov[p] = (120, 170, 255)
    ov[m & ~p] = (255, 140, 120)
    ov[m & p] = (90, 90, 90)
    Image.fromarray(ov).resize((N * 2, N * 2), Image.NEAREST).save(out)
    print("SIDE TRUE", out)


if __name__ == "__main__":
    main()


def rows_report(fbx_render, step=10):
    """per painting row: the back edge (x, pixels) of the model and of the painting, and the top"""
    m = np.asarray(Image.open(fbx_render).convert("RGBA"))[..., 3] > 127
    p = np.asarray(Image.open(os.path.join(ROOT, "art", "ref3d", "archer", SPEC["sheet"])).convert("RGB"))[Y0:Y0 + N, X0:X0 + N].min(axis=2) < 235
    out = []
    for y in range(0, N, step):
        a, b = np.where(m[y])[0], np.where(p[y])[0]
        out.append((Y0 + y, int(a.min()) + X0 if len(a) else None, int(b.min()) + X0 if len(b) else None))
    return out
