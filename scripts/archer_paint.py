"""Hand-painted surface for the Ranger's archer (both parts: ranger_archer and ranger_archer_arms), the same way the
pets get theirs (art/blender/pet_project.py): four ortho sides rendered into a 2 x 2 sheet, Codex repaints the sheet
in the look of the archer painting, each painted view is fitted onto its rendered outline (scripts/pet_paint.py
align), and the paint is projected back. The eyes, brows, mouth and fringe are "keep" paint (petkit) and stay crisp.

Run: python scripts/archer_paint.py [folder=tools/archer] [--reuse]"""
import os
import shutil
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pet_paint import align  # noqa: E402
from tower_paint import codex_paint  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
PIC = os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer.png")

PROMPT = """Image 1 is a model sheet: the same 3D {what} seen from four sides in a 2 by 2 grid (top left front,
top right its left side, bottom left back, bottom right its right side) on a white ground. Image 2 is the concept
painting of this archer.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
soft painterly cloth folds on the green hood and tunic with a cream lining, warm brown leather with stitched edges on
the belt, bracers, boots and quiver, wood grain on the bow, warm skin with soft shading, rich soft light from the top
left, small painted details as image 2 shows them.

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, in the same pose,
with the same outline as in image 1: do not move, turn, resize, add or remove any part. Keep the face exactly as it
is in image 1 (eyes, brows, mouth, hair). Plain pure white background, no ground, no shadows, no text, no border, no
extra objects. Square image.

Use your image generation tool with both images as references and save the result as {{name}} in the current folder.
Reply only with the file path."""

PARTS = {"ranger_archer": "chibi archer character (body, head in a hood, quiver; no arms)",
         "ranger_archer_arms": "pair of archer arms holding a drawn bow and arrow (only the arms and the bow)"}


def blender(*a):
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "pet_project.py"), "--", *a],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith(("SHEET", "PROJECTED")) or "Traceback" in ln]
    print("\n".join(lines), flush=True)
    if not any(ln.startswith(("SHEET", "PROJECTED")) for ln in lines):
        raise SystemExit("Blender step failed:\n" + r.stdout[-1500:])


def main():
    folder = os.path.abspath(next((a for a in sys.argv[1:] if not a.startswith("--")), os.path.join(ROOT, "tools", "archer")))
    for name, what in PARTS.items():
        fbx = os.path.join(folder, name + ".fbx")
        tex, base = fbx[:-4] + "_paint.png", fbx[:-4] + "_base.png"
        views, painted = fbx[:-4] + "_views.png", fbx[:-4] + "_painted.png"
        if "--reuse" not in sys.argv or not os.path.exists(base):
            shutil.copy(tex, base)
        if "--reuse" not in sys.argv:
            blender("views", fbx, base, views)
            codex_paint(PROMPT.format(what=what), os.path.basename(painted), folder, [views, PIC])
        im = Image.open(painted).convert("RGB")
        if im.size != (1024, 1024):
            im.resize((1024, 1024), Image.LANCZOS).save(painted)
        fitted = align(views, painted)
        blender("project", fbx, base, fitted, tex, "1.0")


if __name__ == "__main__":
    main()
