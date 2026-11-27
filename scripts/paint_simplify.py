"""Phone-scale simplify pass (coordinator 2026-11-27, the shared problem Codex named and the numbers back: on the
phone every tower carries 1.26 times the painting's fine texture contrast (gradient) and 1.21 times its lightness
spread: small grain and scratches read as noise, not as the paintings' clean colour blocks). One edge-preserving
smoothing pass over each level's painted sheets (body, roof, props; not the flat gold, silver or weapon sheets);
plank seams, stone joints and colour edges stay.
  python scripts/paint_simplify.py <kind> <level> [backup dir]   (writes art/models in place)"""
import glob
import os
import shutil
import sys

import cv2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
kind, level = sys.argv[1], int(sys.argv[2])
backup = sys.argv[3] if len(sys.argv) > 3 else None
stem = os.path.join(ROOT, "art", "models", f"tower_{kind}_l{level}_paint")
for f in [stem + ".png"] + sorted(glob.glob(stem + "_*.png")):
    tag = os.path.basename(f)[len(os.path.basename(stem)):]
    if any(t in tag for t in ("gold", "silver", "barrel")):
        continue
    if backup:
        os.makedirs(backup, exist_ok=True)
        shutil.copyfile(f, os.path.join(backup, os.path.basename(f)))
    img = cv2.imread(f, cv2.IMREAD_UNCHANGED)
    k = img.shape[0] / 1024
    out = cv2.bilateralFilter(img[..., :3].copy(), 9, 40, 6 * k)
    img[..., :3] = out
    cv2.imwrite(f, img)
    print("simplified", os.path.basename(f))
