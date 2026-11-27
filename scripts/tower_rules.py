"""The research brief's tower rules as numbers (coordinator 2026-11-24), read from a film (test/film: "view <Kind> <n>",
"mask <Kind> <n>", "low <Kind> ..." marks, the run camera's start pointed at the tower, HUD hidden):
  levels tell apart   the outlines of levels 1, 2 and 3 of one tower overlap each other by 80 % or less (IoU)
  towers tell apart   two different towers at the same level overlap by 65 % or less, on the top 40 % of the outline
  stands out          mean colour difference (CIE Lab dE) between the tower and the ground and props right round it
                      (a band 4 to 16 px outside its outline) is 20 or more
Also saves the phone pictures (view, and level 3 at the lowest graphics level when the film could set it).
  python scripts/tower_rules.py tools/film/<name>-phonehq [out dir]     -> rules.json and pictures; exit 1 on a fail"""
import glob
import itertools
import json
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from film_screen import screen_box  # noqa: E402


def frame(ff, clip, t, out):
    subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{t:.2f}", "-i", clip, "-frames:v", "1", out], check=True)
    return np.asarray(Image.open(out).convert("RGB"))


def main():
    base = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "reviews", "towers", "rules")
    os.makedirs(out, exist_ok=True)
    ff = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    marks = []
    notloaded = set()
    for ln in open(base + ".marks.txt", encoding="utf-8"):
        t, _, name = ln.strip().partition("\t")
        if name.startswith(("view ", "mask ", "low ")):
            marks.append((float(t), name))
        elif name.startswith("look not loaded "):   # (the film saw only the stand-in: that level's shots don't count)
            notloaded.add((name.split()[3], int(name.split()[4])))
    views, masks, lows = {}, {}, {}
    box = None

    def magenta(img):
        return np.abs(img.astype(int) - np.array([255, 0, 255])).max(-1) < 70
    # (2026-11-25: the clip's clock drifts against the marks by up to half a second, so a fixed +0.15 s missed the
    # outline frames. Each mask is the frame with the most magenta in a window round its mark; that frame's offset
    # from the mark is then used for the same tower's view picture)
    drift = {}
    # (2026-11-27: one film ran 5.5 s off its marks and every picture showed the next level: the first mask is
    # searched in a wide window, the others round the offset it found)
    centre = None
    for t, name in marks:
        parts = name.split()
        if parts[0] != "mask":
            continue
        best, seen = None, []
        window = np.arange(-8.0, 3.01, 0.15) if centre is None else np.arange(centre - 1.5, centre + 1.51, 0.15)
        for dt in window:   # (drift seen up to -1.5 s, 2026-11-25)
            img = frame(ff, base + ".mp4", t + dt, os.path.join(out, "_frame.png"))
            n = int(magenta(img).sum())
            seen.append((dt, n))
            if best is None or n > best[0]:
                best = (n, dt, img)
        if centre is None:
            # (the wide window can hold the next level's outline too: the film's first outline is the earliest run)
            first = next(i for i, (dt, n) in enumerate(seen) if n >= 0.5 * best[0])
            run = []
            for dt, n in seen[first:]:
                if n < 0.5 * best[0]:
                    break
                run.append((dt, n))
            top = max(n for _, n in run)
            best = (top, next(dt for dt, n in run if n == top), frame(ff, base + ".mp4", t + next(dt for dt, n in run if n == top), os.path.join(out, "_frame.png")))
            seen = run
        img = best[2]
        # (the drift is the middle of the run of outline frames, not its first frame: the first one put the view
        # picture before the view shot began)
        full = [dt for dt, n in seen if n >= 0.9 * best[0]]
        best = (best[0], float(np.mean(full)), img)
        if centre is None:
            centre = best[1]
        if box is None:
            box = screen_box(frame(ff, base + ".mp4", t - 3, os.path.join(out, "_frame.png")))
        masks[(parts[1], int(parts[2]))] = magenta(img[box[1]:box[3], box[0]:box[2]])
        # (2026-11-27: the outline saved too, for measurements on the phone pictures, scripts/phone_measure.py)
        Image.fromarray(masks[(parts[1], int(parts[2]))].astype(np.uint8) * 255).save(os.path.join(out, f"{parts[1]}_l{parts[2]}_mask.png"))
        drift[(parts[1], int(parts[2]))] = best[1]
    for t, name in marks:
        parts = name.split()
        if parts[0] == "mask":
            continue
        if box is None:
            box = screen_box(frame(ff, base + ".mp4", t, os.path.join(out, "_frame.png")))
        if parts[0] == "view":
            key = (parts[1], int(parts[2]))
            # (the view is held from 0.6 s before its mark until the outline goes on 0.5 s after it)
            img = frame(ff, base + ".mp4", t + drift.get(key, 0.0) - 0.1, os.path.join(out, "_frame.png"))
            img = img[box[1]:box[3], box[0]:box[2]]
            views[key] = img
            Image.fromarray(img).save(os.path.join(out, f"{parts[1]}_l{parts[2]}_phone.png"))
        else:
            img = frame(ff, base + ".mp4", t + 0.15, os.path.join(out, "_frame.png"))[box[1]:box[3], box[0]:box[2]]
            lows[parts[1]] = " ".join(parts[2:])
            Image.fromarray(img).save(os.path.join(out, f"{parts[1]}_l3_low_effects.png"))
    res = {"levels": {}, "towers": {}, "stands_out": {}, "low_effects": lows, "fails": []}
    for key in sorted(notloaded):
        masks.pop(key, None)
        views.pop(key, None)
        res["fails"].append(f"{key[0]} level {key[1]}: the real look had not loaded in the film (stand-in), not measured")

    def iou(a, b):
        return float((a & b).sum() / max(1, (a | b).sum()))
    kinds = sorted({k for k, _ in masks})
    for k in kinds:
        for a, b in itertools.combinations((1, 2, 3), 2):
            if (k, a) in masks and (k, b) in masks:
                v = round(100 * iou(masks[(k, a)], masks[(k, b)]), 1)
                res["levels"][f"{k} {a}-{b}"] = v
                if v > 80:
                    res["fails"].append(f"{k} levels {a} and {b} overlap {v}% (needs 80% or less)")
    def top40(m):
        """(coordinator 2026-11-24: every tower stands on the same round plinth, so the whole outlines of two towers
        overlap mostly at the base: two towers are compared on the top 40 % of the outline, the weapon and crown)"""
        rows = np.where(m.any(1))[0]
        if not len(rows):
            return m
        cut = rows.min() + int(0.4 * (rows.max() - rows.min() + 1))
        out = m.copy()
        out[cut:] = False
        return out
    for lv in (1, 2, 3):
        for a, b in itertools.combinations(kinds, 2):
            if (a, lv) in masks and (b, lv) in masks:
                v = round(100 * iou(top40(masks[(a, lv)]), top40(masks[(b, lv)])), 1)
                res["towers"][f"{a}/{b} level {lv}"] = v
                if v > 65:
                    res["fails"].append(f"{a} and {b} at level {lv} overlap {v}% (needs 65% or less)")
    for key, m in masks.items():
        if key not in views or m.sum() < 50:
            continue
        lab = cv2.cvtColor(views[key].astype(np.float32) / 255, cv2.COLOR_RGB2Lab)
        mm = m.astype(np.uint8)
        ring = (cv2.dilate(mm, np.ones((33, 33), np.uint8)) > 0) & ~(cv2.dilate(mm, np.ones((9, 9), np.uint8)) > 0)
        inner = cv2.erode(mm, np.ones((5, 5), np.uint8)) > 0
        de = float(np.linalg.norm(lab[inner].mean(0) - lab[ring].mean(0)))
        res["stands_out"][f"{key[0]} {key[1]}"] = round(de, 1)
        if de < 20:
            res["fails"].append(f"{key[0]} level {key[1]} stands out by dE {de:.1f} from what is round it (needs 20)")
    # bright yellow-orange share (coordinator 2026-11-25, the Flame Cannon's level 3 read as a yellow blob): within the
    # tower's outline in its phone view, pixels that are vivid and bright yellow-orange; 15 % or less
    res["bright"] = {}
    for key, m in masks.items():
        if key not in views or m.sum() < 50:
            continue
        hsv = cv2.cvtColor(views[key], cv2.COLOR_RGB2HSV)
        h, s_, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
        bright = (h >= 10) & (h <= 34) & (s_ > 130) & (v > 200)
        share = round(100 * float((bright & m).sum() / m.sum()), 1)
        res["bright"][f"{key[0]} {key[1]}"] = share
        if share > 15:
            res["fails"].append(f"{key[0]} level {key[1]}: {share}% of it is bright yellow-orange (needs 15% or less)")
    # gold share in the phone view (measured, not a gate; coordinator 2026-11-26: the Flame Cannon's level 2 read as a
    # gold ring/pot): vivid gold-hued pixels of the tower's outline
    res["gold"] = {}
    for key, m in masks.items():
        if key not in views or m.sum() < 50:
            continue
        hsv = cv2.cvtColor(views[key], cv2.COLOR_RGB2HSV)
        gold = (hsv[..., 0] >= 15) & (hsv[..., 0] <= 30) & (hsv[..., 1] > 100) & (hsv[..., 2] > 110)
        res["gold"][f"{key[0]} {key[1]}"] = round(100 * float((gold & m).sum() / m.sum()), 1)
    # fits the phone screen (coordinator 2026-11-26, the Ranger's level 3 roof was cut off at the run camera): in the
    # phone view the top of the tower's outline stays at least 5 % of the screen's height below its top edge
    res["top_margin"] = {}
    for key, m in masks.items():
        rows = np.where(m.any(1))[0]
        if not len(rows):
            continue
        margin = round(100 * rows.min() / m.shape[0], 1)
        res["top_margin"][f"{key[0]} {key[1]}"] = margin
        if margin < 5:
            res["fails"].append(f"{key[0]} level {key[1]}: its top is {margin}% below the screen's top edge (needs 5% or more)")
    # no tower's level 3 more than 1.3 times as tall as the tallest other tower's level 3 (TowerService LEVEL_LOOKS)
    import re
    src = open(os.path.join(ROOT, "src", "server", "TowerService.luau"), encoding="utf-8").read()
    h3 = {m.group(1): float(m.group(2)) for m in re.finditer(r'Name = "tower_(\w+)_l3", Height = ([\d.]+)', src)}
    res["level3_height"] = h3
    for k, h in h3.items():
        others = [v for kk, v in h3.items() if kk != k]
        if others and h > 1.3 * max(others):
            res["fails"].append(f"{k} level 3 is {h:.2f} studs tall, {h / max(others):.2f} times the tallest other level 3 "
                                f"(needs 1.3 or less)")
    # no face read (coordinator 2026-11-26: the Flame Cannon's level 3 read as a face with goggles): at the run camera
    # a bore opening is seen as an ellipse whose short-to-long ratio is |cos| of the angle between the barrel's axis
    # and the view; two or more bores of one level above 0.8 (nearly face-on circles) side by side fail. The bores
    # are written by the builder (art/models/tower_<kind>_l<n>_bores.json); the view is the film's run camera
    # (horizontal direction 0.6, 0, 0.8; Config.RunCamera's pitch)
    import glob as _g
    import math as _m
    cfg = open(os.path.join(ROOT, "src", "shared", "Config.luau"), encoding="utf-8").read()
    pm = re.search(r"RunCamera\s*=\s*\{[^}]*Pitch\s*=\s*([\d.]+)", cfg)
    pitch = _m.radians(float(pm.group(1)) if pm else 32)
    hx, hz = 0.6, 0.8
    view = (hx * _m.cos(pitch), -_m.sin(pitch), hz * _m.cos(pitch))
    res["bore_ratio"] = {}
    for f in sorted(_g.glob(os.path.join(ROOT, "art", "models", "tower_*_l*_bores.json"))):
        name = os.path.basename(f)[len("tower_"):-len("_bores.json")]
        ratios = [round(abs(sum(a * b for a, b in zip(bo["axis"], view))), 2) for bo in json.load(open(f))]
        res["bore_ratio"][name] = ratios
        if sum(r > 0.8 for r in ratios) >= 2:
            res["fails"].append(f"{name}: {sum(r > 0.8 for r in ratios)} bores seen nearly face-on ({ratios}, needs at "
                                f"most one above 0.8): it reads as a face")
    json.dump(res, open(os.path.join(out, "rules.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in res.items() if k != "fails"}, indent=1))
    print("RULES", "PASS" if not res["fails"] else "FAIL", res["fails"])
    sys.exit(0 if not res["fails"] else 1)


if __name__ == "__main__":
    main()
