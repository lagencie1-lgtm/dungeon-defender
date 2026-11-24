"""Paints the hero ability icons (the round buttons in a run) with Codex, in the same house style as
art/make_icons.py. Output: art/icons/ab_<name>.png. Skips icons that already exist.
Run: python art/make_ability_icons.py [names]
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "icons")

STYLE = ("Painted fantasy game icon in a warm, friendly style for kids: soft painterly shading, bold readable "
         "silhouette, light from the top-left with a gentle rim light, palette of dark wood (#46301E), brass "
         "(#D6AA50) and cream (#F3E6C8) with one accent colour. One object or one simple action shape, centered, "
         "filling about 80% of a square canvas, fully transparent background, no text, no numbers, no frame, no border, "
         "no shadow box. It must read clearly at 40 pixels inside a round button. Subject: ")

ICONS = {
    "ab_sword": "a knight's sword mid-swing with a short bright arc behind the blade",
    "ab_whirl": "a sword spinning in a circle, a curved swoosh ring around it, accent pale blue",
    "ab_leap": "a leather boot jumping up with three short speed lines below it",
    "ab_bolt": "a small crackling magic bolt of violet energy, accent violet (#AA96FF)",
    "ab_nova": "a round burst of violet magic rings spreading out from a bright centre",
    "ab_meteor": "a flaming meteor rock falling diagonally with a fire tail, accent fire orange",
    "ab_wrench": "a brass wrench, accent gold",
    "ab_overclock": "a brass gear with a glowing orange lightning bolt in its middle",
    "ab_turret": "a tiny brass gun turret on a tripod",
    "ab_shot": "a single arrow flying right with a feather tail, accent nature green",
    "ab_net": "a rope hunting net thrown open, accent nature green",
    "ab_wolf": "the head of a friendly grey wolf companion, accent nature green",
}


def codex():
    found = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    if not found:
        sys.exit("Codex not found (needs the ChatGPT extension in VS Code, logged in)")
    models = json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])
    model = next((m["slug"] for m in models if m["slug"].startswith("gpt-") and "reserve" not in m["slug"]), "gpt-6.1-terra")
    return found[-1], model


def main():
    exe, model = codex()
    for name in sys.argv[1:] or list(ICONS):
        target = os.path.join(OUT, name + ".png")
        if os.path.exists(target):
            continue
        started = time.time()
        prompt = (STYLE + ICONS[name] + f". Use your image generation tool and save the image as {name}.png in the "
                  "current folder. Reply only with the file path.")
        try:
            subprocess.run([exe, "exec", "-m", model, "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                           cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        except subprocess.TimeoutExpired:
            pass
        if not os.path.exists(target):
            made = [p for p in glob.glob(os.path.expanduser("~/.codex/generated_images/*/*.png")) if os.path.getmtime(p) > started]
            if made:
                shutil.copy(max(made, key=os.path.getmtime), target)
        print("made" if os.path.exists(target) else "FAILED", name, flush=True)


if __name__ == "__main__":
    main()
