"""Painterly paint for the archer, with the pets' own workflow (Lemp 2026-11-23: "use the painterly workflow from the
pets thread"; docs/tower-pipeline.md "Painterly paint, shared with pets"). The pet scripts are called, never copied or
changed: scripts/pet_paint.py (no_face, align, the Blender runner) and art/blender/pet_project.py (views, project).
(This replaces the first archer_paint.py, written for the pet-kit archer with separate arms.)

  python scripts/archer_paint.py <build dir> <out dir> [--reuse] [--strength 1.0] [--crisp 5]
  (two painter runs: the whole archer for the arms, then head and body alone for them)

1. art/blender/archer_project.py packs Head, Body and both arms into one mesh with one atlas (the bow and quiver stay
   out and keep their paint); the plain bake is archer_pack_base.png and is never overwritten.
2. no_face: the painter gets him with eyes, brows and mouth filled with the skin round them (the face comes from the
   front painting only; the painter must not draw another one).
3. pet_project views -> the painter repaints the 2 x 2 sheet in the style of the main painting -> align (views under
   62 % outline overlap are skipped) -> pet_project project (noface) -> the atlas is cut back into the parts.
<out dir> gets ranger_archer.fbx (the build's, unchanged) and every part's painted picture."""
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
NAME = "ranger_archer"
TARGET = os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_34.png")
CELLS = {"head": (0, 0, 1024), "body": (1, 0, 1024), "armr": (0, 1, 512), "arml": (1, 1, 512)}

# the pets' no-face wording, for a character (pet_paint.NOFACE speaks of a pet with fur)
PROMPT = """Image 1 is a model sheet: the same 3D game character, a hooded archer, seen from four sides in a 2 by 2
grid (top left front, top right his left side, bottom left back, bottom right his right side) on a white ground. The
model has NO FACE on purpose: its eyes, eyebrows and mouth are added later by the game. Image 2 is the concept
painting of this character.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
soft painterly strokes on the cloth, leather and skin, rich warm shading, small painted details (cloth folds,
leather grain and stitching, the hood's soft creases, the sheen on the gold buckles), matte, no shine. Do NOT paint
eyes, eyebrows, eyelashes or a mouth anywhere: where they would be, paint plain skin like the rest of the face
(cheek blush is fine). The nose, the hair locks, the trim and the buckles that image 1 already shows stay where they
are and keep their own colour.

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, in the same pose,
with the same outline as in image 1: do not move, turn, resize, add or remove any part. The side views stay pure
side views, the back view shows the back. Plain pure white background, no ground, no shadows, no text, no border,
no extra objects. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


def paint_pass(fbx, work, strength, noarms, reuse):
    """one run of the pets' steps on a packed mesh; returns the painted atlas"""
    os.makedirs(work, exist_ok=True)
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "archer_project.py"), "--", "pack", fbx, work,
                        *(["noarms"] if noarms else [])], capture_output=True, text=True, encoding="utf-8", errors="ignore")
    if "PACKED" not in r.stdout:
        raise SystemExit("pack failed: " + r.stdout[-1500:])
    pack = os.path.join(work, "archer_pack.fbx")
    base = os.path.join(work, "archer_pack_base.png")
    keep = os.path.join(work, "archer_pack_keep.png")
    views = os.path.join(work, "archer_views.png")
    painted = os.path.join(work, "archer_painted.png")
    if not reuse:
        shown = pet_paint.no_face(base, keep, os.path.join(work, "archer_noface.png"))
        pet_paint.blender("views", pack, shown, views)
        if os.path.exists(painted):
            os.remove(painted)
        codex_paint(PROMPT.format(name=os.path.basename(painted)), os.path.basename(painted), work, [views, TARGET])
    aligned, bad = pet_paint.align(views, painted)[:2]   # (it also returns the lowest overlap now)
    # (HTD_SKIP_VIEWS=back: leave a view out by hand; round C: the painter drew a ghost face on the hood's back)
    bad = list(bad) + [v for v in os.environ.get("HTD_SKIP_VIEWS", "").split(",") if v and v not in bad]
    atlas = os.path.join(work, "archer_pack_painted_texture.png")
    pet_paint.blender("project", pack, base, aligned, atlas, strength, "noface", *(["skip=" + ",".join(bad)] if bad else []))
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "archer_project.py"), "--", "pad", pack, atlas],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    padded = [ln for ln in r.stdout.splitlines() if ln.startswith("PADDED")]
    print(padded[0] if padded else "pad failed: " + r.stdout[-800:])
    if bad:
        print("skipped views:", ", ".join(bad))
    return atlas


