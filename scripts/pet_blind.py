"""Blind test of two sets of pet pictures: Gemini sees them as "Set A" and "Set B" in random order and is not told
which is newer. This is the main outside measure of a cycle: an absolute score from scripts/pet_bench.py mostly
reflects its harsh prompt (2026-11-24: the same pets got 5.0 judged alone and 8.5 next to the old set), a side-by-side
choice does not.

  python scripts/pet_blind.py <name> --old old1.png old2.png --new new1.png new2.png
      -> reviews/pets/bench/blind-<name>.md   (the key, which set was A, is written at the top; the judge never saw it)

Sheets: each row one pet from three sides (the layout of reviews/pets/img/cycle5-sheet1.png). The free Gemini key
allows 20 requests per model per day: one run is one request.
"""
import base64
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "gemini-api-key.txt")).read().strip()
MODELS = ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-3.7-flash", "gemini-3.8-flash", "gemini-flash-latest"]   # never a lite model

PROMPT = """You are a harsh, independent Roblox art director. Two sets of pet models were made for the same new Roblox
tower defense game. Each set shows the same pets as still renders, each row one pet from three sides.
Images 1 to {na} are SET A. Images {nb0} to {nb1} are SET B. You do not know which set is older, cheaper or made by whom.
Ignore the background colour and the lighting of the renders: judge the models and their surfaces.

1. For each category, rate BOTH sets 1-10, harshly, against the best pets on Roblox in 2026 (Pet Simulator 99 huges,
   Adopt Me legendaries = 9-10; a ball with eyes built from primitives = 2-3), one line of reason:
   Silhouette / Face appeal / Form quality / Surface / Rarity read / Set cohesion.
2. Overall: which set would a 9-13 year old rather own, and by how much (slightly, clearly, by far)? Which set
   looks more professional?
3. For the better set: its three weakest pets (name them by what they look like) with the worst flaw of each, and
   its three strongest.
4. Is there anything the weaker set does BETTER than the stronger one?

Plain English, under 450 words. Start with a table: category | Set A | Set B."""


def ask(model, files, text):
    parts = [{"inline_data": {"mime_type": "image/png" if f.lower().endswith(".png") else "image/jpeg",
                              "data": base64.b64encode(open(f, "rb").read()).decode()}} for f in files]
    parts.append({"text": text})
    req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                                 data=json.dumps({"contents": [{"parts": parts}], "generationConfig": {"temperature": 0.2}}).encode(),
                                 method="POST", headers={"Content-Type": "application/json", "x-goog-api-key": KEY})
    with urllib.request.urlopen(req, timeout=300) as r:
        res = json.loads(r.read())
    return "".join(p.get("text", "") for p in res["candidates"][0]["content"]["parts"])


def main():
    name = sys.argv[1]
    i_old, i_new = sys.argv.index("--old"), sys.argv.index("--new")
    old = sys.argv[i_old + 1:i_new] if i_old < i_new else sys.argv[i_old + 1:]
    new = sys.argv[i_new + 1:i_old] if i_new < i_old else sys.argv[i_new + 1:]
    new_is_a = random.random() < 0.5
    a, b = (new, old) if new_is_a else (old, new)
    text = PROMPT.format(na=len(a), nb0=len(a) + 1, nb1=len(a) + len(b))
    dead, answer = set(), None
    for _ in range(8):
        for model in MODELS:
            if model in dead:
                continue
            try:
                answer = (model, ask(model, a + b, text))
                break
            except urllib.error.HTTPError as e:
                print("failed", model, e.code, file=sys.stderr)
                if e.code in (404, 429):   # gone, or today's allowance is used up: do not ask this model again
                    dead.add(model)
            except Exception as e:   # noqa: BLE001
                print("failed", model, e, file=sys.stderr)
        if answer or len(dead) == len(MODELS):
            break
        time.sleep(40)             # "high demand" (503) passes
    if not answer:
        raise SystemExit("no Gemini model answered (allowance used up until tomorrow morning?)")
    model, reply = answer
    key = "Set A = NEW, Set B = OLD" if new_is_a else "Set A = OLD, Set B = NEW"
    path = os.path.join(ROOT, "reviews", "pets", "bench", f"blind-{name}.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"# Blind test: {name}\n\nKey (not shown to the judge): {key}. Gemini model {model}.\n"
                f"Old: {', '.join(os.path.basename(x) for x in old)}. New: {', '.join(os.path.basename(x) for x in new)}.\n\n{reply}\n")
    print(path)
    print("KEY:", key)
    print(reply.encode("ascii", "ignore").decode())


if __name__ == "__main__":
    main()
