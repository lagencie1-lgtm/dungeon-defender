"""Labelled sheet for a tower level's painterly pass: target painting | painterly model | model before, from the
painting's angle (the renders scripts/tower_painterly.py scored), with both score lines.
Run: python scripts/tower_painterly_sheet.py <kind> <level> <out.png>"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fit(im, h=520):
    im = im.convert("RGBA")
    bg = Image.new("RGB", im.size, (255, 255, 255))
    bg.paste(im, (0, 0), im)
    box = Image.eval(bg.convert("L"), lambda v: 255 if v < 245 else 0).getbbox() or (0, 0, *bg.size)
    c = bg.crop(box)
    return c.resize((max(1, int(c.width * h / c.height)), h))


def main():
    kind, level, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    d = os.path.join(ROOT, "tools", "towers_paint", f"{kind}_l{level}")
    cols = [("target painting", Image.open(os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png"))),
            ("painterly model (pets' workflow)", Image.open(os.path.join(d, "score_after_render.png"))),
            ("model before", Image.open(os.path.join(d, "score_before_render.png")))]
    ims = [fit(im) for _, im in cols]
    W = sum(i.width for i in ims) + 40 * len(ims)
    lines = open(os.path.join(d, "score.txt")).read().splitlines()
    sheet = Image.new("RGB", (W, 520 + 130), (255, 255, 255))
    dr = ImageDraw.Draw(sheet)
    x = 20
    for (label, _), im in zip(cols, ims):
        dr.text((x, 8), label, fill=(30, 30, 30))
        sheet.paste(im, (x, 30))
        x += im.width + 40
    for k, ln in enumerate(lines):
        dr.text((20, 560 + k * 18), ln[:230], fill=(30, 30, 30))
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
