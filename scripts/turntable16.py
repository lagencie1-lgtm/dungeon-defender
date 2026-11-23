"""A 16-frame turntable of a model at 512 px per frame, painted (each part's own texture) or grey (shape only), plus
a top view. Run: python scripts/turntable16.py model.fbx out_prefix [grey|paint|both]"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"


def main():
    fbx, prefix = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    mode = sys.argv[3] if len(sys.argv) > 3 else "both"
    for kind in (["grey", "paint"] if mode == "both" else [mode]):
        frames = []
        for k in range(16):
            out = f"{prefix}_{kind}_{k:02d}.png"
            subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, out,
                            str(-90 + k * 22.5), "8", "512", "persp", "lit"], capture_output=True,
                           env=dict(os.environ, HTD_GREY="1" if kind == "grey" else ""))
            frames.append(out)
        top = f"{prefix}_{kind}_top.png"
        subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, top, "-90", "89", "512",
                        "persp", "lit"], capture_output=True, env=dict(os.environ, HTD_GREY="1" if kind == "grey" else ""))
        sheet = Image.new("RGB", (512 * 4, 512 * 4 + 40 * 4), (226, 226, 226))
        d = ImageDraw.Draw(sheet)
        for k, f in enumerate(frames):
            im = Image.open(f).convert("RGBA")
            bg = Image.new("RGB", im.size, (226, 226, 226))
            bg.paste(im, (0, 0), im)
            x, y = (k % 4) * 512, (k // 4) * 552
            sheet.paste(bg, (x, y + 40))
            d.text((x + 8, y + 8), f"frame {k:02d}  {k * 22.5:.1f} deg from the front", fill=(30, 30, 30))
        sheet.save(f"{prefix}_{kind}_turntable16.png")
        print(f"{prefix}_{kind}_turntable16.png")


if __name__ == "__main__":
    main()
