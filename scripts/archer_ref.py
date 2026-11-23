"""Target pictures for the Ranger's archer (coordinator 2026-11-23: the archer is its own asset with its own run of the
workflow). Codex paints, in the style of the tower paintings, (1) a turnaround: front, three-quarter, side and back
on one sheet, (2) a face close-up, (3) the three-quarter view alone, big, as the main target.
Writes art/ref3d/archer/ranger_archer_turn.png, _face.png, ranger_archer.png.
Run: python scripts/archer_ref.py [turn|face|main ...]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tower_paint import codex_paint  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "ref3d", "archer")
STYLE = os.path.join(ROOT, "art", "ref3d", "tower_ranger_l2.png")

LOOK = ("the hooded green archer from image 1, as a stand-alone chibi game character: head about 40 percent of the "
        "height, a big pointed green hood with a cream inner lining framing a round friendly face with clear dark eyes "
        "with a white shine, short brown brows and a small confident smile, green tunic with a brown leather belt "
        "and buckle, brown leather bracers on both forearms, brown boots, a wooden bow drawn with an arrow nocked, a "
        "brown leather quiver on the back with white-fletched arrows. Same painterly style, palette and soft light "
        "from the top left as image 1. Clean, readable shapes, no tiny clutter.")

JOBS = {
    "turn": ("ranger_archer_turn.png", "Paint a character turnaround sheet of " + LOOK + " Four full-body views side by "
             "side at the same size, standing in a relaxed bow-ready pose (bow held in the left hand, lowered, no arrow "
             "drawn, so the arms read clearly): left to right front, three-quarter front-left, side (facing left), "
             "back. Plain pure white background, no text, no ground shadow. Wide image."),
    "face": ("ranger_archer_face.png", "Paint a close-up of the head and shoulders of " + LOOK + " Seen from the front, "
             "a little from the left. Plain pure white background, no text. Square image."),
    "main": ("ranger_archer.png", "Paint " + LOOK + " Full body, seen in three-quarter view from the front-left and a "
             "little from above, drawing the bow with the arrow pointing to the right. Plain pure white background, no "
             "text, no ground shadow. Square image."),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for key in sys.argv[1:] or list(JOBS):
        name, prompt = JOBS[key]
        full = (prompt + " Use your image generation tool with image 1 as the style reference and save the result as "
                "{name} in the current folder. Reply only with the file path.")
        codex_paint(full, name, OUT, [STYLE])


if __name__ == "__main__":
    main()
