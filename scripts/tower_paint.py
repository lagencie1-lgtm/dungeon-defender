"""Hand-painted surface for a code-built tower (docs/tower-pipeline.md, no image-to-3D service): renders the model
from four sides (art/blender/tower_project.py views), lets the picture painter (Codex image generation, the owner's
ChatGPT login) repaint that sheet in the look of the tower's target picture, and projects the paint back.

  python scripts/tower_paint.py model.fbx picture.png            paint + project -> <model>_paint.png
  python scripts/tower_paint.py model.fbx picture.png --reuse    project the sheet that is already painted
  --strength 0.9   how much of the new paint is used (1 = all)

Next to the model: <model>_base.png (the plain baked texture, kept so a bad painting can be thrown away),
<model>_views.png (what the painter gets), <model>_painted.png (what it returns).
Run one painting job at a time (two in parallel stall); run it in the foreground (in the background Codex fails)."""
import glob
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"

PROMPT = """Image 1 is a model sheet: the same 3D defense tower model seen from four sides in a 2 by 2 grid (top left
the three-quarter front view with the door, top right its right side, bottom left its back, bottom right its left
side) on a white ground. Image 2 is the concept painting of this tower, seen from the same angle as the top left view.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
warm pale cut stone with soft painted edges and darker gaps, red-brown wooden shingles with light top edges, warm
wood with grain, polished brass with bright highlights, fresh green ivy leaves, cream cloth, rich soft shading with
light from the top left, small painted details like image 2 shows them. The archer keeps a friendly face.

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, with exactly the
same outline as in image 1: do not move, turn, resize, add or remove any part (every stone, shingle, post, plate,
leaf and the flag stay where they are). Paint only what each view shows (the back view has no door). Plain pure white
background, no ground, no shadows on the ground, no text, no border, no extra objects. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


FRONT_PROMPT = """Image 1 is a render of a 3D defense tower model on a white ground. Image 2 is the concept painting of this
tower from the same angle. Repaint image 1 as a finished hand-painted picture in the exact painting style, colours and
surface of image 2, with all the small painted detail image 2 has: warm pale cut stone with soft painted edges and
darker gaps, red-brown wooden shingles with light top edges, warm wood with grain, polished brass with bright
highlights, fresh green ivy leaves, banners and cloth with the colours and emblem of image 2, a friendly archer face.

Hard rules: keep exactly the outline, size, position and every part of image 1: do not move, turn, resize, add or
remove anything. Plain pure white background, no ground shadow, no text, no border. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


# the Oak Barricade (on the path; its pictures show the side the enemies come from, +Y, azimuth 105)
BARRICADE_PROMPT = """Image 1 is a model sheet: the same 3D wooden barricade (a log wall that blocks a road) seen from four
sides in a 2 by 2 grid (top left the three-quarter view of the side the enemies come from, top right and bottom right
its two ends, bottom left the other face) on a white ground. Image 2 is the concept painting of this barricade, seen
from the same angle as the top left view.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
warm oak logs with long painted wood grain, darker gaps between the logs and soft round shading (light tops, darker
undersides), pale sawn log ends with growth rings and a darker heart, posts with vertical grain and pale carved pencil
points with knife-cut facets, dark iron bands with round brass rivets, a round wooden shield of dark planks with a
polished brass rim, brass studs and a shining brass boss, twisted cream rope, red-brown fire-hardened stakes with
charred black points, a dark wooden rail, living brown roots with bark, soft green moss, fresh green leaves, rich soft
shading with light from the top left, small painted details like image 2 shows them (only paint the parts image 1 has).

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, with exactly the
same outline as in image 1: do not move, turn, resize, add or remove any part (every log, post, band, rivet, stake,
root and leaf stays where it is). Plain pure white background, no ground, no road, no grass, no shadows on the ground,
no text, no border, no extra objects. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""

BARRICADE_FRONT_PROMPT = """Image 1 is a render of a 3D wooden barricade (a log wall that blocks a road) on a white ground. Image 2
is the concept painting of this barricade from the same angle. Repaint image 1 as a finished hand-painted picture in
the exact painting style, colours and surface of image 2, with all the small painted detail image 2 has: warm oak logs
with long painted grain and soft round shading, pale sawn log ends with growth rings, posts with pale carved pencil
points with knife-cut facets, dark iron bands with brass rivets, the round wooden shield with its polished brass rim,
studs and shining boss, twisted rope, red-brown stakes with charred points, roots with bark, moss and leaves (only the
parts image 1 has).

