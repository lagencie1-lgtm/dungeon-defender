"""Reads the archer visibility probe out of a film clip (test/film/Film.client.luau, round C: "the game is the truth").
For each of the 8 run-camera directions the clip holds two frames: each archer's head in a flat colour (magenta,
cyan) drawn only where the camera sees it (Occluded), then drawn whole (AlwaysOnTop). Seen share = pixels of the
first / pixels of the second; a head counts as seen at 50 % or more.
  python scripts/film_probe.py tools/film/<name>-phonehq     (the clip's path without .mp4 / .marks.txt)
Prints per direction both heads' seen share and the counts; writes <name>.probe.json and a contact sheet .probe.png."""
import glob
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLOURS = {"magenta": (255, 0, 255), "cyan": (0, 255, 255)}


def frame_at(clip, t, out):
    ffmpeg = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-ss", f"{t:.2f}", "-i", clip, "-frames:v", "1", out], check=True)
    return np.asarray(Image.open(out).convert("RGB")).astype(int)


def count(im, rgb):
    d = np.abs(im - np.array(rgb)).max(-1)
    return int((d < 70).sum())


def main():
    base = sys.argv[1]
    marks = []
    for ln in open(base + ".marks.txt", encoding="utf-8"):
        parts = ln.strip().split("\t", 1)
        if len(parts) == 2 and parts[1].startswith("probe "):
            marks.append((float(parts[0]), parts[1]))
    work = base + "_probe"
    os.makedirs(work, exist_ok=True)
    res, thumbs = {}, []
    for t, name in marks:
        _, ang, mode = name.split()
        im = frame_at(base + ".mp4", t + 0.15, os.path.join(work, f"{ang}_{mode}.png"))
        res.setdefault(ang, {})[mode] = {c: count(im, rgb) for c, rgb in COLOURS.items()}
        if mode == "Occluded":
            thumbs.append((ang, im))
    both = one = 0
    out = {}
    for ang in sorted(res, key=int):
        occ, full = res[ang].get("Occluded", {}), res[ang].get("AlwaysOnTop", {})
        shares = {c: (occ.get(c, 0) / full[c] if full.get(c) else None) for c in COLOURS}
        seen = [s is not None and s >= 0.5 for s in shares.values()]
        both += all(seen)
        one += any(seen)
        out[ang] = {"shares": shares, "occluded": occ, "whole": full}
        print(f"{ang:>3}: " + "  ".join(f"{c} {s * 100:.0f}% ({occ.get(c, 0)}/{full.get(c, 0)} px)" if s is not None else f"{c} -" for c, s in shares.items()))
    print(f"PROBE both archers seen in {both} of 8 directions, at least one in {one} of 8")
    json.dump({"directions": out, "both": both, "one": one}, open(base + ".probe.json", "w"), indent=1)
    if thumbs:
        h, w = thumbs[0][1].shape[:2]
        sc = 400 / w
        sheet = Image.new("RGB", (int(w * sc) * 4, int(h * sc) * 2), "white")
        for i, (ang, im) in enumerate(thumbs[:8]):
            t = Image.fromarray(im.astype(np.uint8)).resize((int(w * sc), int(h * sc)))
            ImageDraw.Draw(t).text((6, 6), f"{ang} deg", fill=(255, 255, 255))
            sheet.paste(t, ((i % 4) * int(w * sc), (i // 4) * int(h * sc)))
        sheet.save(base + ".probe.png")


if __name__ == "__main__":
    main()
