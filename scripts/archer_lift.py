"""Lifts the archer's paint (coordinator 2026-11-24: at the same open-ground spot the Baby Dragon and a Ranger tower
roof read 1.45 and 1.23 of their paintings' brightness, the archer's face 0.72, tunic 0.86, boots 0.91; his hood 1.14
already matches). A soft lift curve out = 1 - (1 - in)^g brightens mid and dark tones and keeps highlights; the hood's
own texels (green in the plain bake) stay as they are.
Run: python scripts/archer_lift.py <painted dir> <plain build dir> [g=1.35] [parts=body,arml,armr]
(The face is the front painting itself: in neutral light it matches it (dE 1.1); lifted it did not (10.9), so the
head is left out: its darker look in game comes from the hood's shade.)"""
import os
import sys

import numpy as np
from PIL import Image

NAME = "ranger_archer"


def main():
    out, plain = sys.argv[1], sys.argv[2]
    g = float(next((a[2:] for a in sys.argv[3:] if a.startswith("g=")), 1.35))
    parts = next((a[6:].split(",") for a in sys.argv[3:] if a.startswith("parts=")), ["head", "body", "arml", "armr"])
    for part in parts:
        path = os.path.join(out, f"{NAME}_{part}_paint.png")
        p = np.asarray(Image.open(path).convert("RGB"), dtype=float) / 255
        lifted = 1 - (1 - p) ** g
        if part == "head":
            b = np.asarray(Image.open(os.path.join(plain, f"{NAME}_head_paint.png")).convert("RGB").resize((p.shape[1], p.shape[0])), dtype=float)
            lum = b @ np.array([0.3, 0.59, 0.11])
            hood = (b[..., 1] > b[..., 0] + 8) & (b[..., 1] > b[..., 2] + 30) & (lum > 70)
            lifted[hood] = p[hood]
        Image.fromarray((np.clip(lifted, 0, 1) * 255 + 0.5).astype("uint8")).save(path)
        print("lifted", part, "g=%.2f" % g)


if __name__ == "__main__":
    main()
