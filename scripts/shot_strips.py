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
    marks, shots = {}, {}
    for ln in open(film + ".marks.txt", encoding="utf-8"):
        t, _, name = ln.strip().partition("\t")
        if name.startswith("shots "):
            marks[name] = float(t)
        elif name.startswith("shot "):   # (an animated shot heard by the client: kind [wind-up travel])
            parts = name.split()
            w, tr = (float(parts[2]), float(parts[3])) if len(parts) >= 4 else (0.2, 0.8)
            shots.setdefault(parts[1], []).append((float(t), w, tr))
    out = os.path.join(ROOT, "reviews", "towers", "shots")
    os.makedirs(out, exist_ok=True)
    jobs = []
    for kind, short in NAMES.items():
        for lv in (1, 2, 3):
            a, b = marks.get(f"shots {kind} {lv} start"), marks.get(f"shots {kind} {lv} end")
            if a is None and lv == 3:   # (films before 2026-11-27 step 2 marked level 3 only)
                a, b = marks.get(f"shots {kind} start"), marks.get(f"shots {kind} end")
            if a is not None and b is not None:
                jobs.append((kind, short, lv, a, b))
    for kind, short, lv, a, b in jobs:
        tmp = os.path.join(out, "_f.png")
        subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{a + 0.5:.2f}", "-i", film + ".mp4", "-frames:v", "1", tmp])
        with Image.open(tmp) as f:
            box = screen_box(np.asarray(f.convert("RGB")))
        # (the tower stands in the middle of the phone screen: the strip and clip keep its middle, without the HUD)
        bx0, by0, bx1, by1 = box
        w, h = bx1 - bx0, by1 - by0
        box = (bx0 + int(w * 0.22), by0 + int(h * 0.12), bx0 + int(w * 0.78), by0 + int(h * 0.72))   # (the tower and the targets behind it: the flight path fills the frame)
        x0, y0, x1, y1 = box
        crop = f"crop={(x1 - x0) // 2 * 2}:{(y1 - y0) // 2 * 2}:{x0}:{y0}"
        clip = os.path.join(out, f"{short}_l{lv}.mp4")
        subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{a:.2f}", "-to", f"{b:.2f}", "-i", film + ".mp4", "-vf", crop,
                        "-c:v", "libx264", "-crf", "24", "-preset", "veryfast", "-an", clip])
        if os.path.getsize(clip) > 5 * 1024 * 1024:
            os.remove(clip)
        frames = []
        # (centred on the first animated shot in the clip when the client marked one: from 0.3 s before it to 1.0 s
        # after, the wind-up, the release, the flight and the hit; else the clip's middle 2 s)
        first = next((x for x in shots.get(kind, []) if a <= x[0] <= b - 0.5), None)
        if first is not None:   # (from just before the wind-up to just after the impact)
            t0, span = first[0] - 0.05, max(first[1] + first[2] + 0.25, 0.5)
        else:
            t0, span = (a + b) / 2 - 1.0, 2.0
        for i in range(12):
            t = t0 + span * i / 11
            subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{t:.2f}", "-i", film + ".mp4", "-frames:v", "1", tmp])
            with Image.open(tmp) as f:
                frames.append(f.convert("RGB").crop(box).resize((300, int(300 * (y1 - y0) / (x1 - x0)))))
        w, h = frames[0].size
        strip = Image.new("RGB", (w * 6, h * 2))
        for i, fr in enumerate(frames):
            strip.paste(fr, ((i % 6) * w, (i // 6) * h))
        strip.save(os.path.join(out, f"{short}_l{lv}_strip.png"))
        os.remove(tmp)
        print("shots", short, lv, "clip" if os.path.exists(clip) else "(clip over 5 MB, strip only)")


if __name__ == "__main__":
    main()
