"""The goblin: chunky body, big head with long ears, big nose, glowing eyes, a little loincloth and belt.
Skin uses the marker colour pure green (0, 1, 0): the game repaints it in each goblin type's colour.
Faces -Y (game forward). About 4.8 studs tall before the game scales it per goblin size."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

SKIN = (0.0, 1.0, 0.0)  # marker: recoloured in the game
CLOTH = (0.50, 0.33, 0.20)
BELT = (0.30, 0.20, 0.13)
EYE = (1.0, 0.16, 0.16)  # bright red: glows in the game

lib.reset()
# legs and feet
for side in (-1, 1):
    lib.box(f"Leg{side}", (0.55, 0.55, 1.0), (side * 0.45, 0, 0.5), SKIN, bevel=0.1)
    lib.box(f"Foot{side}", (0.65, 0.85, 0.3), (side * 0.48, -0.15, 0.15), BELT, bevel=0.08)
# round belly body
lib.sphere("Body", 1.05, (0, 0, 1.75), SKIN, segments=12)
lib.box("Loincloth", (1.5, 1.3, 0.55), (0, 0, 1.1), CLOTH, bevel=0.1)
lib.box("Belt", (1.7, 1.45, 0.2), (0, 0, 1.4), BELT)
lib.sphere("Buckle", 0.14, (0, -0.73, 1.4), lib.BRASS, segments=8)
# arms
for side in (-1, 1):
    lib.box(f"Arm{side}", (0.42, 0.42, 1.2), (side * 1.15, -0.1, 1.75), SKIN, bevel=0.1,
            rotation=(math.radians(15), math.radians(side * 20), 0))
    lib.sphere(f"Hand{side}", 0.3, (side * 1.35, -0.3, 1.2), SKIN, segments=8)
# big head
lib.sphere("Head", 0.95, (0, -0.05, 3.35), SKIN, segments=14)
# long pointy ears
for side in (-1, 1):
    ear = lib.cone(f"Ear{side}", 0.32, 1.5, (side * 1.25, 0.05, 3.55), SKIN, vertices=6)
    ear.rotation_euler = (0, math.radians(-side * 70), 0)
# nose and eyes
lib.sphere("Nose", 0.28, (0, -0.95, 3.2), SKIN, segments=8)
for side in (-1, 1):
    lib.sphere(f"Eye{side}", 0.16, (side * 0.38, -0.82, 3.55), EYE, segments=8)
    lib.box(f"Brow{side}", (0.4, 0.12, 0.1), (side * 0.38, -0.86, 3.78), BELT,
            rotation=(0, math.radians(side * -15), 0))

parts = lib.join_all("Goblin")
print("TRIANGLES", lib.triangles(parts))
out = sys.argv[sys.argv.index("--") + 1]
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", out)
