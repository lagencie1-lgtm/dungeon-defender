"""Calibrates the colour gate of scripts/match_score.py on the picture itself: the picture against copies of itself
that differ the way a 90%-IoU model differs (moved a few percent, a bit softer, slightly lighter or darker).
Run: python scripts/match_calibrate.py picture.png"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))


def variant(im, dx, blur, light):
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if min(r, g, b) >= 238:
                px[x, y] = (0, 0, 0, 0)
    moved = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    moved.paste(rgba, (int(w * dx), 0))
    rgb = ImageEnhance.Brightness(moved.convert("RGB").filter(ImageFilter.GaussianBlur(blur))).enhance(light)
    rgb.putalpha(moved.split()[3])
    return rgb


def main():
    pic = Image.open(sys.argv[1])
    for dx, blur, light in ((0.02, 1.5, 1.0), (0.03, 2.5, 1.06), (0.03, 2.5, 0.94)):
        path = os.path.join(tempfile.gettempdir(), "calib.png")
        variant(pic, dx, blur, light).save(path)
        out = subprocess.run([sys.executable, os.path.join(HERE, "match_score.py"), sys.argv[1], path],
                             capture_output=True, text=True).stdout
        print(f"moved {dx * 100:.0f}% blur {blur} light {light}: " + out.splitlines()[0])


if __name__ == "__main__":
    main()
