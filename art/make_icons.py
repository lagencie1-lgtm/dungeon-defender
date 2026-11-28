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
    "tower_barricade": "a short square wall of stacked oak logs between two thick wooden posts with iron bands and "
                       "sharpened pencil tops, a round wooden shield with a polished brass rim and boss in the middle "
                       "(the Oak Barricade's level 2 look), accent oak brown",
    # gear (the picture of each item kind; its rarity shows as the frame colour)
    "item_longsword": "a straight knightly longsword with a brass crossguard and leather grip, blade pointing up-right",
    "item_greatsword": "a huge heavy two-handed greatsword with a wide blade and a big brass pommel, blade pointing up-right",
    "item_twinblades": "two short curved twin blades crossed over each other, brass hilts",
    "item_helm": "a steel knight's helm with a visor slit and brass trim",
    "item_hood": "a soft leather adventurer's hood with a brass clasp",
    "item_crown": "a golden crown with three points and small red gems",
    "item_chestplate": "a steel chestplate with brass edges and leather straps",
    "item_tunic": "a padded cloth tunic in forest green with a leather belt, accent nature green",
    "item_mail": "a chainmail shirt with a brass collar",
    "item_boots": "a pair of sturdy leather boots with brass buckles",
    "item_sandals": "a pair of leather sandals with wrapped straps",
    "item_greaves": "a pair of steel leg greaves with brass knee caps",
    "item_amulet": "a brass amulet on a chain with a glowing blue gem, accent cyan",
    "item_ring": "a golden ring with a bright green gem, accent nature green",
    "item_charm": "a lucky charm: a small carved wooden token on a red string with a brass bead",
    "chest_open": "an open treasure chest of dark wood and brass with golden light shining out of it, accent gold yellow",
    # rewards (season pass, daily reward, quests)
    "reward_gems_small": "three small faceted gem crystals lying together, accent cyan (#5ADCFF), small sparkles",
    "reward_gems_big": "a big heap of many faceted gem crystals spilling out of a small wooden chest, accent cyan (#5ADCFF), sparkles",
    "reward_gold_small": "a small neat stack of gold coins with two coins lying beside it, accent gold yellow",
    "reward_gold_big": "a bulging leather sack overflowing with gold coins, accent gold yellow",
    "reward_cape": "a flowing hero's cape on a brass shoulder clasp, the cloth plain pure white with soft grey folds (it gets coloured later), no pattern",
    "reward_title": "a golden medal with a star on a wide red ribbon, accent gold yellow",
    # pets (original cute creatures: big head, big shiny eyes, tiny body) and their eggs
    "pet_slimey": "a cute smiling green slime blob pet with big shiny eyes, accent nature green",
    "pet_leafling": "a cute little sprout creature pet, round green body with a big leaf on its head and big shiny eyes, accent nature green",
    "pet_stonepup": "a cute puppy pet made of grey stone with mossy patches, floppy rock ears and big shiny eyes",
    "pet_mosskitten": "a cute fluffy kitten pet with soft green moss fur on its back and a tiny flower on its head, big shiny eyes, accent nature green",
    "pet_glowbug": "a cute chubby firefly pet with a glowing yellow tail and little wings, big shiny eyes, accent gold yellow",
    "pet_emberfox": "a cute baby fox pet with orange fur and a flame-tipped fluffy tail, big shiny eyes, accent fire orange",
    "pet_minigolem": "a cute tiny rock golem pet with a glowing orange core in its chest and big shiny eyes, accent fire orange",
    "pet_babydragon": "a cute chubby baby dragon pet with purple scales, tiny wings and little golden horns, big shiny eyes, accent storm purple",
    "pet_crystalowl": "a cute round owl pet with pale blue crystal feathers and big shiny eyes, accent frost blue",
    "pet_starunicorn": "a cute chubby baby unicorn pet with a white coat, a pastel rainbow mane and a glowing golden horn, big shiny eyes, sparkles",
    "pet_phoenix": "a cute baby phoenix chick pet with blazing red-gold feathers and a fiery tail, big shiny eyes, accent fire orange, sparkles",
    "pet_voiddrake": "a cute baby dragon pet made of dark night-sky scales with glowing violet stars on its wings and bright glowing eyes, accent storm purple, sparkles",
    "egg_forest": "a large speckled green egg wrapped in leaves and vines, accent nature green",
    "egg_magma": "a large dark volcanic egg with glowing orange lava cracks, accent fire orange",
    "egg_crystal": "a large egg made of pale blue and pink crystal facets with a soft inner glow, accent frost blue, sparkles",
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
        try:
            subprocess.run([codex, "exec", "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                           cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        except subprocess.TimeoutExpired:
            pass
        print("made" if os.path.exists(target) else "FAILED", name, flush=True)


if __name__ == "__main__":
    main()
