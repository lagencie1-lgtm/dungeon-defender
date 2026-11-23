"""Checks a picture_body model view by view against the sheet it was built from (coordinator 2026-11-23 gate: front,
side and back near pixel-matches, IoU 95%+, colour dE under 6) and makes a turntable strip (12 frames).
Run: python scripts/picture_check.py spec.json model.fbx out_prefix"""
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
RENDER = os.path.join(ROOT, "art", "blender", "parts_render.py")


def render(fbx, out, az, el, size=600, mode="ortho", lit=False, skip=""):
    env = dict(os.environ, HTD_SKIP=skip)
    subprocess.run([BLENDER, "-b", "-P", RENDER, "--", fbx, out, str(az), str(el), str(size), mode] + (["lit"] if lit else []),
                   capture_output=True, env=env)


def main():
    spec_path, fbx, prefix = (os.path.abspath(a) for a in sys.argv[1:4])
    spec = json.load(open(spec_path))
    sheet = Image.open(os.path.join(os.path.dirname(spec_path), spec["sheet"])).convert("RGB")
    lines = []
    # front: camera at -Y; side (his right): camera at -X; back: camera at +Y
    for name, az in (("front", -90), ("side", 180), ("back", 90)):
        x0, y0, x1, y1, _ = spec["views"][name]
        target = prefix + f"_{name}_target.png"
        sheet.crop((x0, y0, x1, y1)).save(target)
        r = prefix + f"_{name}.png"
        render(fbx, r, az, 0, skip=spec.get("check_skip", ""))
        out = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "match_score.py"), target, r, prefix + f"_{name}_sheet.png"],
                             capture_output=True, text=True).stdout.splitlines()
        lines.append(f"{name}: " + (out[0] if out else "no score"))
        print(lines[-1], flush=True)
    # the honest test: the three-quarter painting (not used to build), both possible sides, keep the better
    if spec.get("test_view"):
        best = None
        for az in (-45, -135):
            r = prefix + f"_34_{-az}.png"
            render(fbx, r, az, 0, 768, "ortho")
            out = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "match_score.py"),
                                  os.path.join(os.path.dirname(spec_path), spec["test_view"]), r, prefix + f"_34_{-az}_sheet.png"],
                                 capture_output=True, text=True).stdout.splitlines()
            iou = float(out[0].split("IoU ")[1].split("%")[0]) if out else 0
            if best is None or iou > best[0]:
                best = (iou, az, out[0] if out else "")
        print(f"three-quarter (azimuth {best[1]}): {best[2]}", flush=True)
    frames = []
    for k in range(12):
        f = prefix + f"_turn{k}.png"
        render(fbx, f, -90 + k * 30, 12, 300, "persp", lit=True)
        im = Image.open(f).convert("RGBA")
        bg = Image.new("RGB", im.size, (236, 236, 236))
        bg.paste(im, (0, 0), im)
        frames.append(bg)
        os.remove(f)
    strip = Image.new("RGB", (300 * 6, 600), (236, 236, 236))
    for k, f in enumerate(frames):
        strip.paste(f, ((k % 6) * 300, (k // 6) * 300))
    strip.save(prefix + "_turntable.png")
    print("TURNTABLE", prefix + "_turntable.png")


if __name__ == "__main__":
    main()
