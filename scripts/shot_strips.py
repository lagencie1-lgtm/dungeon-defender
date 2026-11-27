"""Shooting clips of the level 3 towers (Lemp 2026-11-27, "the tower shooting animations are still way behind"): from a
film made with test/film (marks "shots <Kind> start/end"), each tower's close clip cut to reviews/towers/shots/
<tower>_l3.mp4 (when under 5 MB) and a strip of 12 frames over its middle 2 seconds, <tower>_l3_strip.png.
  python scripts/shot_strips.py tools/film/<name>-phonehq"""
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = {"Ranger": "ranger", "Ballista": "ballista", "StormObelisk": "storm", "FlameCannon": "flame", "FrostCrystal": "frost"}


def main():
    film = sys.argv[1]
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    from film_screen import screen_box
    import numpy as np
    ff = next(os.path.join(dp, f) for dp, _, fs in os.walk(os.path.join(ROOT, "tools", "ffmpeg")) for f in fs if f == "ffmpeg.exe")
    marks = {}
    for ln in open(film + ".marks.txt", encoding="utf-8"):
        t, _, name = ln.strip().partition("\t")
        if name.startswith("shots "):
            marks[name] = float(t)
    out = os.path.join(ROOT, "reviews", "towers", "shots")
    os.makedirs(out, exist_ok=True)
    for kind, short in NAMES.items():
        a, b = marks.get(f"shots {kind} start"), marks.get(f"shots {kind} end")
        if a is None or b is None:
            print("no shots for", kind)
            continue
        tmp = os.path.join(out, "_f.png")
        subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{a + 0.5:.2f}", "-i", film + ".mp4", "-frames:v", "1", tmp])
        with Image.open(tmp) as f:
            box = screen_box(np.asarray(f.convert("RGB")))
        # (the tower stands in the middle of the phone screen: the strip and clip keep its middle, without the HUD)
        bx0, by0, bx1, by1 = box
        w, h = bx1 - bx0, by1 - by0
        box = (bx0 + int(w * 0.28), by0 + int(h * 0.12), bx0 + int(w * 0.72), by0 + int(h * 0.82))
        x0, y0, x1, y1 = box
        crop = f"crop={(x1 - x0) // 2 * 2}:{(y1 - y0) // 2 * 2}:{x0}:{y0}"
        clip = os.path.join(out, f"{short}_l3.mp4")
        subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{a:.2f}", "-to", f"{b:.2f}", "-i", film + ".mp4", "-vf", crop,
                        "-c:v", "libx264", "-crf", "24", "-preset", "veryfast", "-an", clip])
        if os.path.getsize(clip) > 5 * 1024 * 1024:
            os.remove(clip)
        frames = []
        mid = (a + b) / 2
        for i in range(12):
            t = mid - 1.0 + 2.0 * i / 11
            subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{t:.2f}", "-i", film + ".mp4", "-frames:v", "1", tmp])
            with Image.open(tmp) as f:
                frames.append(f.convert("RGB").crop(box).resize((300, int(300 * (y1 - y0) / (x1 - x0)))))
        w, h = frames[0].size
        strip = Image.new("RGB", (w * 6, h * 2))
        for i, fr in enumerate(frames):
            strip.paste(fr, ((i % 6) * w, (i // 6) * h))
        strip.save(os.path.join(out, f"{short}_l3_strip.png"))
        os.remove(tmp)
        print("shots", short, "clip" if os.path.exists(clip) else "(clip over 5 MB, strip only)")


if __name__ == "__main__":
    main()
