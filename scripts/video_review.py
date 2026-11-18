"""Films the running test game (the Studio window of scripts/autotest.sh) with ffmpeg and asks Gemini to review
the clip against the 6A bar. Findings are written to reviews/<time>.md. AI reviewers are noisy: read the claims,
check each one against the frames before fixing anything (6A principle 19).

Needs the Gemini API key in tools/gemini-api-key.txt (from aistudio.google.com).
Run while the test game is running:
  python scripts/video_review.py 40                 film 40 s now, then review
  python scripts/video_review.py --file clip.mp4     review an existing clip
"""
import base64
import datetime
import glob
import json
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "gemini-api-key.txt")
OUT_DIR = os.path.join(ROOT, "reviews")
MODEL = "gemini-2.5-pro"
WINDOW = os.path.join(ROOT, "tools", "htd-autotest.rbxl") + " - Roblox Studio"

PROMPT = """You are a harsh, independent game reviewer. You never saw the design intent. The owner thinks parts of
this game reek of AI slop. This clip is a Roblox co-op tower defense game ("Heroes Tower Defense") filmed from a
Roblox Studio play test window: judge only the game viewport, ignore Studio's own toolbars and panels.

The bar is "6A": exceptional clarity, responsiveness, tactile animation, cohesive art and reliable performance,
judged on a phone by a 9-13 year old in the first minutes. Score each axis 0-10 and pass only if every axis is 9+:
- Clarity: does a kid know what to do and what just happened, without reading?
- Feel: do actions answer instantly; does motion have weight, anticipation and settle; nothing snaps or floats?
- Tactile animation: do bodies push, lean, squash; does anything stand still while things move for it?
- Art: one art direction, a landmark, every object placed for a reason; nothing generic or copy-pasted?
- VFX / juice: are effects rare, short, readable and away from where the player aims; do rewards travel to their counter?
- UI / UX: face up, no clutter, one banner at a time, nothing covering the hero or the action?
- Polish / perf: any flicker, hitch, clipping, z-fighting, popping, unreadable dark areas?

Then list the gaps, worst first, as: [mm:ss] what you see -> why it fails the bar -> a concrete fix (with numbers
where possible). Only claim what is visible in the clip; say "not visible" rather than guess. Keep it under 400 words.
Answer in plain English."""


def record(seconds, out):
    ffmpeg = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-f", "gdigrab", "-framerate", "30", "-i", "title=" + WINDOW,
                    "-t", str(seconds), "-vf", "scale=-2:720", "-c:v", "libx264", "-preset", "veryfast", "-crf", "28",
                    "-pix_fmt", "yuv420p", out], check=True)


def review(video):
    key = open(KEY_FILE).read().strip()
    data = base64.b64encode(open(video, "rb").read()).decode()
    body = {"contents": [{"parts": [{"inline_data": {"mime_type": "video/mp4", "data": data}}, {"text": PROMPT}]}],
            "generationConfig": {"temperature": 0.2}}
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(), method="POST",
        headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=600) as r:
        result = json.loads(r.read())
    parts = result["candidates"][0]["content"]["parts"]
    return "".join(p.get("text", "") for p in parts)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M")
    if "--file" in sys.argv:
        video = sys.argv[sys.argv.index("--file") + 1]
    else:
        seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 40
        video = os.path.join(ROOT, "tools", f"clip-{stamp}.mp4")
        record(seconds, video)
        print("filmed", video)
    text = review(video)
    out = os.path.join(OUT_DIR, f"{stamp}.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"# Gemini 6A review {stamp}\n\nClip: `{os.path.basename(video)}` (model {MODEL})\n\n{text}\n")
    print("review", out)
    print(text)


if __name__ == "__main__":
    main()
