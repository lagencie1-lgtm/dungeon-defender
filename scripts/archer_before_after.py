"""Before/after sheet for the archer's painterly pass: one row per angle (front, both three-quarter views, side,
back), columns: the target painting, the new painterly model, the model before this pass. Models without bow and
quiver (the model sheets carry nothing); flat painted colour, orthographic.
Run: python scripts/archer_before_after.py <new.fbx> <before.fbx> <out.png>"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import archer_compare as C  # noqa: E402


def main():
    new, old, out = (os.path.abspath(a) for a in sys.argv[1:4])
    C.H = 460
    rows = [("front", C.view("ranger_archer_elf.png", 0), -90), ("3/4 front-left", C.view("ranger_archer_elf34.png", 0), -45),
            ("3/4 front-right", C.view("ranger_archer_elf34.png", 1), -135), ("side", C.view("ranger_archer_elf.png", 1), 180),
            ("back", C.view("ranger_archer_elf.png", 2), 90)]
    W = 480
    sheet = Image.new("RGB", (W * 3 + 140, (C.H + 20) * len(rows) + 50), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for i, t in enumerate(("target painting", "painterly model (new)", "model before this pass")):
        d.text((140 + W * i + 10, 14), t, fill=(30, 30, 30))
    for r, (name, paint, az) in enumerate(rows):
        y = 50 + r * (C.H + 20)
        d.text((10, y + C.H // 2), name, fill=(30, 30, 30))
        tmp = os.path.join(os.path.dirname(out), "_ba")
        os.makedirs(tmp, exist_ok=True)
        a = C.render(new, os.path.join(tmp, f"new_{az}.png"), az, "Bow,Quiver")
        b = C.render(old, os.path.join(tmp, f"old_{az}.png"), az, "Bow,Quiver")
        for i, im in enumerate((paint, a, b)):
            sheet.paste(im, (140 + W * i + (W - im.width) // 2, y))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
