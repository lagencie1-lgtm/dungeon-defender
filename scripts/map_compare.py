"""Before / after sheets of the battle maps from two map_tour takes (labelled columns: Lemp could not tell target
from result on unlabelled sheets).
  python scripts/map_compare.py <before> <after> [--views overview,hero,lane2,lane5] [--out name]
Writes reviews/maps/img/<out>-<Map>.jpg (default out = compare) and <out>-all.jpg with the three maps' first row.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, "reviews", "maps", "img")
MAPS = {"CursedForest": "Cursed Forest", "MagmaFortress": "Magma Fortress", "CrystalCaves": "Crystal Caves"}


def arg(flag, default):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def tile(take, map_id, view, w):
    im = Image.open(os.path.join(IMG, f"{take}-{map_id}-{view}.jpg")).convert("RGB")
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)


def main():
    before, after = sys.argv[1], sys.argv[2]
    views = arg("--views", "overview,hero,lane2,lane5").split(",")
    out = arg("--out", "compare")
    w, pad, head = 900, 14, 64
    firsts = []
    for map_id, title in MAPS.items():
        rows = [(tile(before, map_id, v, w), tile(after, map_id, v, w)) for v in views]
        h = sum(max(a.height, b.height) for a, b in rows) + pad * (len(rows) + 1) + head
        sheet = Image.new("RGB", (w * 2 + pad * 3, h), (24, 22, 20))
        d = ImageDraw.Draw(sheet)
        d.text((pad, 12), f"{title}: BEFORE", font=font(36), fill=(235, 190, 120))
        d.text((w + pad * 2, 12), f"{title}: NOW", font=font(36), fill=(140, 230, 150))
        y = head + pad
        for a, b in rows:
            sheet.paste(a, (pad, y))
            sheet.paste(b, (w + pad * 2, y))
            y += max(a.height, b.height) + pad
        sheet.save(os.path.join(IMG, f"{out}-{map_id}.jpg"), quality=90)
        print(os.path.join(IMG, f"{out}-{map_id}.jpg"))
        firsts.append(sheet)
    total = Image.new("RGB", (firsts[0].width, sum(f.height for f in firsts)), (24, 22, 20))
    y = 0
    for f in firsts:
        total.paste(f, (0, y))
        y += f.height
    total.save(os.path.join(IMG, f"{out}-all.jpg"), quality=88)


if __name__ == "__main__":
    main()
