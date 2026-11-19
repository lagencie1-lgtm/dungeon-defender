"""Makes the painted UI kit (Codex image generation): panel frames, buttons, item slots and a title ribbon,
all in the game's painted wood-and-parchment style. They are used as 9-slice images (the borders keep their
size, the middle stretches), so each piece is drawn straight-on with an even border.
Run:  python art/make_ui.py            (all missing)
      python art/make_ui.py ui_panel   (only these)
"""
import os
import subprocess
import sys

from make_icons import find_codex

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ui")

STYLE = ("Hand-painted fantasy game UI element in a warm, friendly cartoon adventure style, flat front view (no perspective, "
         "no tilt), perfectly symmetric, centered, filling the whole square canvas edge to edge, fully transparent "
         "background outside the shape, no text, no icons, no shadow box. Palette: dark carved wood #46301E, brass "
         "#D6AA50, cream parchment #F3E6C8. Soft painterly shading with light from the top. Element: ")

PIECES = {
    "ui_panel": ("a rectangular window frame: a carved dark wooden border of even thickness (about 9 percent of the "
                 "width on every side) with small brass corner caps, and a plain dark-brown wood-grain inner panel "
                 "that is evenly lit and empty"),
    "ui_parchment": ("a rectangular parchment sheet with a thin painted brown edge line all around and slightly "
                     "darker worn edges, the middle plain and evenly lit, square format"),
    "ui_button": ("a rounded rectangular button plate: a brass rim of even thickness around a smooth light warm-wood "
                  "face, gentle highlight on the top half, the face plain and evenly lit"),
    "ui_slot": ("a square item slot: a recessed dark wooden square with a thin brass rim of even thickness and "
                "rounded corners, the inside plain and slightly darker"),
    "ui_ribbon": ("a horizontal banner ribbon in deep red cloth with folded ends and a thin gold edge, the middle "
                  "band plain and evenly lit, shape fills the width"),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    codex = find_codex()
    for name in sys.argv[1:] or list(PIECES):
        target = os.path.join(OUT, name + ".png")
        if os.path.exists(target):
            print("have", name)
            continue
        prompt = (STYLE + PIECES[name] + f". Use your image generation tool, square format with a transparent "
                  f"background, and save the image as {name}.png in the current folder. Reply only with the file path.")
        try:
            subprocess.run([codex, "exec", "--skip-git-repo-check", "--sandbox", "workspace-write", prompt],
                           cwd=OUT, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        except subprocess.TimeoutExpired:
            pass
        print("made" if os.path.exists(target) else "FAILED", name, flush=True)


if __name__ == "__main__":
    main()
