"""The Ranger defender, matching its painted icon (art/icons/tower_ranger.png): a sturdy wooden watchtower
with a ladder, cream banners with a green stripe, a crenellated top with brass caps and a green-hooded archer.
Footprint 5x5 studs, about 12.5 studs tall, under 3,000 triangles."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

lib.reset()

# stone footing
lib.box("Footing", (5.4, 5.4, 0.9), (0, 0, 0.45), lib.STONE_DARK, bevel=0.15)
lib.box("Footing2", (4.6, 4.6, 0.4), (0, 0, 1.1), lib.STONE, bevel=0.1)

# four thick posts, slightly leaning in (wider at the bottom), with brass feet
for i, (x, y) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
    lib.box(f"Post{i}", (0.6, 0.6, 7.2), (x * 1.65, y * 1.65, 4.85), lib.WOOD, bevel=0.07,
            rotation=(math.radians(y * 2.5), math.radians(-x * 2.5), 0))
    lib.box(f"Foot{i}", (0.8, 0.8, 0.3), (x * 1.8, y * 1.8, 1.45), lib.BRASS, bevel=0.06)

# X braces on the sides
for side in (-1, 1):
    for angle in (35, -35):
        lib.box(f"BraceX{side}{angle}", (0.22, 0.18, 4.4), (side * 1.62, 0, 4.4), lib.WOOD_DARK,
                rotation=(math.radians(angle), 0, 0))
        lib.box(f"BraceY{side}{angle}", (0.18, 0.22, 4.4), (0, side * 1.62, 4.4), lib.WOOD_DARK,
                rotation=(0, math.radians(angle), 0))

# a ladder up the front
for side in (-0.45, 0.45):
    lib.box(f"LadderRail{side}", (0.14, 0.14, 7.2), (side, -2.05, 4.9), lib.WOOD_DARK)
for i in range(8):
    lib.box(f"Rung{i}", (1.0, 0.12, 0.12), (0, -2.05, 1.8 + i * 0.75), lib.WOOD)

# platform and crenellated wall with brass caps
lib.box("Platform", (5.0, 5.0, 0.55), (0, 0, 8.75), lib.WOOD, bevel=0.08)
lib.box("PlatformTrim", (5.2, 5.2, 0.18), (0, 0, 8.45), lib.BRASS)
for i in range(4):
    for j in (-1, 0, 1):
        along = j * 1.7
        if i == 0:
            pos = (along, -2.35, 9.55)
        elif i == 1:
            pos = (along, 2.35, 9.55)
        elif i == 2:
            pos = (-2.35, along, 9.55)
        else:
            pos = (2.35, along, 9.55)
        lib.box(f"Merlon{i}{j}", (0.9, 0.9, 1.05), pos, lib.WOOD_DARK, bevel=0.06)
        lib.box(f"MerlonCap{i}{j}", (1.0, 1.0, 0.16), (pos[0], pos[1], 10.15), lib.BRASS)

# banners hanging under the platform (cream with a green stripe)
for i, (x, y, rot) in enumerate([(0, -2.62, 0), (0, 2.62, 0), (-2.62, 0, 90), (2.62, 0, 90)]):
    if i == 0:
        continue  # the ladder is on the front
    lib.box(f"Banner{i}", (1.3, 0.06, 1.9), (x, y, 7.4), lib.CREAM, rotation=(0, 0, math.radians(rot)))
    lib.box(f"BannerStripe{i}", (0.45, 0.08, 1.9), (x, y, 7.4), lib.GREEN, rotation=(0, 0, math.radians(rot)))

# the archer: boots, green cloak body, face, hood and a drawn bow
lib.box("Legs", (0.7, 0.5, 0.8), (0, 0.2, 10.3), lib.WOOD_DARK)
lib.cone("Cloak", 0.85, 1.7, (0, 0.2, 11.3), lib.GREEN, vertices=10, radius_top=0.5)
lib.sphere("Face", 0.42, (0, 0.05, 12.35), (0.96, 0.78, 0.62), segments=10)
lib.cone("Hood", 0.6, 0.95, (0, 0.25, 12.65), (0.27, 0.52, 0.26), vertices=10, radius_top=0.08)
lib.box("Bow", (0.14, 0.14, 2.3), (0.55, -0.6, 11.6), lib.WOOD_DARK, rotation=(0, math.radians(8), 0))
lib.box("Arrow", (0.07, 1.6, 0.07), (0.3, -0.55, 11.65), lib.CREAM)

tower = lib.join_all("RangerTower")
print("TRIANGLES", lib.triangles(tower))
out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "..", "models", "tower_ranger.fbx")
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", os.path.abspath(out))
