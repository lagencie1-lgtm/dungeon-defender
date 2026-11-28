"""Paints the level sheets of the defenders with Codex (docs/tower-pipeline.md): one wide picture per tower with its
three levels side by side as one family, then cuts it into art/ref3d/tower_<kind>_l1..l3.png (ready for Tripo).
Run: python art/make_tower_sheets.py [kind ...]      kinds: flame frost storm ballista barricade
(the Oak Barricade stands on the path and has four looks: level 1, level 2 and the two level 3 branches)
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ref3d")
ROOT = os.path.dirname(HERE)

STYLE = ("Painted fantasy game art for a friendly kids' tower defense game: soft painterly shading, bold readable "
         "silhouettes, chunky proportions, light from the top-left, palette dark wood #46301E, brass #D6AA50, cream "
         "#F3E6C8, warm pale stone, plus the accent below. Not photo-real. One wide image, plain pure white background, "
         "no text. Three versions of the same defense tower standing side by side, left to right, growing with each "
         "upgrade level, same scale and same three-quarter view from slightly above, clearly one family, each on a round "
         "cut-stone footing with a little grass. ")

SHEETS = {
    "flame": "Accent fire orange #FF7A2A. LEFT (level 1): a squat iron mortar on a stone ring. MIDDLE (level 2): a bigger "
             "bronze cannon with a coal hopper and brass bands. RIGHT (level 3): twin barrels on a turning brass turret, "
             "glowing orange vents, a small chimney.",
    "frost": "Accent ice blue #8CD2FF. LEFT (level 1): one tall ice shard on a frosted stone. MIDDLE (level 2): a crystal "
             "cluster with a silver ring around its base. RIGHT (level 3): a tall crown of ice crystals around a floating "
             "glowing core, silver filigree.",
    "storm": "Accent storm violet #9678FF. LEFT (level 1): a short carved rune stone. MIDDLE (level 2): a carved slate "
             "obelisk with a copper lightning rod. RIGHT (level 3): a tall obelisk with copper coils and a floating "
             "crackling violet orb on top.",
    "ballista": "Accent crimson #B4323C. LEFT (level 1): a light wooden ballista on a simple stand. MIDDLE (level 2): a "
                "heavier ballista with iron arms and a crank. RIGHT (level 3): a double ballista on a small stone "
                "bastion with crimson banners and brass fittings.",
}
# the Oak Barricade: four looks on one sheet, on the road instead of a stone footing (art/blender/tower_barricade_detail.py)
OWN_STYLE = {
    "barricade": ("Painted fantasy game art for a friendly kids' tower defense game: soft painterly shading, bold "
                  "readable silhouettes, chunky proportions, light from the top-left, palette dark wood #46301E, brass "
                  "#D6AA50, cream #F3E6C8, oak brown and moss green. Not photo-real. One wide image, plain pure white "
                  "background, no text. Four versions of the same wooden barricade that blocks a road, standing side by "
                  "side with clear white gaps, left to right, same scale and same three-quarter view from slightly "
                  "above, the side the enemies come from facing the viewer, clearly one family, each standing on a short "
                  "strip of packed dirt road. "),
}
SHEETS["barricade"] = ("1 (level 1): a low wall of three stacked oak logs held by two pairs of posts with sharpened tops, "
                       "tied with rope. 2 (level 2): taller, four logs, thicker posts with iron bands and brass rivets, a "
                       "round wooden shield with a brass rim and boss in the middle. 3 (Thornwall): the level 2 wall with "
                       "two rows of long sharpened stakes dug in at its foot pointing out and up toward the viewer, the "
                       "points fire-hardened red-brown, wooden braces behind. 4 (Rootwall): the level 2 wall overgrown by "
                       "thick living tree roots that climb over the logs and spread over the road in front and behind, "
                       "moss on top and a small leafy sapling growing from it. The Thornwall reads as spikes pointing "
                       "out, the Rootwall as roots on the ground.")
PARTS = {"barricade": "l1,l2,thorn,root"}


def codex():
    found = sorted(glob.glob(os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")))
    models = json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])
    model = next((m["slug"] for m in models if m["slug"].startswith("gpt-") and "reserve" not in m["slug"]), "gpt-6.1-terra")
    return found[-1], model


def main():
    exe, model = codex()
    for kind in sys.argv[1:] or list(SHEETS):
        name = f"tower_{kind}_sheet"
        target = os.path.join(OUT, name + ".png")
        if not os.path.exists(target):
            started = time.time()
            prompt = (OWN_STYLE.get(kind, STYLE) + SHEETS[kind] + f" Use your image generation tool and save the image as {name}.png in the "
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
        if os.path.exists(target):
            if kind in PARTS:
                subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "split_sheet.py"), target,
                                os.path.join(OUT, f"tower_{kind}_N.png"), PARTS[kind]])
            else:
                subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "split_sheet.py"), target,
                                os.path.join(OUT, f"tower_{kind}_lN.png")])
        print("made" if os.path.exists(target) else "FAILED", kind, flush=True)


if __name__ == "__main__":
    main()
