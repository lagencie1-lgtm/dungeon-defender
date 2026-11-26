"""Checks the owner's pet complaints as rules, so they cannot come back (6A: turn every complaint into a checked
rule). Run: python scripts/pet_rules.py     exits 1 and names the pet when a rule is broken.

Rules
  heads      "the head of each is just a round bubble" (Lemp 2026-11-23): every pet's head is built with K.head()
             (skull, cheeks, jaw, brow) or, for the few one-piece pets, has its own cheek / brow shapes.
  budget     at most 9,000 triangles and one texture per pet (phones).
  labelled   comparison sheets carry column labels (Lemp could not tell the target from the result).
  in game    the model id and the paint id the game uses for a pet were uploaded together (no new shape under old paint).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "art", "blender", "pets2.py"), encoding="utf-8").read()
KINDS = ["slimey", "leafling", "stonepup", "mosskitten", "glowbug", "emberfox", "crystalowl", "minigolem", "babydragon",
         "starunicorn", "phoenix", "voiddrake"]
# one-piece pets: the whole body is the head. They must still shape the face with extra pieces.
ONE_PIECE = {"slimey": "Curl", "leafling": "Cap", "crystalowl": "OwlBrow"}
problems = []

blocks = re.split(r"\n(?:el)?if kind (?:==|in) ", src)
for kind in KINDS:
    block = next((b for b in blocks if f'"{kind}"' in b.split("\n", 1)[0]), None)
    if block is None:
        problems.append(f"{kind}: not built in pets2.py")
        continue
    if kind in ONE_PIECE:
        if ONE_PIECE[kind] not in block:
            problems.append(f"{kind}: one-piece pet without its face shaping ({ONE_PIECE[kind]})")
    elif "K.head(" not in block:
        problems.append(f"{kind}: bubble head (build the head with K.head)")
    for tris in re.findall(r"triangles=(\d+)", block):
        if int(tris) > 9000:
            problems.append(f"{kind}: {tris} triangles (limit 9,000)")
# in game: a pet's model and its paint in src/shared/Art.luau must be a pair that was uploaded together
# (reviews/pets/assets.json, or the earlier pair in reviews/pets/old-ids.json): a new shape under an old paint, or the
# other way round, shows smeared in the game
import json  # noqa: E402
art = open(os.path.join(ROOT, "src", "shared", "Art.luau"), encoding="utf-8").read()
models_block, textures_block = art[art.index("Art.Models = {"):art.index("Art.Textures = {")], art[art.index("Art.Textures = {"):]
pairs = []
for name in ("assets.json", "old-ids.json"):
    f = os.path.join(ROOT, "reviews", "pets", name)
    if os.path.exists(f):
        pairs.append(json.load(open(f)))
for kind in KINDS:
    m = re.search(r'\spet_' + kind + r' = "(\d+)"', models_block)
    t = re.search(r'\spaint_pet_' + kind + r' = "(\d+)"', textures_block)
    if not m or not t:
        problems.append(f"{kind}: no model or paint id in Art.luau")
    elif not any(p.get(kind, {}).get("model") == m.group(1) and p.get(kind, {}).get("paint") == t.group(1) for p in pairs):
        problems.append(f"{kind}: the model and paint ids in Art.luau are not a pair that was uploaded together")
if "TARGET PICTURE" not in open(os.path.join(ROOT, "scripts", "pet_match.py"), encoding="utf-8").read():
    problems.append("comparison sheets have no column labels")
print("\n".join(problems) if problems else "pet rules OK (12 pets)")
sys.exit(1 if problems else 0)
