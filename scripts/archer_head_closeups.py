"""Head close-ups of painted archer builds, neutral light (flat albedo, as the turntables): front, both three-quarter
views and the side, one row per build, labelled (coordinator round C: "head close-ups at front, three-quarter and side").
  python scripts/archer_head_closeups.py out.png "round C=tools/archer20b" "round B=tools/archer17b" [size=768]"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
ANGLES = [(0, "front"), (-45, "3/4 left of viewer"), (45, "3/4 right of viewer"), (90, "side")]
FRAME = "0,0.1,1.93,1.25"   # the head's middle and the view's width (the hood is 1.04 wide, 2.41 is its top)


def render(fbx, deg, out, size):
    env = dict(os.environ, HTD_FRAME=FRAME)
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out,
                    str(-90 + deg), "0", str(size), "ortho"], env=env, capture_output=True)
    return Image.open(out).convert("RGBA")


def main():
    out = sys.argv[1]
    size = int(next((a[5:] for a in sys.argv[2:] if a.startswith("size=")), 768))
    rows = [a.split("=", 1) for a in sys.argv[2:] if "=" in a and not a.startswith("size=")]
    work = os.path.join(os.path.dirname(os.path.abspath(out)), "_closeups")
    os.makedirs(work, exist_ok=True)
    pad = 34
    sheet = Image.new("RGB", (len(ANGLES) * size, len(rows) * (size + pad)), "white")
    d = ImageDraw.Draw(sheet)
    for r, (label, build) in enumerate(rows):
        fbx = os.path.join(ROOT, build, "ranger_archer.fbx")
        for c, (deg, name) in enumerate(ANGLES):
            im = render(fbx, deg, os.path.join(work, f"{r}_{c}.png"), size)
            sheet.paste(im, (c * size, r * (size + pad) + pad), im)
            d.text((c * size + 8, r * (size + pad) + 8), f"{label}: {name} ({deg:+d} deg)", fill="black")
    sheet.save(out)
    print("SHEET", out)


if __name__ == "__main__":
    main()
