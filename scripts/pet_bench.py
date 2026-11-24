"""Pet benchmark: asks Gemini to watch a public YouTube video of another Roblox game's pets (or a clip / picture
sheet of ours) and describe and rate the pets the same way every time, so the scores are comparable
(reviews/pets/SCORES.md). Sister of scripts/yt_review.py (hub benchmark).

  python scripts/pet_bench.py "Game name" https://www.youtube.com/watch?v=...   -> reviews/pets/bench/<game>.md
  python scripts/pet_bench.py --ours name file.mp4|file.png [more files]          -> reviews/pets/bench/ours-<name>.md

Needs the Gemini key in tools/gemini-api-key.txt. Gemini invents things: check claims against frames.
"""
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "gemini-api-key.txt")).read().strip()
OUT = os.path.join(ROOT, "reviews", "pets", "bench")
MODELS = ["gemini-pro-latest", "gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash", "gemini-flash-latest"]

AXES = """Rate the PETS 1-10, harshly, against the best pets on Roblox in 2026 (Pet Simulator 99 huges, Adopt Me
legendaries = 9-10; a ball with eyes built from primitives = 2-3). One line of reason each:
- Silhouette: is each pet recognisable as a black shape at thumbnail size, and different from the others?
- Face appeal: eyes, mouth, expression; does a 9-13 year old go "aww, I want that one"?
- Form quality: clean, deliberate shapes and proportions; no lumps, stray pieces, clipping or accidental facets?
- Surface: colour choices, painted or modelled detail, gradients, clean material read; nothing flat or muddy?
- Rarity read: do rare pets look clearly more special than common ones (not just bigger)?
- Set cohesion: do all pets look like one game's family?
- Motion and life: idle, hop, follow, tricks, hatch reveal (write n/a for still pictures)."""

PROMPT_YT = """You are a harsh, experienced Roblox art director. This video shows the Roblox game "{game}". Look only
at the PETS (the small companion creatures), not at the map or menus. Judge only what is visible; write "not visible"
rather than guess. Give timestamps [mm:ss] for every claim.

Part A - how the pets are built (be concrete, estimate numbers):
1. Body recipe: basic shapes, head-to-body ratio, how many separate pieces, legs or no legs, how blocky or round.
2. Face: eye shape, size (as a share of the head width), spacing, highlights, pupils; mouth, nose, blush; is the face
   painted on (texture) or modelled?
3. Surface: flat colours or gradients, how many colours per pet, outlines, shading, shine, glow; smooth or faceted.
4. What makes the rare / top-tier pets special compared to the common ones (shape, size, effects, materials, aura).
5. Motion: how pets idle, follow, hop, float, attack; hatch or reveal animation, with timings.
6. How pets are shown in menus (inventory tiles, hatch screen): angle, background, frame, size.

Part B - """ + AXES + """

Part C - the 7 most copyable rules a small new game should follow to make its own original pets look this good
(concrete, with numbers). Do not suggest copying any specific pet.

Plain English, under 750 words."""

PROMPT_OURS = """You are a harsh, independent Roblox art director. You never saw the design intent. The owner thinks
these pets look like cheap AI-made placeholder models. The material shows the pets of a new Roblox tower defense game
("Heroes Tower Defense"){what}. Judge only what is visible.

Part A - for EACH pet (name it by what it looks like), one line: what works, and the worst flaw.
Part B - """ + AXES + """
Part C - the 8 changes that would lift these pets the most toward Pet Simulator 99 / Adopt Me quality, worst gap
first, each as: what you see -> why it fails -> a concrete fix with numbers.

Plain English, under 650 words."""


def call(parts):
    body = {"contents": [{"parts": parts}], "generationConfig": {"temperature": 0.2}}
    last = None
    for attempt in range(4):
        for model in MODELS:
            req = urllib.request.Request(
                f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                data=json.dumps(body).encode(), method="POST",
                headers={"Content-Type": "application/json", "x-goog-api-key": KEY})
            try:
                with urllib.request.urlopen(req, timeout=400) as r:
                    res = json.loads(r.read())
                return model, "".join(p.get("text", "") for p in res["candidates"][0]["content"]["parts"])
            except urllib.error.HTTPError as e:
                last = f"{model}: {e.code} {e.read()[:200]!r}"
            except Exception as e:
                last = f"{model}: {e}"
            print("failed:", last, file=sys.stderr)
        time.sleep(30)
    raise RuntimeError(last)


def main():
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1] == "--ours":
        name, files = "ours-" + sys.argv[2], sys.argv[3:]
        parts = []
        for f in files:
            mime = "video/mp4" if f.lower().endswith(".mp4") else "image/png" if f.lower().endswith(".png") else "image/jpeg"
            parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(open(f, "rb").read()).decode()}})
        video = any(f.lower().endswith(".mp4") for f in files)
        what = ", filmed in the game" if video else ", as still renders (each row is one pet from three sides)"
        if any("roblox" in os.path.basename(f).lower() for f in files):
            what += " and as screenshots taken inside Roblox (one pet per tile)"
        game, src = "Heroes Tower Defense (ours)", ", ".join(os.path.basename(f) for f in files)
        parts.append({"text": PROMPT_OURS.format(what=what)})
    else:
        game, src = sys.argv[1], sys.argv[2]
        name = re.sub(r"[^a-z0-9]+", "-", game.lower()).strip("-")
        parts = [{"file_data": {"file_uri": src, "mime_type": "video/*"}}, {"text": PROMPT_YT.format(game=game)}]
    model, text = call(parts)
    path = os.path.join(OUT, name + ".md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"# {game}: pets\n\nSource: {src} (Gemini model {model})\n\n{text}\n")
    print(path)
    print(text.encode("ascii", "ignore").decode())


if __name__ == "__main__":
    main()
