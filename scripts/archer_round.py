"""Logs one round of the archer loop (coordinator 2026-11-23): the archer against its painting at the painting's
angle (picture | model | outline diff, with the numbers), the archer at phone size (as big as it is on a tower in
the game: about 40 px tall, shown enlarged with hard pixels) and a large lit beauty render.
Writes reviews/archer/round_XX.png and appends reviews/archer/rounds.md.
Run: python scripts/archer_round.py <round> "what changed" [folder=tools/archer]"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
PIC = os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer.png")


def render(folder, out, az, el, size, lit=False):
    cmd = [BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "archer_render.py"), "--", folder, out, str(az), str(el), str(size)]
    subprocess.run(cmd + (["lit"] if lit else []), capture_output=True)


def on_white(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGB", im.size, (255, 255, 255))
    bg.paste(im, (0, 0), im)
    box = bg.convert("L").point(lambda v: 255 if v < 248 else 0).getbbox()
    return bg.crop(box) if box else bg


def main():
    rnd, note = int(sys.argv[1]), sys.argv[2]
    folder = os.path.abspath(sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, "tools", "archer"))
    out_dir = os.path.join(ROOT, "reviews", "archer")
    os.makedirs(out_dir, exist_ok=True)
    stem = os.path.join(out_dir, f"round_{rnd:02d}")
    render(folder, stem + "_r.png", -115, 12, 768)
    score = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "match_score.py"), PIC, stem + "_r.png", stem + "_m.png"],
                           capture_output=True, text=True).stdout.splitlines()
    render(folder, stem + "_lit.png", -115, 12, 900, lit=True)
    render(folder, stem + "_tower.png", -60, 35, 900, lit=True)   # as the game camera sees it: from above
    match = Image.open(stem + "_m.png")
    beauty = on_white(stem + "_lit.png")
    beauty.thumbnail((360, 360))
    phone = on_white(stem + "_tower.png")
    phone.thumbnail((40, 40))
    phone = phone.resize((phone.width * 8, phone.height * 8), Image.NEAREST)
    pic_small = on_white(PIC)
    pic_small.thumbnail((40, 40))
    pic_small = pic_small.resize((pic_small.width * 8, pic_small.height * 8), Image.NEAREST)
    W = max(match.width, 360 + 20 + phone.width + 20 + pic_small.width)
    sheet = Image.new("RGB", (W, 60 + match.height + 380), (255, 255, 255))
    sheet.paste(match, (0, 60))
    y = 60 + match.height + 10
    sheet.paste(beauty, (0, y))
    sheet.paste(pic_small, (380, y))
    sheet.paste(phone, (380 + pic_small.width + 20, y))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    d.text((8, 4), f"Ranger archer, round {rnd}: {note}", fill=(20, 20, 20), font=font)
    d.text((8, 22), score[0] if score else "", fill=(20, 20, 20), font=font)
    d.text((380, y - 2 + 330), "phone size (40 px, x8): painting | model", fill=(60, 60, 60), font=font)
    sheet.save(stem + ".png")
    for p in ("_r.png", "_m.png", "_lit.png", "_tower.png"):
        if os.path.exists(stem + p):
            os.remove(stem + p)
    with open(os.path.join(out_dir, "rounds.md"), "a", encoding="utf-8") as log:
        log.write(f"- round {rnd}: {note}\n  {score[0] if score else ''}\n")
    print(stem + ".png")
    print(score[0] if score else "")


if __name__ == "__main__":
    main()
