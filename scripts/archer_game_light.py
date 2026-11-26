"""In-game light of the archer at the film's open-ground spot (round B's brightness table, made a script in round C):
pulls the film's shots (archer and Baby Dragon in open light, the archer from four sides on the level 3 tower) out of
the clip (phone viewport) and measures, per part, the in-game brightness over the painting's (L* ratio) and the colour
difference with the brightness taken out.
  python scripts/archer_game_light.py tools/film/<name>-phonehq <out dir>"""
import glob
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from pet_match import lab  # noqa: E402

SHOTS = ("archer open light", "dragon open light", "archer front", "archer left", "archer back", "archer right")


def L(c):
    return lab(list(c))[0]


def de(a, b):
    la, lb = lab(list(a)), lab(list(b))
    return sum((la[i] - lb[i]) ** 2 for i in range(3)) ** 0.5


def med(img, box, cond):
    a = np.asarray(img.convert("RGB")).astype(float)
    if box:
        a = a[box[1]:box[3], box[0]:box[2]]
    a = a.reshape(-1, 3)
    m = cond(a)
    return np.median(a[m], axis=0), int(m.sum())


green = lambda a: (a[:, 1] > a[:, 0] + 10) & (a[:, 1] > a[:, 2] + 40) & (a[:, 1] > 80)  # noqa: E731
brown = lambda a: (a[:, 0] > a[:, 1] + 25) & (a[:, 1] > a[:, 2] + 5) & (a[:, 0] < 200) & (a[:, 0] > 80)  # noqa: E731
skin = lambda a: (a[:, 0] > 150) & (a[:, 0] > a[:, 1] + 20) & (a[:, 1] > a[:, 2] + 20) & (a[:, 1] > 90)  # noqa: E731
purple = lambda a: (a[:, 2] > a[:, 1] + 30) & (a[:, 0] > a[:, 1] + 15) & (a.sum(1) > 200)  # noqa: E731


def main():
    base, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    ff = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    marks = {}
    for ln in open(base + ".marks.txt", encoding="utf-8"):
        t, _, name = ln.strip().partition("\t")
        marks.setdefault(name, float(t))
    for n in SHOTS:
        if n in marks:
            dst = os.path.join(out, n.replace(" ", "_") + ".png")
            subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{marks[n] + 0.9:.2f}", "-i", base + ".mp4", "-frames:v", "1", dst], check=True)
            im = Image.open(dst).convert("RGB")
            from film_screen import screen_box   # (the phone screen, wherever Studio's window put it)
            box = screen_box(np.asarray(im))
            im.crop(box).resize((604, 280)).save(dst)
    g = Image.open(os.path.join(out, "dragon_open_light.png"))
    c1, _ = med(g, (250, 90, 370, 200), purple)
    c2, _ = med(Image.open(os.path.join(ROOT, "art", "ref3d", "batch2", "pet_babydragon.png")), None, purple)
    rows = [("Baby Dragon", L(c1) / L(c2), None, None)]
    g = Image.open(os.path.join(out, "archer_open_light.png"))
    p = Image.open(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_elf.png"))
    for nm, box, pbox, cond in (("face", (285, 90, 312, 115), (220, 190, 420, 320), skin),
                                ("tunic", (278, 120, 320, 175), (200, 380, 440, 640), green),
                                ("hood", (275, 80, 325, 118), (140, 30, 500, 340), green),
                                ("boots", (275, 185, 325, 225), (150, 700, 500, 868), brown)):
        c1, n1 = med(g, box, cond)
        c2, _ = med(p, pbox, cond)
        r = L(c1) / L(c2)
        rows.append((f"archer {nm}", r, de(c1, c2), de(np.clip(c1 / r, 0, 255), c2)))
    for nm, r, d, dn in rows:
        print(f"{nm:14s} brightness ratio {r:.2f}" + ("" if d is None else f"   dE {d:.1f}   dE with brightness taken out {dn:.1f}"))
    ims = [Image.open(os.path.join(out, f"archer_{n}.png")) for n in ("front", "left", "back", "right") if os.path.exists(os.path.join(out, f"archer_{n}.png"))]
    if len(ims) == 4:
        w, h = ims[0].size
        s = Image.new("RGB", (w * 2, h * 2))
        for i, im in enumerate(ims):
            s.paste(im, ((i % 2) * w, (i // 2) * h))
        s.save(os.path.join(out, "L3_four_sides.png"))


if __name__ == "__main__":
    main()
