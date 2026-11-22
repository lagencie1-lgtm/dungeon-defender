"""Paints the reference pictures Lemp feeds into Tripo (image to 3D) for the Watch Keep's buildings:
one object, front three-quarter view, plain white background, the game's painted style (art/STYLE.md).
Output: art/ref3d/keep_<name>.png. Uses a Gemini image model (key in tools/gemini-api-key.txt).
Run: python scripts/ref3d.py [name ...]
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "gemini-api-key.txt")).read().strip()
OUT = os.path.join(ROOT, "art", "ref3d")
MODELS = ["gemini-3.1-flash-image"]

STYLE = ("A single game asset for a 3D model reference: {what}. Front three-quarter view from slightly above, the whole "
         "object in frame and centred, plain pure white background, no ground, no shadow box, no text, no letters, no "
         "people. Painted fantasy style for a friendly kids' game: soft painterly shading, bold readable silhouette, "
         "chunky proportions, light from the top-left. Palette: dark wood #46301E, brass #D6AA50, cream #F3E6C8, "
         "pale warm stone, one accent colour {accent}. Not photo-real, not glossy plastic, no thin details.")

ITEMS = {
    "portal_gate": ("a grand round portal gate: a thick ring of carved pale stone with five violet rune stones set "
                    "around it, standing on a wide three-step stone base, two short stone pillars with brass caps at "
                    "its sides; the inside of the ring is empty", "violet #AA96FF"),
    "forge_house": ("a small blacksmith workshop: stone walls, a timber frame and a red shingle roof, a big stone "
                    "chimney, the front open with an anvil on a tree stump and a glowing hearth inside", "fire orange #FF7A2A"),
    "shop_stall": ("a market stall: four wooden posts, a striped awning in sky blue and cream, a wooden counter "
                   "with glass jars full of cyan gems and small crates beside it", "gem cyan #5ADCFF"),
    "pet_house": ("a pet nursery: a hollow tree stump made into a little house with a round door and a straw roof, "
                  "a big straw nest on top holding three speckled eggs", "nature green #5FB45A"),
    "quest_board": ("a tall wooden notice board with a small shingle roof, five parchment notes pinned to it with "
                    "brass pins, a lantern hanging at one side", "gold yellow #FFD246"),
    "reward_chest": ("a huge treasure chest with a rounded lid, dark wood with brass bands and corners, a golden "
                     "lock, standing on a low round stone dais", "gold yellow #FFD246"),
    "tower_ranger_sheet": ("three versions of the same archer defense tower standing side by side left to right, growing with each upgrade level, all at the same scale on one shared white background: LEFT level 1, a small wooden watch post on a round stone footing with a plank lookout, one hooded green archer with a bow, a short shingled roof; MIDDLE level 2, a round warm-stone tower with an arched wooden door, ivy, a timber lookout with railings, a tall red-brown shingled cone roof with a green pennant, one archer; RIGHT level 3, a taller tower with a second stone storey and brass bands, green and cream banners, a wider lookout with two archers, a tall roof with a glowing green gem on the finial. Same three-quarter view, same light, clearly one family", "forest green #5FB45A"),
    "beacon_tower": ("a tall square watchtower of pale warm stone with a wide archway at its foot, battlements at "
                     "the top and a timber lantern cage with a pointed blue roof holding a big glowing violet crystal, "
                     "blue cloth banners with brass hems hanging either side of the arch", "violet #AA96FF"),
    "hero_statue": ("a heroic stone statue of a young knight raising a sword to the sky, cape flowing, on a round "
                    "stepped plinth with a brass band", "nature green #5FB45A"),
}


def paint(name):
    what, accent = ITEMS[name]
    body = {"contents": [{"parts": [{"text": STYLE.format(what=what, accent=accent)}]}],
            "generationConfig": {"responseModalities": ["IMAGE"]}}
    last = None
    for model in MODELS:
        req = urllib.request.Request(
            f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            data=json.dumps(body).encode(), method="POST",
            headers={"Content-Type": "application/json", "x-goog-api-key": KEY})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                res = json.loads(r.read())
            for part in res["candidates"][0]["content"]["parts"]:
                data = part.get("inlineData") or part.get("inline_data")
                if data:
                    path = os.path.join(OUT, (name if name.startswith("tower_") else "keep_" + name) + ".png")
                    with open(path, "wb") as f:
                        f.write(base64.b64decode(data["data"]))
                    print(name, "->", path, "(" + model + ")")
                    return
            last = f"{model}: no image"
        except urllib.error.HTTPError as e:
            last = f"{model}: {e.code} {e.read()[:200]!r}"
        except Exception as e:
            last = f"{model}: {e}"
        print("failed", last, file=sys.stderr)
    # the free Gemini key has no image quota: paint with Codex (the owner's ChatGPT login), as art/make_icons.py does
    import glob
    import subprocess
    found = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    target = os.path.join(OUT, (name if name.startswith("tower_") else "keep_" + name) + ".png")
    if found:
        prompt = (STYLE.format(what=what, accent=accent) + f" Use your image generation tool and save the image as "
                  f"{name if name.startswith('tower_') else 'keep_' + name}.png in the current folder. Reply only with the file path.")
        try:
            # the default model in the owner's Codex config is no longer served for ChatGPT logins: name one
            # from Codex's own list (~/.codex/models_cache.json)
            models = json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])
            model = next((m["slug"] for m in models if m["slug"].startswith("gpt-") and "reserve" not in m["slug"]), "gpt-6.1-terra")
            started = __import__("time").time()
            subprocess.run([found[-1], "exec", "-m", model, "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                           cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        except subprocess.TimeoutExpired:
            pass
        if not os.path.exists(target):
            # Codex sometimes keeps the picture in its own folder: take the one it made just now
            import shutil
            made = [p for p in glob.glob(os.path.expanduser("~/.codex/generated_images/*/*.png")) if os.path.getmtime(p) > started]
            if made:
                shutil.copy(max(made, key=os.path.getmtime), target)
    print("made with Codex" if os.path.exists(target) else "FAILED", name, "" if os.path.exists(target) else last, flush=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n in sys.argv[1:] or ITEMS:
        paint(n)
