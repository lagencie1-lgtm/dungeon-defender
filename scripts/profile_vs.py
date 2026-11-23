import sys
from PIL import Image
def prof(path):
    im = Image.open(path)
    if im.mode == "RGBA":
        a = im.split()[3].load(); solid = lambda x, y: a[x, y] > 40
    else:
        im = im.convert("RGB"); p = im.load(); solid = lambda x, y: min(p[x, y]) < 238
    w, h = im.size
    rows = [y for y in range(h) if any(solid(x, y) for x in range(0, w, 3))]
    top, bot = rows[0], rows[-1]; H = bot - top
    out = []
    for k in range(0, 21):
        y = top + int(H * k / 20)
        xs = [x for x in range(0, w, 2) if solid(x, y)]
        out.append((max(xs) - min(xs)) / H if xs else 0)
    return out
t, r = prof(sys.argv[1]), prof(sys.argv[2])
print("row%  " + " ".join(f"{k*5:4d}" for k in range(21)))
print("pict  " + " ".join(f"{v:4.2f}" for v in t))
print("model " + " ".join(f"{v:4.2f}" for v in r))
