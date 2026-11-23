import sys
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
px = im.load()
w, h = im.size
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        m = min(r, g, b)
        if m > 242:
            px[x, y] = (r, g, b, 0)
        elif m > 225:
            px[x, y] = (r, g, b, int(255 * (242 - m) / 17))
box = im.getbbox()
im = im.crop(box)
side = max(im.size)
sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
sq.paste(im, ((side - im.size[0]) // 2, side - im.size[1]))
sq.save(out)
