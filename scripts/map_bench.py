"""Outside judge for the battle maps (Gemini, the same key and call as scripts/pet_bench.py): a harsh blind rating
of two unlabelled sets of phone-size stills of one map (A and B, the order is shuffled per map and printed last),
against how Dungeon Defenders builds its maps. My own scores run 1.5 to 3 points too kind: ask this before
quoting a score.
  python scripts/map_bench.py <takeA> <takeB> [Map ...]     e.g.  python scripts/map_bench.py before cycle2
Reads reviews/maps/img/<take>-<Map>-sheet.jpg, writes reviews/maps/bench-<takeA>-vs-<takeB>.md
The free key allows about 20 requests per model per day (shared with the other threads).
"""
import base64
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import pet_bench  # noqa: E402

PROMPT = """You are a harsh level-design reviewer for mobile games. The owner thinks parts of this Roblox tower
defense map reek of lazy AI work. Two sets of stills of the SAME map follow, set A then set B, taken at phone size
(a small screen; the HUD is part of the picture). Each set: the hero's start view, the plan from straight above,
a slanted overview, then seven views along the enemy lane at the play camera's angle. Monsters and defenders are
placed for the stills.

The bar is how Dungeon Defenders and Dungeon Defenders Awakened build maps: never an open rectangle; raised floors
and stairs; pits, lava or water the lanes cross on bridges; walls, gates and ruins that create chokepoints and
leave a few good building spots; one landmark you can name; dense but readable environment.

For EACH set give a 1-10 score (10 = a shipped Dungeon Defenders map, 5 = an average Roblox tower defense map,
2 = a flat field with a path) on: layout (lanes, chokepoints), obstacles and environment, height changes,
landmarks, readability on a phone, and overall. One line per score with the concrete thing you see in the stills
that earns or costs it. Then: the three weakest things in the better set, most damaging first, each with one
concrete fix. Do not praise. Do not guess what you cannot see. Under 320 words."""


def main():
    a, b = sys.argv[1], sys.argv[2]
    maps = sys.argv[3:] or ["CursedForest", "MagmaFortress", "CrystalCaves"]
    out = [f"# Outside judge: {a} vs {b}", ""]
    for m in maps:
        order = [a, b]
        random.shuffle(order)
        parts = []
        for label, take in zip("AB", order):
            path = os.path.join(ROOT, "reviews", "maps", "img", f"{take}-{m}-sheet.jpg")
            parts.append({"text": f"Set {label}:"})
            parts.append({"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(open(path, "rb").read()).decode()}})
        parts.append({"text": PROMPT})
        try:
            answer = pet_bench.call(parts)
        except RuntimeError as e:   # (the day's quota is used up: keep what was answered so far)
            answer = ("none", "no answer: " + str(e)[:160])
        out += [f"## {m}  (A = {order[0]}, B = {order[1]}; model {answer[0]})", "", str(answer[1]), ""]
        print(out[-4], "\n", out[-2], "\n", flush=True)
    open(os.path.join(ROOT, "reviews", "maps", f"bench-{a}-vs-{b}.md"), "w", encoding="utf-8").write("\n".join(out))


if __name__ == "__main__":
    main()
