"""Colour classes of the archer's bare model sheet (art/ref3d/archer/ranger_archer_bare.png), shared by the loft
builder's spec maker and the gates: g green cloth, c cream trim, s skin, h hair/leather brown, d dark (eyes, brows),
y gold, . background."""
import numpy as np
from PIL import Image


def classes(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mx, mn = im.max(-1), im.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    out = np.full(r.shape, ".", dtype="<U1")
    fg = mn < 0.92
    out[fg & (g > r) & (g > b)] = "g"
    out[fg & (r >= g) & (mx < 0.45)] = "h"
    out[fg & (r >= g) & (mx >= 0.45) & (sat > 0.25)] = "s"
    out[fg & (r >= g) & (mx >= 0.45) & (sat > 0.25) & (r - g < 0.2) & (g > 0.55) & (b < 0.35)] = "y"
    out[fg & (r >= g) & (sat <= 0.25) & (mx > 0.75)] = "c"
    out[fg & (mx < 0.2)] = "d"
    # brown leather/hair vs skin: brown is darker and more saturated
    out[fg & (r >= g) & (mx >= 0.45) & (mx < 0.62) & (sat > 0.45)] = "h"
    return out, im


if __name__ == "__main__":
    import sys
    out, _ = classes(sys.argv[1])
    x0, x1, step = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]) if len(sys.argv) > 4 else 8
    for y in range(0, out.shape[0], step):
        print("%3d " % y + "".join(out[y, x0:x1:step // 2]))
