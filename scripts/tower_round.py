"""Logs one round of the tower workflow (docs/tower-pipeline.md): renders the model from the picture's angle and from
four sides, scores it against the picture (scripts/match_score.py) and writes
  reviews/towers/<kind>_l<level>/round_XX.png          picture | model | outline diff, the four sides, the numbers
  reviews/towers/<kind>_l<level>/round_XX_flicker.gif  picture and model flipping in one frame
  reviews/towers/<kind>_l<level>/rounds.md             one line per round: what changed and the numbers

Run: python scripts/tower_round.py <kind> <level> <round> model.fbx "what changed this round"
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore")
    return r.stdout


def main():
    kind, level, rnd, fbx = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), os.path.abspath(sys.argv[4])
    note = sys.argv[5] if len(sys.argv) > 5 else ""
    folder = os.path.join(ROOT, "reviews", "towers", f"{kind}_l{level}")
    os.makedirs(folder, exist_ok=True)
    picture = os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png")
    stem = os.path.join(folder, f"round_{rnd:02d}")
    render = stem + "_render.png"
    run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", fbx, render, "-75", "15", "512"])
    out = run([sys.executable, os.path.join(ROOT, "scripts", "match_score.py"), picture, render, stem + "_match.png"]).splitlines()
    around = stem + "_around.png"
    for k, az in enumerate((-75, 15, 105, -165)):
        run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "parts_render.py"), "--", fbx, around[:-4] + f"_{k}.png",
             str(az), "15", "300", "persp", "lit"])
    match = Image.open(stem + "_match.png")
    sides = [Image.open(around[:-4] + f"_{k}.png").convert("RGBA") for k in range(4) if os.path.exists(around[:-4] + f"_{k}.png")]
    w = max(match.size[0], 300 * len(sides))
    sheet = Image.new("RGB", (w, 60 + match.size[1] + 300), (255, 255, 255))
    sheet.paste(match, (0, 60))
    for k, s in enumerate(sides):
        bg = Image.new("RGB", s.size, (235, 235, 235))
        bg.paste(s, (0, 0), s)
        sheet.paste(bg.resize((300, 300)), (k * 300, 60 + match.size[1]))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    d.text((8, 4), f"{kind} level {level}, round {rnd}: {note}", fill=(20, 20, 20), font=font)
    d.text((8, 22), out[0] if out else "no score", fill=(20, 20, 20), font=font)
    d.text((8, 40), out[1] if len(out) > 1 else "", fill=(60, 60, 60), font=font)
    sheet.save(stem + ".png")
    for k in range(4):
        p = around[:-4] + f"_{k}.png"
        if os.path.exists(p):
            os.remove(p)
    for p in (render, stem + "_match.png"):
        if os.path.exists(p):
            os.remove(p)
    with open(os.path.join(folder, "rounds.md"), "a", encoding="utf-8") as log:
        log.write(f"- round {rnd}: {note}\n  {out[0] if out else ''}\n  {out[1] if len(out) > 1 else ''}\n")
    print(stem + ".png")
    print("\n".join(out))


if __name__ == "__main__":
    main()
