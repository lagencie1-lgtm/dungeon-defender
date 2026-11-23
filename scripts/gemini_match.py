"""Blind judge for the tower workflow (docs/tower-pipeline.md, gate: 8 or more): Gemini gets two pictures in random
order, A and B, without being told which is the concept painting and which is the 3D model, and rates how closely
they show the same asset (shape, parts, colours, painted detail) from 1 to 10, naming the biggest differences.
Needs the Gemini key in tools/gemini-api-key.txt. Gemini invents things: read its differences against the pictures.

Run: python scripts/gemini_match.py picture.png render.png"""
import base64
import io
import json
import os
import random
import sys
import urllib.error
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "gemini-api-key.txt")).read().strip()
MODELS = ["gemini-pro-latest", "gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash", "gemini-flash-latest"]
PROMPT = ("Picture A and picture B each show a game asset (a defense tower) on a plain background. Judge how closely they "
          "show the same asset: overall shape and proportions, every part (roof, lookout, figures, banners, plants, "
          "door, footing, ornaments), colours and the painted surface detail. Ignore the background and small "
          "differences in viewing angle or lighting. Reply as JSON: {\"score\": 1-10 (10 = the same asset, 8 = only "
          "small differences a player would not notice, 5 = clearly related but many differences), "
          "\"differences\": [the biggest differences, most important first, at most 6]}")


def png_b64(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGB", im.size, (255, 255, 255))
    bg.paste(im, (0, 0), im)
    box = bg.convert("L").point(lambda v: 255 if v < 245 else 0).getbbox()
    bg = bg.crop(box)
    bg.thumbnail((768, 768))
    buf = io.BytesIO()
    bg.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def main():
    pics = [("painting", sys.argv[1]), ("model", sys.argv[2])]
    random.shuffle(pics)
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
        except (urllib.error.HTTPError, urllib.error.URLError, KeyError, ValueError) as e:
            print(f"({model} failed: {getattr(e, 'code', e)})", file=sys.stderr)
    print("GEMINI no model answered")


if __name__ == "__main__":
    main()