Hard rules: keep exactly the outline, size, position and every part of image 1: do not move, turn, resize, add or
remove anything. Plain pure white background, no ground, no road, no grass, no ground shadow, no text, no border.
Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


def codex_paint(prompt, name, folder, images):
    cmd = [find_codex(), "exec", "--skip-git-repo-check", "--sandbox", "workspace-write"]
    try:   # the default model in the owner's Codex config is not always served: name one from Codex's own list
        models = json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])
        slugs = [m["slug"] for m in models if m["slug"].startswith("gpt-") and "reserve" not in m["slug"]]
        # (gpt-6.2-sol is listed but refused on a ChatGPT login; terra works)
        model = next((m for m in slugs if "terra" in m), slugs[0] if slugs else None)
        if model:
            cmd += ["-m", model]
    except (OSError, ValueError):
        pass
    target = os.path.join(folder, name)
    if os.path.exists(target):
        os.remove(target)
    started = time.time()
    pictures = []
    for p in images:   # (-i takes several files, so the prompt goes first or it is read as another picture)
        pictures += ["-i", p]
    try:
        r = subprocess.run(cmd + [prompt.format(name=name)] + pictures, cwd=folder, capture_output=True, text=True,
                           stdin=subprocess.DEVNULL, encoding="utf-8", errors="ignore", timeout=1200)
        tail = ((r.stdout or "") + (r.stderr or ""))[-600:]
    except subprocess.TimeoutExpired:
        tail = "timed out"
    if not os.path.exists(target):
        made = [p for p in glob.glob(os.path.expanduser("~/.codex/generated_images/*/*.png")) if os.path.getmtime(p) > started]
        if made:
            shutil.copy(max(made, key=os.path.getmtime), target)
    if not os.path.exists(target):
        raise SystemExit("the painter returned no picture: " + tail)
    print("painted %s in %.0f s" % (name, time.time() - started), flush=True)


def find_codex():
    found = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    if not found:
        raise SystemExit("Codex (the ChatGPT VS Code extension) was not found")
    return found[-1]


VIEW_AZ = {"barricade": "105"}   # the picture's azimuth per tower kind (scripts/tower_stage.py)


def blender(*a):
    kind = os.path.basename(a[1]).split("_")[1] if os.path.basename(a[1]).startswith("tower_") else ""
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "tower_project.py"), "--", *a],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore",
                       env=dict(os.environ, HTD_VIEW_AZ=VIEW_AZ.get(kind, "-75")))
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith(("SHEET", "PROJECTED", "VIEW")) or "Error" in ln or "Traceback" in ln]
    print("\n".join(lines), flush=True)
    if not any(ln.startswith(("SHEET", "PROJECTED")) for ln in lines):
        raise SystemExit("Blender step failed:\n" + r.stdout[-1500:])


def main():
    fbx, target = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    strength = sys.argv[sys.argv.index("--strength") + 1] if "--strength" in sys.argv else "1.0"
    stem = fbx[:-4]
    tex, base = stem + "_paint.png", stem + "_base.png"
    views, painted = stem + "_views.png", stem + "_painted.png"
    front_painted = stem + "_front_painted.png"
    if "--reuse" not in sys.argv or not os.path.exists(base):
        shutil.copy(tex, base)      # a fresh build wrote a fresh plain texture: that is the base
        for skin in glob.glob(stem + "_paint_*.png"):   # the other parts' textures (tower kit atlases)
            shutil.copy(skin, stem + "_base_" + skin[len(stem + "_paint_"):])
    if "--reuse" not in sys.argv:
        blender("views", fbx, base, views)
        folder = os.path.dirname(fbx)
        barricade = "_barricade_" in os.path.basename(fbx)
        codex_paint(BARRICADE_PROMPT if barricade else PROMPT, os.path.basename(painted), folder, [views, target])
        codex_paint(BARRICADE_FRONT_PROMPT if barricade else FRONT_PROMPT, os.path.basename(front_painted), folder,
                    [views[:-4] + "_front.png", target])
    im = Image.open(painted).convert("RGB")
    if im.size != (1024, 1024):
        im.resize((1024, 1024), Image.LANCZOS).save(painted)
    if os.path.exists(front_painted):
        f = Image.open(front_painted).convert("RGB")
        if f.size != (1024, 1024):
            f.resize((1024, 1024), Image.LANCZOS).save(front_painted)
    blender("project", fbx, base, painted, tex, strength, front_painted)


if __name__ == "__main__":
    main()
