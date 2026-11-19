"""Makes the painted material set the 3D models are textured with (Codex image generation, the owner's
ChatGPT login). Every texture is a seamless square tile in one hand-painted style, so all models share one look.
Blender bakes these onto each model (art/blender/paint.py).
Run:  python art/make_textures.py            (all missing)
      python art/make_textures.py wood stone (only these)
"""
import os
import subprocess
import sys

from make_icons import find_codex

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "textures")

STYLE = ("Seamless tileable hand-painted stylized game texture, top-down flat view filling the whole square, "
         "warm friendly fantasy style like a painted cartoon adventure game: chunky readable shapes, soft painterly "
         "brush strokes, gentle light from the top-left baked into each shape, clear dark outlines between pieces, "
         "no perspective, no lighting gradient across the image, no text, no border, edges must tile seamlessly. "
         "Material: ")

TEXTURES = {
    "wood": "vertical wooden planks, warm honey brown with darker grain lines and a few knots, palette #46301E to #B07A44",
    "wood_dark": "dark weathered wooden beams, deep brown with subtle grain, palette #2E1E12 to #6B4A2E",
    "stone": "fitted grey-beige castle stone blocks of varied sizes with mortar lines, palette #6E6A66 to #C9C0B0",
    "roof": "overlapping rounded roof shingles in muted forest green rows, palette #2F4A2A to #7FA35A",
    "brass": "hammered brass metal with soft highlights and small rivets, palette #7A5A22 to #F0D080",
    "iron": "dark riveted iron plates, slightly bluish grey, palette #2A2C33 to #7C808C",
    "cloth": "smooth soft cream canvas fabric with a very fine subtle weave and gentle painted folds, mostly plain, palette #A8987A to #F3E6C8",
    "basalt": "dark volcanic basalt rock with cracked facets and warm reddish tint, palette #2A2020 to #7A6058",
    "lava_rock": "black volcanic rock with glowing orange lava cracks between plates, palette #1A1010, #FF7A20, #FFD060",
    "ice": "pale blue ice crystal with clean facets and white highlights, palette #4A8ACF to #E6F6FF",
    # terrain (painted looks for the Roblox terrain materials, so maps match the models)
    "t_ground": "packed warm brown dirt path with small pebbles and worn tracks, palette #6E4A30 to #C89060",
    "t_cobble": "rounded cobblestones of mixed sizes set in dark soil, warm grey, palette #4A4440 to #A89C90",
    "t_ash": "grey volcanic ash ground with small dark stones and faint cracks, palette #4A4240 to #9A8E88",
    "t_cliff": "rough layered volcanic cliff rock with big chunky angular facets, reddish brown, palette #3A2622 to #8A5E4E",
    # Cursed Forest
    "t_grass": "short dense meadow grass with small clover and tiny flowers, muted dusky green, palette #2E4A2A to #7A9A50",
    "t_forest_dirt": "dark forest floor soil with fallen leaves and twigs, palette #3A2A1E to #8A6A44",
    "t_moss_rock": "grey boulder rock with patches of soft green moss, palette #4A4E48 to #8A9A70",
    "bark": "rough twisted tree bark with deep vertical grooves, dark brown, palette #2E2018 to #6E5038",
    "leaves": "dense clustered tree leaves canopy, deep green with lighter tips, palette #1E3A22 to #6A9A48",
    "rune_stone": "dark purple-grey carved stone with faint engraved rune lines, palette #2E2838 to #7A6E8E",
}


def main():
    os.makedirs(OUT, exist_ok=True)
    codex = find_codex()
    wanted = sys.argv[1:] or list(TEXTURES)
    for name in wanted:
        target = os.path.join(OUT, name + ".png")
        if os.path.exists(target):
            print("have", name)
            continue
        prompt = (STYLE + TEXTURES[name] + f". Use your image generation tool, square format, and save the image as "
                  f"{name}.png in the current folder. Reply only with the file path.")
        try:
            subprocess.run([codex, "exec", "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                           cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        except subprocess.TimeoutExpired:
            pass
        print("made" if os.path.exists(target) else "FAILED", name, flush=True)


if __name__ == "__main__":
    main()
