"""Fills the black gaps between a baked texture's islands with the islands' own colours (they are averaged in when the
game shows the model small on a phone and made the Ranger level 2 look dark). Uses the colour to find the gaps
(near-black texels), so it suits finished paint files; the Blender steps (art/blender/tower_project.py) do the same
with the exact UV layout. Run: python scripts/fill_gaps.py texture.png [more.png ...]"""
import sys

import numpy as np
from PIL import Image


def fill(path, rounds=24):
    img = np.asarray(Image.open(path).convert("RGB")).astype(float)
    used = img.sum(axis=2) >= 25
    out = img.copy()
    have = used.copy()
    for _ in range(rounds):
        acc = np.zeros_like(out)
        cnt = np.zeros(have.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(have, dy, 0), dx, 1)
            acc += np.roll(np.roll(out, dy, 0), dx, 1) * sh[..., None]
            cnt += sh
        grow = (~have) & (cnt > 0)
        out[grow] = acc[grow] / cnt[grow][:, None]
        have |= grow
    out[~have] = img[used].mean(axis=0)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(path)
    print("filled %s: %.0f%% were gaps" % (path, 100 * (~used).mean()))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        fill(p)
