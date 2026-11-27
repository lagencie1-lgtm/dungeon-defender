"""Benchmark the defenders' shots (coordinator 2026-11-27): Gemini watches a top Roblox tower defense game's tower-shot
footage on YouTube (video only; their pictures never go into git) and, separately, our own shot clips, and answers the
same questions with numbers: projectile size and contrast, trail, wind-up length, muzzle flash, hit reaction, sound.
  python scripts/shot_bench.py "Game" https://www.youtube.com/watch?v=...    -> tools/shotbench/<game>.md (not in git)
  python scripts/shot_bench.py --ours reviews/towers/shots/<tower>_l3.mp4 ...
Needs the Gemini key in tools/gemini-api-key.txt. Gemini invents things: check claims against frames."""
import base64
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from yt_review import call  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "shotbench")

PROMPT = """You are a harsh animation and VFX director for Roblox tower defense games, judging how tower SHOTS read on a
phone screen. Watch {what}. Judge only what is visible; write "not visible" rather than guess; give timestamps.
For up to 6 different towers you can see shooting, answer with numbers where you can estimate them:
1. Projectile: what it is; its size on screen (as a share of the tower's height); contrast against the ground
   (bright on dark, outline, glow); colour.
2. Trail or streak behind it: yes/no, length (as a share of the shot distance), how long it lingers (seconds).
3. Wind-up / anticipation before the shot: what moves, how long (seconds or frames), is the pose held?
4. Release: muzzle flash (size vs barrel, duration), recoil (how far, how long to settle).
5. Flight time (seconds) and whether it arcs.
6. Hit reaction: what the enemy does (flash, knockback distance, stagger), the impact effect size vs the enemy, hit-stop.
7. Sound timing if audible.
Then: the 5 most important reasons these shots read clearly on a phone, each with a number a developer could copy.
Plain English, under 600 words."""


def main():
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1] == "--ours":
        for clip in sys.argv[2:]:
            media = {"inline_data": {"mime_type": "video/mp4", "data": base64.b64encode(open(clip, "rb").read()).decode()}}
            model, text = call([media, {"text": PROMPT.format(what="this clip of our own game (filmed in Roblox Studio at phone size, one tower shooting)")}])
            name = "ours-" + os.path.splitext(os.path.basename(clip))[0]
            open(os.path.join(OUT, name + ".md"), "w", encoding="utf-8").write(f"# ours: {clip}\n\n(Gemini {model})\n\n{text}\n")
            print(name, "done")
    else:
        game, url = sys.argv[1], sys.argv[2]
        model, text = call([{"file_data": {"file_uri": url, "mime_type": "video/*"}}, {"text": PROMPT.format(what=f"this video of the Roblox game \"{game}\"")}])
        name = re.sub(r"[^a-z0-9]+", "-", game.lower()).strip("-")
        open(os.path.join(OUT, name + ".md"), "w", encoding="utf-8").write(f"# {game}\n\nSource: {url} (Gemini {model})\n\n{text}\n")
        print(text)


if __name__ == "__main__":
    main()