HOOD = (125, 155, 39)   # the painting's hood green (median of all its green pixels, scripts/archer_elf_spec.py)


def soften_hood(painted_path, plain_path, strength=0.5):
    """the hood in the painting is a fresh mid green with soft shading; painted, it came out dark olive with blotchy
    stains (coordinator 2026-11-23). On the hood's texels (green in the plain bake, not its dark inside) the colour is
    moved so its middle is the painting's green and the brush strokes keep half their contrast."""
    import numpy as np
    p = np.asarray(Image.open(painted_path).convert("RGB"), dtype=float)
    b = np.asarray(Image.open(plain_path).convert("RGB").resize((p.shape[1], p.shape[0])), dtype=float)
    lum = b @ np.array([0.3, 0.59, 0.11])
    hood = (b[..., 1] > b[..., 0] + 8) & (b[..., 1] > b[..., 2] + 30) & (lum > 70)
    if hood.sum() < 100:
        return
    mean = np.median(p[hood], axis=0)
    p[hood] = np.array(HOOD, dtype=float) + strength * (p[hood] - mean)
    Image.fromarray(np.clip(p, 0, 255).astype("uint8")).save(painted_path)
    print("hood softened: %d texels, middle %s -> %s" % (hood.sum(), mean.astype(int).tolist(), list(HOOD)))


def main():
    build, out = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    strength = sys.argv[sys.argv.index("--strength") + 1] if "--strength" in sys.argv else "1.0"
    reuse = "--reuse" in sys.argv
    fbx = os.path.join(build, NAME + ".fbx")
    # two runs: the whole archer (the arms take their paint from it), then head and body alone, so the torso's sides
    # that the arms hide in the side views are painted too (in one run they got only the painter's tone: a flat band)
    whole = paint_pass(fbx, os.path.join(out, "paint"), strength, False, reuse)
    alone = paint_pass(fbx, os.path.join(out, "paint_noarms"), strength, True, reuse)
    for part, (cx, cy, size) in CELLS.items():
        a = Image.open(alone if part in ("head", "body") else whole).convert("RGB")
        c = a.width // 2
        a.crop((cx * c, cy * c, (cx + 1) * c, (cy + 1) * c)).resize((size, size), Image.LANCZOS).save(
            os.path.join(out, f"{NAME}_{part}_paint.png"))
    if not os.environ.get("HTD_NO_SOFTEN"):
        soften_hood(os.path.join(out, f"{NAME}_head_paint.png"), os.path.join(build, f"{NAME}_head_paint.png"))
    for f in (NAME + ".fbx", f"{NAME}_bow_paint.png", f"{NAME}_quiver_paint.png", "gates_build.json"):
        shutil.copy(os.path.join(build, f), os.path.join(out, f))
    # the colour blended across every texture seam (about 3 px), so a cut never shows as a line
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "seam_blend.py"), "--", os.path.join(out, NAME + ".fbx"),
                        "radius=3", "skip=Bow,Quiver", "keep=Head:" + os.path.join(build, f"{NAME}_head_keep.png")],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    for ln in r.stdout.splitlines():
        if ln.startswith("BLENDED"):
            print(ln)
    print("PAINTED", out)


if __name__ == "__main__":
    main()
