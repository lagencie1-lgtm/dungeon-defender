"""Blueprints for sculpting a pet: the target picture shows the pet from ONE side only, so the side and back of
every pet used to be guessed. This asks the picture painter (Codex image generation) for a model sheet of the same
character: straight front, its left side, back, its right side, in the same 2 x 2 layout the paint projection uses
(art/blender/pet_project.py), and then measures the built model against it.

  python scripts/pet_blueprint.py make <kind>      paint art/ref3d/turn/<kind>.png (about a minute; one job at a time)
  python scripts/pet_blueprint.py check <kind>     model views (art/models/pets2/paint/<kind>_views.png) against the
                                                   blueprint -> reviews/pets/img/_blue_<kind>.png and four overlaps

In the overlay picture: grey = both agree, red = the blueprint has shape there and the model has none (add clay),
blue = the model sticks out where the blueprint is empty (remove clay). Each view is first fitted to the same
outline box, so the numbers compare proportions, not size. The painter is not exact: use it as a guide for
proportions (how big is the head, where do the ears sit, how long is the muzzle), not as a ruler.
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TURN = os.path.join(ROOT, "art", "ref3d", "turn")
VIEWS = (("front", (0, 0)), ("left side", (1, 0)), ("back", (0, 1)), ("right side", (1, 1)))

PROMPT = """The attached image is the concept painting of a small cute game pet. Paint a character model sheet
(turnaround) of exactly this character, in exactly the same painting style and colours, as a 2 by 2 grid on a
plain pure white background:
top left: straight front view (looking at the viewer, symmetric);
top right: pure side view of its left side (the pet faces to the LEFT edge of the picture);
bottom left: straight back view;
bottom right: pure side view of its right side (the pet faces to the RIGHT edge of the picture).
Same character, same proportions, same size and same standing or sitting pose in all four views, the feet on the
same height in each row, no perspective (orthographic), each view centred in its quarter with a clear white gap
between the views. No text, no labels, no ground, no shadows, no border, no extra objects. Square image.

Use your image generation tool with the image as reference and save the result as {name} in the current folder.
Reply only with the file path."""


def find_codex():
    found = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    if not found:
        raise SystemExit("Codex (the ChatGPT VS Code extension) was not found")
    return found[-1]


def make(kind):
    os.makedirs(TURN, exist_ok=True)
    out = os.path.join(TURN, kind + ".png")
    target = os.path.join(ROOT, "art", "ref3d", "batch2", f"pet_{kind}.png")
    try:
        listed = [m["slug"] for m in json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])]
    except (OSError, ValueError):
        listed = []
    candidates = [m for m in listed if m.startswith("gpt-") and "reserve" not in m][:4] + ["gpt-6.1-terra", None]
    started = time.time()
    if os.path.exists(out):
        os.remove(out)
    tail = ""
    for model in dict.fromkeys(candidates):
        cmd = [find_codex(), "exec", "--skip-git-repo-check", "--sandbox", "workspace-write"] + (["-m", model] if model else [])
        try:
            r = subprocess.run(cmd + [PROMPT.format(name=kind + ".png"), "-i", target], cwd=TURN, capture_output=True, text=True,
                               stdin=subprocess.DEVNULL, encoding="utf-8", errors="ignore", timeout=1200)
            tail = ((r.stdout or "") + (r.stderr or ""))[-500:]
        except subprocess.TimeoutExpired:
            tail = "timed out"
        if os.path.exists(out) or "model_not_found" not in tail:
            break
    if not os.path.exists(out):
        made = [p for p in glob.glob(os.path.expanduser("~/.codex/generated_images/*/*.png")) if os.path.getmtime(p) > started]
        if made:
            shutil.copy(max(made, key=os.path.getmtime), out)
    if not os.path.exists(out):
        raise SystemExit("the painter returned no picture: " + tail)
    Image.open(out).convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out)
    print("blueprint", out, "in %.0f s" % (time.time() - started))


def mask(im):
    r, g, b = im.convert("RGB").split()
    f = lambda v: 255 if v < 238 else 0  # noqa: E731
    return ImageChops.lighter(ImageChops.lighter(r.point(f), g.point(f)), b.point(f))


def check(kind):
    blue = Image.open(os.path.join(TURN, kind + ".png")).convert("RGB").resize((1024, 1024))
    views = Image.open(os.path.join(ROOT, "art", "models", "pets2", "paint", f"{kind}_views.png")).convert("RGB").resize((1024, 1024))
    N = 420
    sheet = Image.new("RGB", (N * 4, N * 3 + 34), (30, 30, 34))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arialbd.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    scores = []
    for i, (name, (cx, cy)) in enumerate(VIEWS):
        box = (cx * 512, cy * 512, cx * 512 + 512, cy * 512 + 512)
        b, v = blue.crop(box), views.crop(box)
        mb, mv = mask(b), mask(v)
        bb, vb = mb.getbbox(), mv.getbbox()
        if not bb or not vb:
            continue

        def fit(im, bx):   # the outline box of each onto the same square, feet on the same line
            c = im.crop(bx)
            s = min(N * 0.9 / c.width, N * 0.9 / c.height)
            c = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
            out = Image.new(im.mode, (N, N), "white" if im.mode == "RGB" else 0)
            out.paste(c, ((N - c.width) // 2, N - 12 - c.height))
            return out

        fb, fv, fmb, fmv = fit(b, bb), fit(v, vb), fit(mb, bb), fit(mv, vb)
        both = ImageChops.multiply(fmb, fmv)
        only_b = ImageChops.subtract(fmb, fmv)
        only_v = ImageChops.subtract(fmv, fmb)
        inter = sum(1 for p in both.getdata() if p)
        union = inter + sum(1 for p in only_b.getdata() if p) + sum(1 for p in only_v.getdata() if p)
        scores.append(f"{name} {100 * inter / max(1, union):.0f}%")
        over = Image.new("RGB", (N, N), (245, 245, 245))
        over.paste((150, 150, 150), (0, 0), both)
        over.paste((225, 60, 50), (0, 0), only_b)
        over.paste((50, 110, 230), (0, 0), only_v)
        sheet.paste(fb, (i * N, 34))
        sheet.paste(fv, (i * N, 34 + N))
        sheet.paste(over, (i * N, 34 + 2 * N))
        draw.text((i * N + 8, 6), name, fill="white", font=font)
    draw.text((8, 34 + 4), "BLUEPRINT", fill=(150, 110, 20), font=font)
    draw.text((8, 34 + N + 4), "MODEL", fill=(30, 130, 60), font=font)
    draw.text((8, 34 + 2 * N + 4), "red = add clay, blue = remove", fill=(60, 60, 60), font=font)
    out = os.path.join(ROOT, "reviews", "pets", "img", f"_blue_{kind}.png")
    sheet.save(out)
    print(kind, "blueprint overlap:", "  ".join(scores))


if __name__ == "__main__":
    {"make": make, "check": check}[sys.argv[1]](sys.argv[2])
