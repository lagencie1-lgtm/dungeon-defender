"""Hand-painted surface for a code-built pet (no image-to-3D service): renders the model from four sides, lets the
picture painter (Codex image generation, the owner's ChatGPT login) repaint that sheet in the style of the pet's
target picture, and projects the paint back onto the model (art/blender/pet_project.py).

  python scripts/pet_paint.py <kind>            paint + project      -> art/models/pets2/pet_<kind>_paint.png
  python scripts/pet_paint.py <kind> --reuse    project the painted sheet that is already there (after a model fix
                                                that kept the outline, or to try another strength)
  --strength 0.85   how much of the new paint is used (1 = all)
  --crisp 5         flatten the painter's small strokes into clean patches (median filter of that size) and
                    project from a doubled, sharpened sheet
  --tries 3         paint up to that many sheets and keep the one whose worst side fits the model best
  --noface          the painter gets the pet WITHOUT eyes and mouth and is told to paint none, so it cannot leave
                    its own eyes beside ours (brown smudges). The real eyes and mouth come back from the plain texture.

The plain baked texture is kept as pet_<kind>_base.png, so a bad painting can always be thrown away.
Files in art/models/pets2/paint/: <kind>_views.png (what the painter gets), <kind>_painted.png (what it returns).
Run only one painting job at a time (two in parallel stall).
"""
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
D = os.path.join(ROOT, "art", "models", "pets2")
P = os.path.join(D, "paint")

PROMPT = """Image 1 is a model sheet: the same 3D pet model seen from four sides in a 2 by 2 grid (top left front,
top right its left side, bottom left back, bottom right its right side) on a white ground. Image 2 is the concept
painting of this pet.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
soft painterly fur or skin strokes, rich warm shading, small painted details (fur tufts, markings, stripes, scales,
leaf veins, as image 2 shows them), clean dark-brown outline. Do NOT redraw the face: leave the eyes and the mouth
of image 1 exactly as they are, in the same place, size and shape, and only paint the fur or skin around them.

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, in the same pose,
with the same outline as in image 1: do not move, turn, resize, add or remove any body part. The left and right side
views must stay pure side views, the back view must show the back (no face). Plain pure white background, no ground,
no shadows, no text, no border, no extra objects. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


# (The first version said "no nose": the painter then turned the fox's nose to fur and the stone puppy's nose and
# tongue to stone. Noses, beaks and tongues are model parts, so the painter must keep them.)
NOFACE = """Image 1 is a model sheet: the same 3D pet model seen from four sides in a 2 by 2 grid (top left front,
top right its left side, bottom left back, bottom right its right side) on a white ground. The model has NO FACE on
purpose: its eyes and mouth are added later by the game. Image 2 is the concept painting of this pet.

Repaint image 1 as a finished hand-painted model sheet in the exact painting style, colours and surface of image 2:
soft painterly fur or skin strokes, rich warm shading, small painted details (fur tufts, markings, stripes, scales,
leaf veins, as image 2 shows them), clean dark-brown outline. Do NOT paint eyes, eyebrows, eyelashes or a mouth
anywhere: where they would be, paint plain fur or skin like the rest of the head (cheek blush is fine). A nose, a beak,
a tongue, horns, claws or teeth that image 1 already shows stay where they are and keep their own colour.

Hard rules: keep the 2 by 2 layout. Every view stays in exactly the same place, at the same size, in the same pose,
with the same outline as in image 1: do not move, turn, resize, add or remove any body part. The left and right side
views must stay pure side views, the back view must show the back. Plain pure white background, no ground,
no shadows, no text, no border, no extra objects. Square image.

