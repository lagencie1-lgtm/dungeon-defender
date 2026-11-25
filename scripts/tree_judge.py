"""Blind outside check of map trees (the tower workflow's last gate): two in-game stills of the same view, A and B in
an order set by a coin flip, judged by Gemini without being told which is new.
  python scripts/tree_judge.py old.jpg new.jpg [more_old.jpg more_new.jpg ...]
Prints the verdict and which picture was which; appends to reviews/maps/trees.md."""
import base64
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from pet_bench import call  # noqa: E402

PROMPT = """You are a harsh, independent art director for stylised fantasy games (think Kingdom Rush, Dungeon
Defenders, hand-painted Roblox games). Below are pairs of screenshots of the SAME view of a Roblox tower defense map,
labelled A and B. Look only at the TREES (crowns, trunks, how they sit together), not at the UI, path or characters.
For A and for B, score 1-10 each:
- Painted look: does it read as hand-painted stylised fantasy foliage (10), or as glossy plastic balls / bubble gum
  (1-2)?
- Shape: believable trunk, limbs and crown masses with a clear silhouette, or blobs on sticks?
- Light: a clear light side and shadow side in the crowns, or flat one-colour green?
- Fit: do the trees suit a painted fantasy game world?
Then: which set of trees is better overall (A or B), and the 3 biggest remaining flaws of the better one, each with a
concrete fix. Plain English, under 300 words."""


def image(path):
    return {"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(open(path, "rb").read()).decode()}}


def main():
    files = sys.argv[1:]
    flip = random.Random().random() < 0.5
    parts = [{"text": PROMPT}]
    for i in range(0, len(files), 2):
        old, new = files[i], files[i + 1]
        a, b = (new, old) if flip else (old, new)
        parts += [{"text": f"Pair {i // 2 + 1}, A:"}, image(a), {"text": f"Pair {i // 2 + 1}, B:"}, image(b)]
    model, text = call(parts)
    key = f"(blind: A = {'NEW' if flip else 'OLD'}, B = {'OLD' if flip else 'NEW'}; {model})"
    print(text)
    print(key)
    with open(os.path.join(ROOT, "reviews", "maps", "trees.md"), "a", encoding="utf-8") as f:
        f.write(f"\n## Judge {key}\nFiles: {', '.join(os.path.basename(x) for x in files)}\n\n{text}\n")


if __name__ == "__main__":
    main()
