"""Measures how close a second-generation pet model is to its target picture, and builds the comparison sheet
(6A: "measured matching beats eyeballing"). Called by scripts/pet_cycle.sh after the renders exist.

  python scripts/pet_match.py <kind> [--old]     --old scores the first-generation model instead (baseline)

Numbers (the target picture scores 100 / 0 / 100 / 100 against itself):
  shape   overlap of the two outlines in percent (IoU), best of the two front views, mirrored or not
  colour  average colour difference in CIE Lab over a 8x8 grid (lower is better; under 12 reads as the same paint)
  rich    how much colour the model shows compared with the picture, percent (saturation inside the outline)
  detail  how much drawn detail it shows compared with the picture, percent (edges inside the outline)
Writes reviews/pets/img/_cycle_<kind>.png and appends a line to reviews/pets/match.csv.
"""
import datetime
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 256


def cutout(path, bg):
    """The picture on a transparent ground: flood-fills the background colour from the borders."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    marker = (255, 0, 255)
    work = im.copy()
    for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (0, h // 2), (w - 1, h // 2), (w // 2, h - 1)]:
        px = work.getpixel(xy)
        if px != marker and sum(abs(px[i] - bg[i]) for i in range(3)) < 60:
            ImageDraw.floodfill(work, xy, marker, thresh=38)
    mask = work.point(lambda v: v).convert("RGB")
    r, g, b = mask.split()
    is_bg = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v == 255 else 0), g.point(lambda v: 255 if v == 0 else 0)),
                                b.point(lambda v: 255 if v == 255 else 0))
    alpha = ImageChops.invert(is_bg).filter(ImageFilter.MedianFilter(5))
    box = alpha.getbbox()
    im, alpha = im.crop(box), alpha.crop(box)
    # fit into N x N, standing on the bottom edge, centred
    s = min(N / im.width, N / im.height)
    size = (max(1, round(im.width * s)), max(1, round(im.height * s)))
    im, alpha = im.resize(size, Image.LANCZOS), alpha.resize(size, Image.LANCZOS)
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    rgba = im.convert("RGBA")
    rgba.putalpha(alpha)
    canvas.paste(rgba, ((N - size[0]) // 2, N - size[1]))
    return canvas


def lab(rgb):
    def f(c):
        c /= 255
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
    r, g, b = (f(v) for v in rgb)
    x, y, z = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.9505, 0.2126 * r + 0.7152 * g + 0.0722 * b, (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.089

    def g2(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return 116 * g2(y) - 16, 500 * (g2(x) - g2(y)), 200 * (g2(y) - g2(z))


def stats(img):
    """mean saturation and edge strength inside the outline"""
    a = img.split()[3]
    inner = a.filter(ImageFilter.MinFilter(9))   # stay off the outline itself
    hsv = img.convert("RGB").convert("HSV")
    edges = img.convert("RGB").convert("L").filter(ImageFilter.FIND_EDGES)
    n = sat = edge = 0
    sp, ep, ip = hsv.split()[1].load(), edges.load(), inner.load()
    for y in range(N):
        for x in range(N):
            if ip[x, y] > 128:
                n += 1
                sat += sp[x, y]
                edge += ep[x, y]
    return (sat / n, edge / n) if n else (0, 0)


def compare(target, model):
    ta, ma = target.split()[3].load(), model.split()[3].load()
    inter = union = 0
    for y in range(N):
        for x in range(N):
            t, m = ta[x, y] > 128, ma[x, y] > 128
            inter += t and m
            union += t or m
    iou = 100 * inter / union if union else 0
    cells, diff = 0, 0.0
    step = N // 8
    tp, mp = target.load(), model.load()
    for gy in range(8):
        for gx in range(8):
            tc, mc, tn, mn = [0, 0, 0], [0, 0, 0], 0, 0
            for y in range(gy * step, (gy + 1) * step, 2):
                for x in range(gx * step, (gx + 1) * step, 2):
                    if tp[x, y][3] > 128:
                        tn += 1
                        for i in range(3):
                            tc[i] += tp[x, y][i]
                    if mp[x, y][3] > 128:
                        mn += 1
                        for i in range(3):
                            mc[i] += mp[x, y][i]
            if tn > 20 and mn > 20:
                l1, l2 = lab([c / tn for c in tc]), lab([c / mn for c in mc])
                diff += sum((l1[i] - l2[i]) ** 2 for i in range(3)) ** 0.5
                cells += 1
    return iou, (diff / cells if cells else 99)


def main():
    kind = sys.argv[1]
    old = "--old" in sys.argv
    target = cutout(os.path.join(ROOT, "art", "ref3d", "batch2", f"pet_{kind}.png"), (255, 255, 255))
    grey = (41, 41, 46)
    d = os.path.join(ROOT, "art", "models", "pets2")
    views = [os.path.join(d, f"_old_{kind}.png")] if old else [os.path.join(d, f"_v_{kind}_{a}.png") for a in (24, -50)]
    best = None
    for v in views:
        if not os.path.exists(v):
            continue
        m = cutout(v, grey)
        for flip in (False, True):
            mm = m.transpose(Image.FLIP_LEFT_RIGHT) if flip else m
            iou, de = compare(target, mm)
            if best is None or iou > best[0]:
                best = (iou, de, mm)
    if best is None:
        raise SystemExit("no renders for " + kind)
    iou, de, model = best
    ts, te = stats(target)
    ms, me = stats(model)
    rich, detail = 100 * ms / ts if ts else 0, 100 * me / te if te else 0
    label = "gen1" if old else "gen2"
    print(f"{kind} {label}: shape {iou:.0f}%  colour dE {de:.1f}  rich {rich:.0f}%  detail {detail:.0f}%")
    out_dir = os.path.join(ROOT, "reviews", "pets")
    os.makedirs(os.path.join(out_dir, "img"), exist_ok=True)
    with open(os.path.join(out_dir, "match.csv"), "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M},{kind},{label},{iou:.1f},{de:.1f},{rich:.0f},{detail:.0f}\n")
    if old:
        return
    # sheet: target | new front | new other side | new back | old
    T = 420
    tiles = [Image.open(os.path.join(ROOT, "art", "ref3d", "batch2", f"pet_{kind}.png")).convert("RGB").resize((T, T))]
    for a in (24, -50, 160):
        tiles.append(Image.open(os.path.join(d, f"_v_{kind}_{a}.png")).convert("RGB").crop((90, 60, 610, 640)).resize((T, T)))
    oldp = os.path.join(d, f"_old_{kind}.png")
    if os.path.exists(oldp):
        tiles.append(Image.open(oldp).convert("RGB").crop((90, 60, 610, 640)).resize((T, T)))
    sheet = Image.new("RGB", (T * len(tiles), T), (41, 41, 46))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * T, 0))
    sheet.save(os.path.join(out_dir, "img", f"_cycle_{kind}.png"))


if __name__ == "__main__":
    main()
