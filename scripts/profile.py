import sys
from PIL import Image
for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    rows = []
    top = bottom = None
    for y in range(h):
        xs = [x for x in range(0, w, 2) if min(px[x, y]) < 238]
        if xs:
            top = y if top is None else top
            bottom = y
    H = bottom - top
    out = []
    for k in range(0, 21):
        y = top + int(H * k / 20)
        xs = [x for x in range(0, w, 2) if min(px[x, y]) < 238]
        out.append(f"{k*5:3d}%:{(max(xs)-min(xs))/H:.2f}" if xs else f"{k*5:3d}%:0")
    print(path.split("\\")[-1], "height px", H, " ".join(out))
