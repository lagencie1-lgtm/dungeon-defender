"""Orthographic model sheets of the towers for the picture-as-body build (art/blender/picture_body.py; coordinator
2026-11-23: the tower elevation pass). Codex paints, from the tower's level picture, a flat FRONT, SIDE and BACK view
at the same height, without the archers (they are their own model) or other figures.
Writes art/ref3d/ortho/tower_<kind>_l<level>_ortho.png.
Run: python scripts/tower_ortho.py <kind> [levels=1,2,3]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tower_paint import codex_paint  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "ref3d", "ortho")

PROMPT = ("Image 1 is a painting of a defense tower for a kids' game. Paint a strict orthographic model sheet of exactly "
          "this tower: three views side by side at exactly the same size and height, base on the same line, top on the "
          "same line: FRONT view (looking straight at the door side), SIDE view (from its right), BACK view. Flat "
          "orthographic views, no perspective, no tilt, the same proportions, parts, colours and painterly style as "
          "image 1. {extra}Plain pure white background, no ground shadow, no text. Wide image.\n\nUse your image "
          "generation tool with image 1 as the reference and save the result as {{name}} in the current folder. Reply "
          "only with the file path.")
EXTRA = {"ranger": "Leave out the archers and any people: the lookout is empty. "}


def main():
    kind = sys.argv[1]
    levels = [int(v) for v in (sys.argv[2] if len(sys.argv) > 2 else "1,2,3").split(",")]
    os.makedirs(OUT, exist_ok=True)
    for level in levels:
        picture = os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png")
        name = f"tower_{kind}_l{level}_ortho.png"
        codex_paint(PROMPT.format(extra=EXTRA.get(kind, "")), name, OUT, [picture])


if __name__ == "__main__":
    main()
