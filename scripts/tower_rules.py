"""The research brief's tower rules as numbers (coordinator 2026-11-24), read from a film (test/film: "view <Kind> <n>",
"mask <Kind> <n>", "low <Kind> ..." marks, the run camera's start pointed at the tower, HUD hidden):
  levels tell apart   the outlines of levels 1, 2 and 3 of one tower overlap each other by 80 % or less (IoU)
  towers tell apart   two different towers at the same level overlap by 65 % or less
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
    for ln in open(base + ".marks.txt", encoding="utf-8"):
        t, _, name = ln.strip().partition("\t")
        if name.startswith(("view ", "mask ", "low ")):
            marks.append((float(t), name))
    views, masks, lows = {}, {}, {}
    box = None
    for t, name in marks:
        parts = name.split()
        img = frame(ff, base + ".mp4", t + 0.15, os.path.join(out, "_frame.png"))
        if box is None:
            box = screen_box(img)
        img = img[box[1]:box[3], box[0]:box[2]]
        if parts[0] == "view":
            views[(parts[1], int(parts[2]))] = img
            Image.fromarray(img).save(os.path.join(out, f"{parts[1]}_l{parts[2]}_phone.png"))
        elif parts[0] == "mask":
            d = np.abs(img.astype(int) - np.array([255, 0, 255])).max(-1)
            masks[(parts[1], int(parts[2]))] = d < 70
        else:
            lows[parts[1]] = " ".join(parts[2:])
            Image.fromarray(img).save(os.path.join(out, f"{parts[1]}_l3_low_effects.png"))
    res = {"levels": {}, "towers": {}, "stands_out": {}, "low_effects": lows, "fails": []}

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
    for lv in (1, 2, 3):
        for a, b in itertools.combinations(kinds, 2):
            if (a, lv) in masks and (b, lv) in masks:
                v = round(100 * iou(masks[(a, lv)], masks[(b, lv)]), 1)
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
    json.dump(res, open(os.path.join(out, "rules.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in res.items() if k != "fails"}, indent=1))
    print("RULES", "PASS" if not res["fails"] else "FAIL", res["fails"])
    sys.exit(0 if not res["fails"] else 1)


if __name__ == "__main__":
    main()
