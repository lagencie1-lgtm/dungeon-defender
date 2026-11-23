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

BARE = ("the hooded green archer from image 1, as a stand-alone chibi game character: head about 40 percent of the "
        "height, a big rounded green hood ending in a soft point at the back, with a cream inner lining framing a round "
        "friendly face with clear dark eyes with a white shine, short brown brows, a little brown hair fringe and a small "
        "confident smile, green tunic with cream trim at the hem and sleeves, a brown leather belt with a gold buckle, brown "
        "leather bracers on both forearms, brown trousers and brown boots. Same painterly style, palette and soft light "
        "from the top left as image 1. Clean, readable shapes, no tiny clutter.")

JOBS = {
    "turn": ("ranger_archer_turn.png", "Paint a character turnaround sheet of " + LOOK + " Four full-body views side by "
             "side at the same size, standing in a relaxed bow-ready pose (bow held in the left hand, lowered, no arrow "
             "drawn, so the arms read clearly): left to right front, three-quarter front-left, side (facing left), "
             "back. Plain pure white background, no text, no ground shadow. Wide image."),
    "ortho": ("ranger_archer_ortho.png", "Paint a strict orthographic character model sheet of " + LOOK.replace(", a wooden bow drawn with an arrow nocked", "") +
              " Three full-body views side by side at exactly the same size and height, feet on the same line, head tops on the "
              "same line: FRONT view (looking straight at him), SIDE view (his left side, facing the right edge of the "
              "image), BACK view. Neutral standing pose, legs slightly apart, both arms hanging a little away from the body "
              "with empty hands in loose fists, so the arms do not cover the body. No bow in the hands. Flat orthographic "
              "views, no perspective, no turning of the head. Plain pure white background, no text, no ground shadow. Wide image."),
    # rebuild sheets (Lemp 2026-11-23: torn face, cut head): nothing may overlap the body's outline in any view
    "bare": ("ranger_archer_bare.png", "Paint a strict orthographic character model sheet of " + BARE + " Three full-body "
             "views side by side at exactly the same size and height, feet on the same line, head tops on the same line: "
             "FRONT view (looking straight at him), SIDE view (his left side, nose pointing to the right edge of the image), "
             "BACK view. Neutral A-pose: standing straight, legs slightly apart, both arms held well away from the body at "
             "about 30 degrees with empty hands in loose fists, so there is clear white space between each arm and the "
             "torso in the front and back views. He carries NOTHING: no bow, no quiver, no arrows, no strap across the chest, "
             "nothing on his back. The hood outline must be one smooth unbroken shape in every view. Flat orthographic views, "
             "no perspective, the head looking straight ahead. Plain pure white background, no text, no ground shadow. Wide image."),
    "bare34": ("ranger_archer_bare34.png", "Image 2 is the model sheet of this character. Paint the same character in "
               "exactly the same A-pose (arms well away from the body, carrying nothing: no bow, no quiver, no arrows) in two "
               "full-body views side by side at the same size: left, three-quarter view from his front-left (turned 45 "
               "degrees); right, three-quarter view from his front-right (turned 45 degrees the other way). Orthographic, "
               "eye level, same proportions, colours and painterly style as image 2. The hood outline is one smooth unbroken "
               "shape. Plain pure white background, no text, no ground shadow. Wide image."),
    "q34": ("ranger_archer_34.png", "Image 2 is the model sheet of this character (front, side, back). Paint the same "
            "character in exactly the same neutral standing pose as image 2 (arms hanging a little away from the body, "
            "the wooden longbow held lowered in his left hand, the quiver on his back), seen in three-quarter view from "
            "the front-left (45 degrees) at eye level, orthographic, full body. Same proportions, colours and painterly "
            "style as image 2. Plain pure white background, no text, no ground shadow. Square image."),
    "props": ("ranger_archer_props.png", "Paint a flat prop sheet for " + LOOK + " Left: his wooden longbow with its "
              "string, seen flat from the side, standing upright. Right: his brown leather quiver with white-fletched arrows, "
              "seen flat from the front. Same painterly style. Plain pure white background, no text. Wide image."),
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
        extra = ([os.path.join(OUT, "ranger_archer_ortho.png")] if key == "q34" else
                 [os.path.join(OUT, "ranger_archer_bare.png")] if key == "bare34" else [])
        codex_paint(full, name, OUT, [STYLE] + extra)


if __name__ == "__main__":
    main()
