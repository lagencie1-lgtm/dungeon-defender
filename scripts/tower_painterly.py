"""The pets' painterly paint for a tower level (Lemp 2026-11-23: "use the painterly workflow from the pets thread";
docs/tower-pipeline.md "Painterly paint, shared with pets"). Geometry stays the tower kit's; the pet scripts are called
unchanged (scripts/pet_paint.py: align and the Blender runner; art/blender/pet_project.py: views, project).

  python scripts/tower_painterly.py <kind> <level> [--reuse] [--strength 1.0]

1. art/blender/paint_pack.py packs the model's painted parts (Body, Skin_roof, Skin_props, Skin_barrel ...) into one
   mesh with one atlas; the current paint is the base and is never overwritten (the result goes to its own folder).
2. pet_project views -> the painter repaints the four sides in the style of the level's painting -> align (views under
   62 % outline overlap are skipped) -> pet_project project -> the island gaps are filled from the painted edge -> the
   atlas is cut back into the parts' pictures, each at its own size.
3. Scored before and after with scripts/match_score.py from the painting's angle (outline, colour dE, detail).
Out: tools/towers_paint/<kind>_l<level>/ (model, pictures, sheets, score.txt)."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import pet_paint  # noqa: E402  (the pets' painter steps, used as they are)
from tower_paint import codex_paint  # noqa: E402

BLENDER = pet_paint.BLENDER

# the pets' wording, for a tower (pet_paint.PROMPT speaks of a pet's fur and face)
PROMPT = """Image 1 is a model sheet: the same 3D defense tower model seen from four sides in a 2 by 2 grid (top left,
top right, bottom left, bottom right: four sides a quarter turn apart) on a white ground. Image 2 is the concept
painting of this tower.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
soft painterly strokes, rich warm shading with light from the top left, small painted details (stone edges and gaps,
wood grain, shingle edges, brass highlights, leaves, cloth folds, as image 2 shows them), matte, no shine.

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, with exactly the
same outline as in image 1: do not move, turn, resize, add or remove any part. Paint only what each view shows. Plain
pure white background, no ground, no shadows, no text, no border, no extra objects. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


def score(fbx, picture, out_png):
    render = out_png[:-4] + "_render.png"
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", fbx, render, "-75", "15", "512"],
                   capture_output=True)
    r = subprocess.run([sys.executable, os.path.join(HERE, "match_score.py"), picture, render, out_png], capture_output=True,
                       text=True, encoding="utf-8", errors="ignore")
    return r.stdout.strip().splitlines()


def main():
    kind, level = sys.argv[1], int(sys.argv[2])
    strength = sys.argv[sys.argv.index("--strength") + 1] if "--strength" in sys.argv else "1.0"
    name = f"tower_{kind}_l{level}"
    src = os.path.join(ROOT, "art", "models")
    out = os.path.join(ROOT, "tools", "towers_paint", f"{kind}_l{level}")
    work = os.path.join(out, "paint")
    before = os.path.join(out, "before")
    for d in (out, work, before):
        os.makedirs(d, exist_ok=True)
    # the model as it is now: kept as "before", and the starting point
    for f in os.listdir(src):
        if f == name + ".fbx" or (f.startswith(name + "_paint") and f.endswith(".png")):
            shutil.copy(os.path.join(src, f), os.path.join(before, f))
            shutil.copy(os.path.join(src, f), os.path.join(out, f))
    fbx = os.path.join(out, name + ".fbx")
    picture = os.path.join(ROOT, "art", "ref3d", f"{name}.png")
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "paint_pack.py"), "--", os.path.join(before, name + ".fbx"), work],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    if "PACKED" not in r.stdout:
        raise SystemExit("pack failed: " + r.stdout[-1500:])
    pack, base = os.path.join(work, "pack.fbx"), os.path.join(work, "pack_base.png")
    views, painted = os.path.join(work, "views.png"), os.path.join(work, "painted.png")
    if "--reuse" not in sys.argv:
        pet_paint.blender("views", pack, base, views)
        if os.path.exists(painted):
            os.remove(painted)
        codex_paint(PROMPT.format(name=os.path.basename(painted)), os.path.basename(painted), work, [views, picture])
    aligned, bad = pet_paint.align(views, painted)[:2]
    atlas = os.path.join(work, "pack_painted_texture.png")
    pet_paint.blender("project", pack, base, aligned, atlas, strength, *(["skip=" + ",".join(bad)] if bad else []))
    subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "archer_project.py"), "--", "pad", pack, atlas],
                   capture_output=True)
    cells = json.load(open(os.path.join(work, "cells.json")))
    a = Image.open(atlas).convert("RGB")
    c = a.width // cells["n"]
    for part, info in cells["parts"].items():
        dst = os.path.join(out, os.path.basename(info["texture"]))
        a.crop((info["cx"] * c, info["cy"] * c, (info["cx"] + 1) * c, (info["cy"] + 1) * c)).resize(
            (info["size"], info["size"]), Image.LANCZOS).save(dst)
    sb = score(os.path.join(before, name + ".fbx"), picture, os.path.join(out, "score_before.png"))
    sa = score(fbx, picture, os.path.join(out, "score_after.png"))
    txt = f"{name}\nbefore: {sb[0] if sb else '?'}\nafter:  {sa[0] if sa else '?'}\nskipped views: {', '.join(bad) or 'none'}\n"
    open(os.path.join(out, "score.txt"), "w").write(txt)
    print(txt)


if __name__ == "__main__":
    main()
