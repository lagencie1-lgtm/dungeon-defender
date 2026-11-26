"""Blind judge for the tower workflow (docs/tower-pipeline.md, gate: 8 or more): Gemini gets two pictures in random
order, A and B, without being told which is the concept painting and which is the 3D model, and rates how closely
they show the same asset (shape, parts, colours, painted detail) from 1 to 10, naming the biggest differences.
Needs the Gemini key in tools/gemini-api-key.txt. Gemini invents things: read its differences against the pictures.
HTD_JUDGE=codex asks Codex instead (the owner's logged-in Codex CLI, free; it shares its limit with the painting, so use
it sparingly and never while another thread paints): the same rubric and the same two pictures, run in an empty folder
outside the project with a read-only sandbox, so it knows nothing about our work.

Run: python scripts/gemini_match.py picture.png render.png      (HTD_JUDGE=codex python ... for the Codex judge)"""
import base64
import io
import json
import os
import glob
import random
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = ["gemini-pro-latest", "gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash", "gemini-flash-latest"]
PROMPT = ("Picture A and picture B each show a game asset (" + os.environ.get("HTD_SUBJECT", "a defense tower") + ") on a plain background. Judge how closely they "
          "show the same asset: overall shape and proportions, every part (roof, lookout, figures, banners, plants, "
          "door, footing, ornaments), colours and the painted surface detail. Ignore the background and small "
          "differences in viewing angle or lighting" + os.environ.get("HTD_EXTRA", "") + ". Reply as JSON: {\"score\": 1-10 (10 = the same asset, 8 = only "
          "small differences a player would not notice, 5 = clearly related but many differences), "
          "\"differences\": [the biggest differences, most important first, at most 6]}")


def prepared(path):
    """the picture as the judge sees it: on white, cropped to the asset, at most 768 px"""
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGB", im.size, (255, 255, 255))
    bg.paste(im, (0, 0), im)
    box = bg.convert("L").point(lambda v: 255 if v < 245 else 0).getbbox()
    bg = bg.crop(box)
    bg.thumbnail((768, 768))
    return bg


def png_b64(path):
    buf = io.BytesIO()
    bg = prepared(path)
    bg.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def codex_judge(pics):
    """the same rubric for Codex: the two pictures as files A.png and B.png in an empty folder"""
    exe = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    if not exe:
        print("CODEX not found (the ChatGPT VS Code extension)")
        return
    cmd = [exe[-1], "exec", "--skip-git-repo-check", "--sandbox", "read-only"]
    model = "default"
    try:   # (the owner's default model is not always served on a ChatGPT login; scripts/tower_paint.py picks the same)
        models = json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])
        slugs = [m["slug"] for m in models if m["slug"].startswith("gpt-") and "reserve" not in m["slug"]]
        model = next((m for m in slugs if "terra" in m), slugs[0] if slugs else "default")
        if model != "default":
            cmd += ["-m", model]
    except (OSError, ValueError):
        pass
    folder = tempfile.mkdtemp(prefix="judge_")
    try:
        files = []
        for letter, (_, path) in zip("AB", pics):
            f = os.path.join(folder, letter + ".png")
            prepared(path).save(f)
            files += ["-i", f]
        prompt = ("The first attached image is picture A, the second is picture B. " + PROMPT
                  + " Reply with only that JSON, nothing else.")
        r = subprocess.run(cmd + [prompt] + files, cwd=folder, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                           encoding="utf-8", errors="ignore", timeout=600)
        found = re.findall(r'\{[^{}]*"score"[^{}]*\}', r.stdout or "", re.S)
        if not found:
            print("CODEX no answer: " + ((r.stdout or "") + (r.stderr or ""))[-300:].replace("\n", " "))
            return
        verdict = json.loads(found[-1])
    except (subprocess.TimeoutExpired, ValueError, OSError) as e:
        print(f"CODEX failed: {e}")
        return
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    names = {"A": pics[0][0], "B": pics[1][0]}
    print(f"CODEX {model}: score {verdict.get('score')} (A was the {names['A']})")
    for d in verdict.get("differences", []):
        print("  - " + str(d).replace("Picture A", names["A"]).replace("Picture B", names["B"]))


def main():
    pics = [("painting", sys.argv[1]), ("model", sys.argv[2])]
    random.shuffle(pics)
    if os.environ.get("HTD_JUDGE", "gemini") == "codex":
        codex_judge(pics)
        return
    KEY = open(os.path.join(ROOT, "tools", "gemini-api-key.txt")).read().strip()
    parts = [{"text": "Picture A:"}, {"inline_data": {"mime_type": "image/png", "data": png_b64(pics[0][1])}},
             {"text": "Picture B:"}, {"inline_data": {"mime_type": "image/png", "data": png_b64(pics[1][1])}},
             {"text": PROMPT}]
    body = json.dumps({"contents": [{"parts": parts}], "generationConfig": {"responseMimeType": "application/json"}}).encode()
    for model in MODELS:
        try:
            req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                                         data=body, headers={"Content-Type": "application/json", "x-goog-api-key": KEY})
            with urllib.request.urlopen(req, timeout=180) as r:
                out = json.loads(r.read())
            text = out["candidates"][0]["content"]["parts"][0]["text"]
            verdict = json.loads(text)
            names = {"A": pics[0][0], "B": pics[1][0]}
            diffs = [d.replace("Picture A", names["A"]).replace("Picture B", names["B"]) for d in verdict.get("differences", [])]
            print(f"GEMINI {model}: score {verdict.get('score')} (A was the {names['A']})")
            for d in diffs:
                print("  - " + d)
            return
        except (urllib.error.HTTPError, urllib.error.URLError, KeyError, ValueError, TimeoutError, OSError) as e:
            print(f"({model} failed: {getattr(e, 'code', e)})", file=sys.stderr)
    print("GEMINI no model answered")


if __name__ == "__main__":
    main()
