"""Asks Gemini to watch a public YouTube video (lobby tour / first minutes of a Roblox game) and describe its hub
the same way we review our own game, so the ratings are comparable (reviews/hub/benchmark.md).

  python scripts/yt_review.py "Game name" https://www.youtube.com/watch?v=...   -> reviews/hub/bench/<game>.md
  python scripts/yt_review.py --ours clip.mp4                                   -> same questions for our own clip

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
OUT = os.path.join(ROOT, "reviews", "hub", "bench")
MODELS = ["gemini-pro-latest", "gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash", "gemini-flash-latest"]

PROMPT = """You are a harsh, experienced Roblox game reviewer. This video shows the Roblox game "{game}". Judge only
what is visible in the video; write "not visible" rather than guess. Give timestamps [mm:ss] for every claim.

Part A - the lobby / hub (the place players stand in before a match):
1. Layout and size: shape, how many studs/steps across it feels, how compact; what surrounds it (walls, cliffs, skyline).
2. What a player sees right after spawning (first 5 seconds).
3. The landmark: the one thing you would name to a friend.
4. How a match is started: walk-in pads, elevators, portals, queue rooms, a menu teleport? How are maps named and how
   is party size shown?
5. Stations (shop, summon, quests, rewards, leaderboard...): how are they signed (big icons, text boards, NPCs, rings
   on the ground, prompts)?
6. Lighting and colour: time of day, brightness, saturation, palette.
7. Life: NPCs, moving things, particles, other players, sound if audible.
8. HUD layout as it would sit on a phone: where buttons are, how big, how many; any gamepad/console hints visible.

Part B - if the video also shows a match: towers (look, size, placement feel, how they sit on the ground), monsters
(look, readability, do they walk on the ground), the map, effects.

Part C - rate 1-10, harshly, against the best Roblox games of 2026, one line of reason each:
hub, towers, monsters, map, UI, mobile/console UX, effects. Write "n/a" where the video shows nothing for an axis.

Part D - the 5 things this game's hub does best that a small new tower defense game should copy (concrete, with
numbers or sizes where you can estimate them).

Plain English, under 700 words."""


def call(parts):
    body = {"contents": [{"parts": parts}], "generationConfig": {"temperature": 0.2}}
    last = None
    for attempt in range(3):
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
                last = f"{model}: {e.code} {e.read()[:300]!r}"
            except Exception as e:
                last = f"{model}: {e}"
            print("failed:", last, file=sys.stderr)
        time.sleep(30)
    raise RuntimeError(last)


def main():
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1] == "--ours":
        clip = sys.argv[2]
        game = "Heroes Tower Defense (ours, filmed in Roblox Studio at phone size)"
        media = {"inline_data": {"mime_type": "video/mp4", "data": base64.b64encode(open(clip, "rb").read()).decode()}}
        name, src = "ours-" + os.path.splitext(os.path.basename(clip))[0], clip
    else:
        game, src = sys.argv[1], sys.argv[2]
        media = {"file_data": {"file_uri": src, "mime_type": "video/*"}}
        name = re.sub(r"[^a-z0-9]+", "-", game.lower()).strip("-")
    model, text = call([media, {"text": PROMPT.format(game=game)}])
    path = os.path.join(OUT, name + ".md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"# {game}\n\nSource: {src} (Gemini model {model})\n\n{text}\n")
    print(path)
    print(text)


if __name__ == "__main__":
    main()
