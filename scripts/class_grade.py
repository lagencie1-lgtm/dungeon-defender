"""Colour sweep by material (coordinator 2026-11-25, "every tower is 13 to 20 against the 12 target"): the pixels of a
painted sheet are sorted into material classes by colour (wood, gold, cream stone, grey iron and stone, violet slate,
ice); for each class the median colour of the model as RENDERED from the painting's angle (score render) is compared
with the same class in the PAINTING, and the sheet's pixels of that class are moved by that difference (saturation
and value by ratio, hue by the hue shift), blended in softly at the class edges. So the colours the painting shows
come straight from the painting, class by class, and what the painting doesn't show keeps the painter's colours
relative to them.
  python scripts/class_grade.py <render.png> <painting.png> <sheet.png> [<sheet.png> ...]   -> sheets graded in place
  (render.png: the model drawn from the painting's angle on transparent, e.g. tools/<kind>f/score_l<n>_render.png)"""
import sys

import cv2
import numpy as np

# OpenCV HSV (hue 0-180): soft class weights
CLASSES = {
    "wood": lambda h, s, v: _in(h, 3, 16, 2) * _over(s, 90, 25) * _in(v, 30, 215, 15),
    "gold": lambda h, s, v: _in(h, 17, 32, 2) * _over(s, 100, 25) * _over(v, 120, 20),
    "cream": lambda h, s, v: _under(s, 70, 20) * _over(v, 150, 20),
    "grey": lambda h, s, v: _under(s, 50, 15) * _in(v, 50, 150, 15),
    "violet": lambda h, s, v: _in(h, 118, 170, 4) * _over(s, 50, 20),
    "ice": lambda h, s, v: _in(h, 85, 115, 4) * _over(s, 40, 20),
}


def _over(x, lo, soft):
    return np.clip((x - lo) / soft + 0.5, 0, 1)


def _under(x, hi, soft):
    return np.clip((hi - x) / soft + 0.5, 0, 1)


def _in(x, lo, hi, soft):
    return _over(x, lo, soft) * _under(x, hi, soft)


def hsv_of(path, alpha_only=False):
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    keep = np.ones(img.shape[:2], bool)
    if img.shape[2] == 4:
        keep = img[..., 3] > 40
    else:   # (the painting: its white background left out)
        keep = img[..., :3].min(-1) < 238
    hsv = cv2.cvtColor(img[..., :3], cv2.COLOR_BGR2HSV).astype(np.float32)
    return img, hsv, keep


def medians(hsv, keep, w):
    m = keep & (w > 0.6)
    if m.sum() < 200:
        return None
    return np.median(hsv[m], 0), int(m.sum())


def main():
    render, painting, sheets = sys.argv[1], sys.argv[2], sys.argv[3:]
    _, rh, rk = hsv_of(render)
    _, ph, pk = hsv_of(painting)
    moves = {}
    for name, f in CLASSES.items():
        a = medians(rh, rk, f(*(rh[..., i] for i in range(3))))
        b = medians(ph, pk, f(*(ph[..., i] for i in range(3))))
        if a is None or b is None:
            continue
        (h0, s0, v0), (h1, s1, v1) = a[0], b[0]
        # (bounded: a class that is a few pixels of something else in one picture must not swing the whole sheet)
        moves[name] = (float(np.clip(h1 - h0, -6, 6)), float(np.clip(s1 / max(s0, 1), 0.6, 1.5)), float(np.clip(v1 / max(v0, 1), 0.7, 1.35)))
        print(f"GRADE {name}: hue {moves[name][0]:+.1f}, saturation x{moves[name][1]:.2f}, value x{moves[name][2]:.2f} "
              f"(render {a[1]} px, painting {b[1]} px)")
    for path in sheets:
        img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
        hsv = cv2.cvtColor(img[..., :3], cv2.COLOR_BGR2HSV).astype(np.float32)
        h, s, v = (hsv[..., i] for i in range(3))
        out = hsv.copy()
        total = np.zeros(h.shape, np.float32)
        acc = np.zeros(hsv.shape, np.float32)
        for name, (dh, ks, kv) in moves.items():
            w = CLASSES[name](h, s, v)
            g = np.stack([(h + dh) % 180, np.clip(s * ks, 0, 255), np.clip(v * kv, 0, 255)], -1)
            acc += g * w[..., None]
            total += w
        has = total > 0.05
        out[has] = (acc[has] / total[has][:, None]) * np.minimum(total[has], 1)[:, None] + hsv[has] * (1 - np.minimum(total[has], 1))[:, None]
        rgb = cv2.cvtColor(out.astype(np.uint8), cv2.COLOR_HSV2BGR)
        if img.shape[2] == 4:
            rgb = np.dstack([rgb, img[..., 3]])
        cv2.imwrite(path, rgb)
        print("GRADED", path)


if __name__ == "__main__":
    main()
