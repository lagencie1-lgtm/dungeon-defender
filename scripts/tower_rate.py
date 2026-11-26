"""Per-part rating of every tower level (coordinator 2026-11-26): Codex, as an outside art director, gets the concept
painting, the 16-frame turntable and the in-game phone view of one level and scores each listed part 1-10, plus the
whole tower; the scores go into reviews/towers/review/scores.md (a "Per part" table per tower).
  python scripts/tower_rate.py [kind ...]     (default: ranger ballista storm flame frost)"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from tower_judge import codex  # noqa: E402

PARTS = {
    "ranger": ("Ranger (archer) tower", ["base and footing", "walls / stilts", "lookout and rails", "roof", "archers", "flag, banners, ivy"]),
    "ballista": ("Ballista", ["base and footing", "trestle", "stock and bolt", "bow and string", "level extras (gear, platform, bastion)", "gold and iron fittings"]),
    "storm": ("Storm Obelisk", ["base and footing", "stone / skirt", "obelisk body", "runes", "copper rings and horns", "orb / rod"]),
    "flame": ("Flame Cannon", ["base and footing", "drum / boiler", "barrel(s)", "bore and fire", "gold and bronze fittings", "hopper, chimney, windows"]),
    "frost": ("Frost Crystal", ["base and footing", "pedestal and planks", "snow and icicles", "crystals", "silver ring and arch", "banner and gems"]),
}

PROMPT = """You are a harsh, independent art director for stylised fantasy tower defence games (Kingdom Rush,
hand-painted Roblox games). Picture 1 is the concept painting of the {name}, level {level}. Picture 2 is a turntable of
our 3D model (16 views around it). Picture 3 is an in-game phone screenshot with it built (look only at that tower).
Score each part 1-10 for how well the model matches the painting and reads at phone size:
{parts}
Then score the whole tower 1-10. Answer ONLY with JSON like {{"parts": {{"<part>": n, ...}}, "whole": n,
"weakest": "<one sentence: the biggest flaw and its fix>"}}."""


def main():
    kinds = sys.argv[1:] or list(PARTS)
    out = os.path.join(ROOT, "reviews", "towers", "review", "scores.md")
    text = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
    m = re.search(r"\n## Per part \(Codex\).*", text, re.S)
    # (towers not re-rated this time keep their last table)
    kept = dict(re.findall(r"\n### (.+?)\n(.*?)(?=\n### |\Z)", m.group(0), re.S)) if m else {}
    text = text[:m.start()] if m else text
    tables = {}
    for kind in kinds:
        name, parts = PARTS[kind]
        rows = tables.setdefault(name, ["", "| level | " + " | ".join(parts) + " | whole | weakest |", "|" + "---|" * (len(parts) + 3)])
        for level in (1, 2, 3):
            imgs = [os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png"),
                    os.path.join(ROOT, "reviews", "towers", "review", f"{kind}_l{level}_turntable16.png"),
                    os.path.join(ROOT, "reviews", "towers", "review", f"{kind}_l{level}_in_game_phone.png")]
            imgs = [p for p in imgs if os.path.exists(p)]
            who, ans = codex(PROMPT.format(name=name, level=level, parts="\n".join("- " + p for p in parts)), imgs)
            m = re.search(r"\{.*\}", ans, re.S)
            try:
                d = json.loads(m.group(0))
            except Exception:
                rows.append(f"| {level} | (no score: {ans[:80]!r}) |")
                continue
            sc = [str((d.get("parts") or {}).get(p, "?")) for p in parts]
            rows.append(f"| {level} | " + " | ".join(sc) + f" | {d.get('whole', '?')} | {d.get('weakest', '')} |")
            print(kind, level, sc, d.get("whole"), flush=True)
    head = ["", "## Per part (Codex)", "", "Codex as an outside art director: painting, 16-frame turntable and phone view per level, each part 1-10."]
    for name, _ in PARTS.values():
        if name in tables:
            head += ["", f"### {name}"] + tables[name]
        elif name in kept:
            head += ["", f"### {name}", kept[name].rstrip()]
    open(out, "w", encoding="utf-8").write(text.rstrip() + "\n" + "\n".join(head) + "\n")
    print("WROTE", out)


if __name__ == "__main__":
    main()
