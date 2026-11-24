"""Before / after sheets of the battle maps from two map_tour takes (labelled columns: Lemp could not tell target
from result on unlabelled sheets).
  python scripts/map_compare.py <before> <after> [--views overview,hero,lane2,lane5] [--out name]
                                [--labels "BEFORE,NOW"] [--crop] [--maps CursedForest,...]
   (--crop for pc-size takes: cuts the HUD's edges away)
Writes reviews/maps/img/<out>-<Map>.jpg (default out = compare).
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


def tile(take, map_id, view, w, crop=False):
    im = Image.open(os.path.join(IMG, f"{take}-{map_id}-{view}.jpg")).convert("RGB")
    if crop:
        W, H = im.size
        im = im.crop((int(W * 0.14), int(H * 0.13), int(W * 0.86), int(H * 0.86)))
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)


def main():
    before, after = sys.argv[1], sys.argv[2]
    views = arg("--views", "overview,hero,lane2,lane5").split(",")
    out = arg("--out", "compare")
    labels = arg("--labels", "BEFORE,NOW").split(",")
    crop = "--crop" in sys.argv   # pc-size stills: cut the HUD's edges away and keep the middle of the view
    w, pad, head = 900, 14, 64
    only = arg("--maps", ",".join(MAPS)).split(",")
    for map_id, title in MAPS.items():
        if map_id not in only:
            continue
        rows = [(tile(before, map_id, v, w, crop), tile(after, map_id, v, w, crop)) for v in views]
        h = sum(max(a.height, b.height) for a, b in rows) + pad * (len(rows) + 1) + head
        sheet = Image.new("RGB", (w * 2 + pad * 3, h), (24, 22, 20))
        d = ImageDraw.Draw(sheet)
        d.text((pad, 12), f"{title}: {labels[0]}", font=font(36), fill=(235, 190, 120))
        d.text((w + pad * 2, 12), f"{title}: {labels[1]}", font=font(36), fill=(140, 230, 150))
        y = head + pad
        for a, b in rows:
            sheet.paste(a, (pad, y))
            sheet.paste(b, (w + pad * 2, y))
            y += max(a.height, b.height) + pad
        sheet.save(os.path.join(IMG, f"{out}-{map_id}.jpg"), quality=90)
        print(os.path.join(IMG, f"{out}-{map_id}.jpg"))


if __name__ == "__main__":
    main()
