"""Overview sheets of all 12 pets, every tile labelled (the owner could not tell target from result on an unlabelled
sheet). Run after scripts/pet_cycle.sh (lit renders) and scripts/pet_stage.py --close all (engine close-ups).

  python scripts/pet_overview.py lit <out.jpg>      per pet: TARGET PICTURE above, NEW lit like the engine below
  python scripts/pet_overview.py engine <out.jpg>   per pet: the close-up taken inside Roblox Studio
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KINDS = ["slimey", "leafling", "stonepup", "mosskitten", "glowbug", "emberfox", "crystalowl", "minigolem", "babydragon",
         "starunicorn", "phoenix", "voiddrake"]
NAMES = {"slimey": "Slimey", "leafling": "Leafling", "stonepup": "Stonepup", "mosskitten": "Moss Kitten", "glowbug": "Glowbug",
         "emberfox": "Ember Fox", "crystalowl": "Crystal Owl", "minigolem": "Mini Golem", "babydragon": "Baby Dragon",
         "starunicorn": "Star Unicorn", "phoenix": "Sunfire Phoenix", "voiddrake": "Void Drake"}
T, BAR = 360, 36
try:
    FONT = ImageFont.truetype("arialbd.ttf", 20)
except OSError:
    FONT = ImageFont.load_default()


def label(draw, x, y, text, colour):
    draw.rectangle((x, y, x + T - 2, y + BAR - 2), fill=colour)
    draw.text((x + 8, y + 6), text, fill="white", font=FONT)


def lit(out):
    sheet = Image.new("RGB", (T * 6, (T + BAR) * 4), (41, 41, 46))
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(KINDS):
        c, r = i % 6, (i // 6) * 2
        target = Image.open(os.path.join(ROOT, "art", "ref3d", "batch2", f"pet_{k}.png")).convert("RGB").resize((T, T), Image.LANCZOS)
        new = Image.open(os.path.join(ROOT, "art", "models", "pets2", f"_lit_{k}_24.png")).convert("RGB").crop((90, 60, 610, 640)).resize((T, T), Image.LANCZOS)
        for row, im, text, col in ((r, target, "TARGET  " + NAMES[k], (150, 110, 20)), (r + 1, new, "NEW 3D MODEL", (30, 130, 60))):
            y = row * (T + BAR)
            label(d, c * T, y, text, col)
            sheet.paste(im, (c * T, y + BAR))
    sheet.save(out, quality=90)


def engine(out):
    W, H = 435, 400
    sheet = Image.new("RGB", (W * 4, (H + BAR) * 3), (41, 41, 46))
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(KINDS):
        p = os.path.join(ROOT, "reviews", "pets", "img", f"close-{k}.png")
        x, y = (i % 4) * W, (i // 4) * (H + BAR)
        d.rectangle((x, y, x + W - 2, y + BAR - 2), fill=(30, 130, 60))
        d.text((x + 8, y + 6), NAMES[k] + "  in Roblox", fill="white", font=FONT)
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            w, h = im.size
            side = min(w, h) * 0.86   # the pet sits in the middle of the close-up
            box = (int(w / 2 - side * W / H / 2), int(h * 0.5 - side / 2), int(w / 2 + side * W / H / 2), int(h * 0.5 + side / 2))
            sheet.paste(im.crop(box).resize((W, H), Image.LANCZOS), (x, y + BAR))
    sheet.save(out, quality=90)


if __name__ == "__main__":
    {"lit": lit, "engine": engine}[sys.argv[1]](sys.argv[2])
    print(sys.argv[2])
