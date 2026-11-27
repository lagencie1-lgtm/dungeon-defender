"""Review of the four kit-built towers (coordinator 2026-11-24: review only, no repainting): per level the target
painting beside the model from the painting's angle with its scores (scripts/match_score.py: outline IoU, width
profile, region colour dE, detail), a 16-frame painted turntable, and the phone in-game picture from a film
(the film's "<Kind> level <n>" close shots).
  python scripts/tower_review.py <film base, tools/film/<name>-phonehq> [kinds]
Out: reviews/towers/review/<kind>_l<n>_*.png and scores.md (the scores; the gaps in words are written by hand)."""
import glob
import os
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import tower_painterly as TP  # noqa: E402

KINDS = {"flame": "FlameCannon", "frost": "FrostCrystal", "storm": "StormObelisk", "ballista": "Ballista", "ranger": "Ranger"}


def archers_extra(level):
    """HTD_EXTRA for parts_render: the Ranger level's archers from TowerService LEVEL_LOOKS (position, yaw, height)"""
    import re
    src = open(os.path.join(ROOT, "src", "server", "TowerService.luau"), encoding="utf-8").read()
    m = re.search(r'Name = "tower_ranger_l%d".*?Archers = \{(.*?)\} \},' % level, src, re.S)
    if not m:
        return ""
    model = os.path.join(ROOT, "art", "models", "ranger_archer.fbx")
    return ";".join(f"{model}|{x},{y},{z}|{yaw}|{h}" for x, y, z, yaw, h in
                    re.findall(r"Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\), ([-\d.]+), ([-\d.]+) \}", m.group(1)))


def save_safe(img, path):
    """(2026-11-25: Windows now and then refuses to open a picture for writing just after something read it, Errno 22;
    written to a new name and moved into place, with a few tries)"""
    import time
    tmp = path[:-4] + "_new.png"
    for tries in range(6):
        try:
            img.save(tmp)
            os.replace(tmp, path)
            return
        except OSError:
            time.sleep(2)
    raise OSError("could not write " + path)


def main():
    film = sys.argv[1]
    kinds = sys.argv[2:] or list(KINDS)
    out = os.path.join(ROOT, "reviews", "towers", "review")
    os.makedirs(out, exist_ok=True)
    ff = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    marks = {}
    for ln in open(film + ".marks.txt", encoding="utf-8"):
        t, _, name = ln.strip().partition("\t")
        marks.setdefault(name, float(t))
    lines = ["| Tower level | outline IoU | width profile off | region colour dE | detail ratio |", "|---|---|---|---|---|"]
    for kind in kinds:
        for level in (1, 2, 3):
            name = f"tower_{kind}_l{level}"
            fbx = os.path.join(ROOT, "art", "models", name + ".fbx")
            pic = os.path.join(ROOT, "art", "ref3d", name + ".png")
            score_png = os.path.join(out, f"{kind}_l{level}_score.png")
            s = TP.score(fbx, pic, score_png)
            txt = s[0] if s else "?"
            print(name, txt)
            parts = {k: v for k, v in (
                ("iou", txt.split("IoU ")[1].split("%")[0] if "IoU " in txt else "?"),
                ("width", txt.split("profile off ")[1].split("%")[0] if "profile off " in txt else "?"),
                ("dE", txt.split("region colour dE ")[1].split(" ")[0] if "region colour dE " in txt else "?"),
                ("detail", txt.split("(ratio ")[1].split(")")[0] if "(ratio " in txt else "?"))}
            lines.append(f"| {kind} {level} | {parts['iou']}% | {parts['width']}% | {parts['dE']} | {parts['detail']} |")
            # the labelled sheet: target painting | model (from the score's own render at the painting's angle)
            render = score_png[:-4] + "_render.png"
            a = Image.open(pic).convert("RGB")
            b = Image.open(render).convert("RGBA")
            h = 512
            a = a.resize((int(a.width * h / a.height), h))
            bg = Image.new("RGB", b.size, "white")
            bg.paste(b, (0, 0), b)
            bb = bg.resize((int(bg.width * h / bg.height), h))
            sheet = Image.new("RGB", (a.width + bb.width + 20, h + 40), "white")
            sheet.paste(a, (0, 40))
            sheet.paste(bb, (a.width + 20, 40))
            d = ImageDraw.Draw(sheet)
            d.text((6, 8), f"{name}: target painting", fill="black")
            d.text((a.width + 26, 8), "model (its paint, the painting's angle)", fill="black")
            d.text((6, 22), txt[:150], fill="black")
            save_safe(sheet, os.path.join(out, f"{kind}_l{level}_sheet.png"))
            # (2026-11-26: the Ranger's archers are their own model, placed by TowerService: drawn into the turntable)
            env = dict(os.environ, HTD_EXTRA=archers_extra(level) if kind == "ranger" else "")
            subprocess.run([sys.executable, os.path.join(HERE, "turntable16.py"), fbx, os.path.join(out, f"_{kind}_l{level}_t16"), "paint"], env=env,
                           capture_output=True)
            t16 = os.path.join(out, f"_{kind}_l{level}_t16_paint_turntable16.png")
            if os.path.exists(t16):
                os.replace(t16, os.path.join(out, f"{kind}_l{level}_turntable16.png"))
            m = f"{KINDS[kind]} level {level}"
            # (2026-11-26: the rules' own phone frame when tower_rules ran on this film: a fixed 1.2 s after the mark
            # sometimes caught the camera still zooming, and the judge saw a cropped tower)
            rules_png = os.path.join(ROOT, "tools", "rules_" + os.path.basename(film).split("-")[0], f"{KINDS[kind]}_l{level}_phone.png")
            if os.path.exists(rules_png):
                import shutil
                shutil.copyfile(rules_png, os.path.join(out, f"{kind}_l{level}_in_game_phone.png"))
            elif m in marks:
                dst = os.path.join(out, f"{kind}_l{level}_in_game_phone.png")
                tmp = os.path.join(out, "_frame.png")
                subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{marks[m] + 1.2:.2f}", "-i", film + ".mp4", "-frames:v", "1", tmp])
                # (the phone screen wherever Studio's window put it, not a fixed crop)
                from film_screen import screen_box
                import numpy as np
                with Image.open(tmp) as f:
                    im = f.convert("RGB")
                for tries in range(5):   # (Windows sometimes holds a file just written for a moment: Errno 22)
                    try:
                        im.crop(screen_box(np.asarray(im))).save(dst)
                        break
                    except OSError:
                        import time
                        time.sleep(1)
    # (2026-11-26: rows of the towers not reviewed this time, and the per-part Codex tables, stay)
    import re
    sp = os.path.join(out, "scores.md")
    old = open(sp, encoding="utf-8").read() if os.path.exists(sp) else ""
    done = {ln.split()[1] for ln in lines[2:]}
    keep = [ln for ln in old.split("\n## Per part")[0].splitlines() if re.match(r"\| [a-z]+ \d \|", ln) and ln.split()[1] not in done]
    order = ["ranger", "ballista", "storm", "flame", "frost"]
    lines[2:] = sorted(lines[2:] + keep, key=lambda ln: (order.index(ln.split()[1]) if ln.split()[1] in order else 9, ln))
    tail = old[old.index("\n## Per part"):] if "\n## Per part" in old else ""
    open(sp, "w", encoding="utf-8").write("\n".join(lines) + "\n" + tail)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