Use your image generation tool with both images as references and save the result as {name} in the current folder.
Reply only with the file path."""


def no_face(base_path, keep_path, out_path):
    """The plain texture with eyes and mouth painted over by the skin round them (grown inwards from their edge).
    The painter gets a pet without a face, so it cannot draw its own eyes in a slightly different place: those
    leftovers were the brown smudges round the eyes. The real eyes and mouth come back from the plain texture."""
    import numpy as np
    b = np.asarray(Image.open(base_path).convert("RGB"), dtype=float) / 255
    k = np.asarray(Image.open(keep_path).convert("L").resize((b.shape[1], b.shape[0])), dtype=float) / 255
    hole = k > 0.02
    for _ in range(4):   # the soft rim of every mark belongs to the hole
        m = hole.copy()
        m[1:, :] |= hole[:-1, :]; m[:-1, :] |= hole[1:, :]; m[:, 1:] |= hole[:, :-1]; m[:, :-1] |= hole[:, 1:]
        hole = m
    known = ~hole
    img = b * known[..., None]
    for _ in range(600):
        if known.all():
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(known.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            src = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * src[..., None]
            cnt += src
        new = (~known) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        known |= new
    soft = img.copy()
    for _ in range(12):   # blur the filled skin so no streaks show
        soft = (soft + np.roll(soft, 1, 0) + np.roll(soft, -1, 0) + np.roll(soft, 1, 1) + np.roll(soft, -1, 1)) / 5
        soft = np.where(hole[..., None], soft, img)
    Image.fromarray((np.clip(soft, 0, 1) * 255 + 0.5).astype("uint8")).save(out_path)
    return out_path


def find_codex():
    found = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    if not found:
        raise SystemExit("Codex (the ChatGPT VS Code extension) was not found")
    return found[-1]


def blender(*a):
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "pet_project.py"), "--", *a],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith(("SHEET", "PROJECTED")) or "Error" in ln or "Traceback" in ln]
    print("\n".join(lines))
    if not any(ln.startswith(("SHEET", "PROJECTED")) for ln in lines):
        raise SystemExit("Blender step failed:\n" + r.stdout[-1500:])


CRISP = int(sys.argv[sys.argv.index("--crisp") + 1]) if "--crisp" in sys.argv else 0   # median size (odd), 0 = off
SKIP_UNDER = 0.62   # a view whose painted outline covers less than this of the model's outline is not projected


def align(views_path, painted_path):
    """The painter never keeps a view pixel-exact: it tends to draw the pet a little bigger or shifted. Each of the
    four views is therefore stretched so that its painted outline box sits exactly on the rendered outline box, and
    the overlap of the two outlines is printed (under about 80% the painter changed the shape: paint again)."""
    from PIL import ImageChops
    views = Image.open(views_path).convert("RGB").resize((1024, 1024))
    painted = Image.open(painted_path).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    out = Image.new("RGB", (1024, 1024), "white")
    scores = []
    bad = []
    lowest = 1.0

    def mask(im):
        r, g, b = im.split()
        return ImageChops.lighter(ImageChops.lighter(r.point(lambda v: 255 if v < 240 else 0), g.point(lambda v: 255 if v < 240 else 0)),
                                  b.point(lambda v: 255 if v < 240 else 0))

    for name, (cx, cy) in (("front", (0, 0)), ("left", (1, 0)), ("back", (0, 1)), ("right", (1, 1))):
        box = (cx * 512, cy * 512, cx * 512 + 512, cy * 512 + 512)
        v, pnt = views.crop(box), painted.crop(box)
        vb, pb = mask(v).getbbox(), mask(pnt).getbbox()
        if not vb or not pb:
            out.paste(pnt, box[:2])
            continue
        fitted = pnt.crop(pb).resize((vb[2] - vb[0], vb[3] - vb[1]), Image.LANCZOS)
        cell = Image.new("RGB", (512, 512), "white")
        cell.paste(fitted, vb[:2])
        mv, mp = mask(v), mask(cell)
        inter = sum(1 for x in ImageChops.multiply(mv, mp).getdata() if x)
        union = sum(1 for x in ImageChops.lighter(mv, mp).getdata() if x)
        scores.append(f"{name} {100 * inter / max(1, union):.0f}%")
        lowest = min(lowest, inter / max(1, union))
        if inter / max(1, union) < SKIP_UNDER:
            bad.append(name)
        out.paste(cell, box[:2])
    if CRISP:
        # Clean shading planes instead of soft noise (the outside judge: fur and leaves "muddy" next to the top
        # games): a median filter flattens the painter's small strokes into clear patches and keeps their edges,
        # then the sheet is doubled and sharpened so the projection has clean edges to sample.
        from PIL import ImageFilter
        out = out.filter(ImageFilter.MedianFilter(CRISP)).resize((2048, 2048), Image.LANCZOS)
        out = out.filter(ImageFilter.UnsharpMask(radius=3, percent=80, threshold=2))
    out.save(painted_path[:-4] + "_aligned.png")
    print("outline overlap after fitting:", "  ".join(scores))
    if bad:
        print("not projected (the painter changed the shape too much, its paint would land on the wrong parts):", ", ".join(bad))
    return painted_path[:-4] + "_aligned.png", bad, lowest


def main():
    kind = sys.argv[1]
    strength = sys.argv[sys.argv.index("--strength") + 1] if "--strength" in sys.argv else "1.0"
    os.makedirs(P, exist_ok=True)
    fbx = os.path.join(D, f"pet_{kind}.fbx")
    tex = os.path.join(D, f"pet_{kind}_paint.png")
    base = os.path.join(D, f"pet_{kind}_base.png")
    views = os.path.join(P, f"{kind}_views.png")
    painted = os.path.join(P, f"{kind}_painted.png")
    if not os.path.exists(base):
        # a fresh build wrote a fresh plain texture and removed the old base (scripts/pet_cycle.sh): that is the base.
        # When the base is still there, the texture is already painted and must never replace it.
        shutil.copy(tex, base)
    noface = "--noface" in sys.argv
    marker = os.path.join(P, f"{kind}_noface.txt")   # remembers how the painted sheet was made, for --reuse
    if "--reuse" in sys.argv:
        noface = os.path.exists(marker)
    elif os.path.exists(marker):
        os.remove(marker)
    if "--reuse" not in sys.argv:
        shown = base
        if noface:
            shown = no_face(base, os.path.join(D, f"pet_{kind}_keep.png"), os.path.join(P, f"{kind}_noface.png"))
        blender("views", fbx, shown, views)
        target = os.path.join(ROOT, "art", "ref3d", "batch2", f"pet_{kind}.png")
        # (-i takes several files, so the prompt goes first or it is read as another picture)
        cmd = [find_codex(), "exec", "--skip-git-repo-check", "--sandbox", "workspace-write"]
        pictures = ["-i", views, "-i", target]
        # the default model in the owner's Codex config is not always served for ChatGPT logins, and the list
        # changes: try the models Codex itself lists, one after the other, until one paints
        try:
            listed = [m["slug"] for m in json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])]
        except (OSError, ValueError):
            listed = []
        candidates = [m for m in listed if m.startswith("gpt-") and "reserve" not in m][:4] + ["gpt-6.1-terra", None]
        # The painter is a little different every time. With --tries N it paints up to N sheets and the one whose
        # worst side fits the model best is kept (it stops early once every side fits 85%).
        tries = int(sys.argv[sys.argv.index("--tries") + 1]) if "--tries" in sys.argv else 1
        best, best_low = os.path.join(P, f"{kind}_painted_best.png"), -1.0
        for attempt in range(tries):
            if os.path.exists(painted):
                os.remove(painted)
            started = time.time()
            tail = ""
            for model in dict.fromkeys(candidates):
                try:
                    r = subprocess.run(cmd + (["-m", model] if model else []) + [(NOFACE if noface else PROMPT).format(name=os.path.basename(painted))] + pictures,
                                       cwd=P, capture_output=True, text=True, stdin=subprocess.DEVNULL, encoding="utf-8", errors="ignore", timeout=1200)
                    tail = ((r.stdout or "") + (r.stderr or ""))[-600:]
                except subprocess.TimeoutExpired:
                    tail = "timed out"
                if os.path.exists(painted) or "model_not_found" not in tail:
                    break
            if not os.path.exists(painted):
                made = [p for p in glob.glob(os.path.expanduser("~/.codex/generated_images/*/*.png")) if os.path.getmtime(p) > started]
                if made:
                    shutil.copy(max(made, key=os.path.getmtime), painted)
            if not os.path.exists(painted):
                if best_low >= 0:
                    break
                raise SystemExit("the painter returned no picture: " + tail)
            print("painted in %.0f s" % (time.time() - started))
            if tries == 1:
                break
            low = align(views, painted)[2]
            if low > best_low:
                best_low = low
                shutil.copy(painted, best)
            if low >= 0.85:
                break
        if tries > 1:
            shutil.copy(best, painted)
            print("kept the painting whose worst side fits %.0f%%" % (100 * best_low))
        if noface:
            open(marker, "w").write("painted without a face")
    aligned, bad, _ = align(views, painted)
    blender("project", fbx, base, aligned, tex, strength, *(["noface"] if noface else []), *(["skip=" + ",".join(bad)] if bad else []))


if __name__ == "__main__":
    main()
