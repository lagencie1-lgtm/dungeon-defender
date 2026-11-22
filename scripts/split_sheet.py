import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
# split at the white gaps between the three towers: columns that are (almost) all white
cols = []
px = im.load()
for x in range(w):
    white = sum(1 for y in range(0, h, 4) if min(px[x, y]) > 245)
    cols.append(white / (h / 4) > 0.985)
runs, start = [], None
for x, wcol in enumerate(cols):
    if not wcol and start is None:
        start = x
    if wcol and start is not None:
        if x - start > 40:
            runs.append((start, x))
        start = None
if start is not None:
    runs.append((start, w))
print("parts", runs)
for i, (a, b) in enumerate(runs[:3], start=1):
    pad = 20
    im.crop((max(0, a - pad), 0, min(w, b + pad), h)).save(sys.argv[2].replace("N", str(i)))
