"""Paints the reference pictures for image-to-3D (Tripo; Lemp 2026-11-19: "i get tripo pro"): one clean picture
per monster and boss, all with the same prompt frame so the 3D models come out as one set.
Run:  python art/make_ref3d.py            (all missing)
      python art/make_ref3d.py imp slime  (only these)
Output: art/ref3d/<name>.png
"""
import os
import subprocess
import sys

from make_icons import find_codex

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ref3d")

STYLE = ("Stylized 3D game character concept render for image-to-3D conversion, for a friendly fantasy tower "
         "defense game: {subject}. Full body, standing upright in a neutral A-pose with the arms slightly away "
         "from the body, seen from the front at a slight 3/4 angle, simple chunky shapes with few thin parts, "
         "hand-painted texture look, soft even studio lighting with no strong shadows, the whole character visible "
         "and centered, plain pure white background, no ground shadow, no text.")

SUBJECTS = {
    "goblin": ("a chunky cartoon goblin warrior with a big head, long pointed ears and a big nose, green skin, "
               "leather tunic with a belt and brass buckle, holding nothing"),
    "imp": ("a small chubby cartoon fire imp with orange-red skin, little horns, small bat wings, a pointed tail "
            "and a mischievous grin, glowing ember cracks on its belly"),
    "knight": ("a stocky cartoon dark knight in chunky obsidian-purple plate armor with a glowing orange visor "
               "slit, a round shield on one arm and a short broad sword in the other hand, a short cape"),
    "slime": ("a cute wobbly cartoon lava slime blob, orange and red with a glowing yellow core, big round eyes "
              "and a small smile, a few drips at its base (no arms or legs)"),
    "golem": ("a hulking cartoon rock golem with huge fists and short legs, made of chunky dark stone blocks "
              "with glowing orange cracks and a glowing core in its chest, small glowing eyes"),
    "shade": ("a small hooded cartoon shadow ghost in a tattered deep-purple cloak with no feet, a dark face "
              "with two bright glowing eyes and wispy sleeves"),
    "boss_goblin_king": ("a big fat cartoon goblin king with green skin, a golden crown, a red royal cape with "
                         "fur trim, a big belly with a brass-buckled belt and a spiked wooden club in one hand"),
    "boss_molten_golem": ("a giant cartoon molten lava golem with obsidian armor plates, rivers of glowing lava "
                          "between the plates, a crown of rock spikes and huge glowing fists"),
    "boss_shadow_queen": ("a tall elegant cartoon shadow queen floating in a long flowing violet gown that fades "
                          "into mist, a crown of dark crystals, a pale face with glowing eyes and long sleeves"),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    codex = find_codex()
    for name in sys.argv[1:] or list(SUBJECTS):
        target = os.path.join(OUT, name + ".png")
        if os.path.exists(target):
            print("have", name)
            continue
        prompt = (STYLE.format(subject=SUBJECTS[name]) + f" Use your image generation tool, square format, and save "
                  f"the image as {name}.png in the current folder. Reply only with the file path.")
        try:
            subprocess.run([codex, "exec", "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                           cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        except subprocess.TimeoutExpired:
            pass
        print("made" if os.path.exists(target) else "FAILED", name, flush=True)


if __name__ == "__main__":
    main()
