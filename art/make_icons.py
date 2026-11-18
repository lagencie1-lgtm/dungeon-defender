"""Makes the game's painted icon set with Codex image generation (the owner's ChatGPT login),
all with the same style prefix from art/STYLE.md. Skips icons that already exist.
Run:  python art/make_icons.py            (all)
      python art/make_icons.py shop gem   (only these)
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "icons")

STYLE = ("Painted fantasy game icon in a warm, friendly style for kids: soft painterly shading, bold readable "
         "silhouette, light from the top-left with a gentle rim light, palette of dark wood (#46301E), brass "
         "(#D6AA50) and cream (#F3E6C8) with one accent colour. One object, centered, 3/4 front view, filling about "
         "80% of a square canvas, fully transparent background, no text, no numbers, no frame, no border, no shadow box. "
         "It must read clearly at 48 pixels. Subject: ")

ICONS = {
    # side menu
    "shop": "a small merchant's coin pouch tied with brass string, a few coins peeking out, accent gold yellow",
    "daily": "a wrapped gift box with a cream ribbon and brass corners, accent nature green",
    "backpack": "an adventurer's leather backpack with brass buckles and a rolled blanket on top",
    "heroes": "two crossed swords in front of a round wooden shield with a brass rim",
    "quests": "a rolled parchment scroll with a red wax seal",
    "pets": "a speckled creature egg in a little straw nest, accent nature green",
    "season": "a brass trophy cup with two handles on a small wooden base",
    # currencies and states
    "gem": "a single faceted gem crystal, accent cyan (#5ADCFF), small sparkle",
    "gold": "a small stack of three gold coins, accent gold yellow",
    "mana": "a glowing round mana orb in a brass holder, accent violet (#AA96FF)",
    "scrap": "a small pile of bent metal scraps, gears and bolts",
    "lock": "a sturdy brass padlock",
    # defenders
    "tower_ranger": "a wooden archer watchtower with a green hooded archer on top, accent nature green",
    "tower_flame": "a stout iron cannon on a stone base with a fiery glowing muzzle, accent fire orange",
    "tower_frost": "a tall pale-blue ice crystal on a frosty stone base, accent frost blue",
    "tower_storm": "a dark stone obelisk with a crackling purple orb on top, accent storm purple",
    "tower_ballista": "a wooden ballista loaded with a big bolt, brass fittings",
    # heroes (original characters, chunky friendly proportions)
    "hero_swordmaster": "portrait bust of a brave young sword hero with short hair, blue tunic and a brass pauldron, holding a sword",
    "hero_hunter": "portrait bust of a cheerful beast hunter with a hooded green cloak and a bow, a wolf pup peeking beside them",
    "hero_mage": "portrait bust of a young rune mage with a tall purple pointed hat and a glowing staff, accent violet",
    "hero_engineer": "portrait bust of a smiling engineer with goggles on the forehead, orange overalls and a big wrench",
}


def find_codex():
    pattern = os.path.expandvars(r"%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe")
    found = sorted(glob.glob(pattern))
    if not found:
        sys.exit("Codex not found (needs the ChatGPT extension in VS Code, logged in)")
    return found[-1]


def main():
    os.makedirs(OUT, exist_ok=True)
    codex = find_codex()
    wanted = sys.argv[1:] or list(ICONS)
    for name in wanted:
        target = os.path.join(OUT, name + ".png")
        if os.path.exists(target):
            print("have", name)
            continue
        prompt = (STYLE + ICONS[name] + f". Use your image generation tool and save the image as {name}.png in the "
                  "current folder. Reply only with the file path.")
        subprocess.run([codex, "exec", "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                       cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=600)
        print("made" if os.path.exists(target) else "FAILED", name, flush=True)


if __name__ == "__main__":
    main()
