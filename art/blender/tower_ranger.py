"""The Ranger defender: a sturdy wooden watchtower on a stone footing with a green archer.
Footprint 5x5 studs, about 12 studs tall (matches the old part-built tower), under 3,000 triangles."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

lib.reset()

# stone footing, slightly uneven blocks so it doesn't look copy-pasted
lib.box("Footing", (5.2, 5.2, 1.0), (0, 0, 0.5), lib.STONE_DARK, bevel=0.15)
for i, (x, y) in enumerate([(-1.6, -1.6), (1.6, -1.6), (-1.6, 1.6), (1.6, 1.6)]):
    lib.box(f"Stone{i}", (1.4 + 0.1 * i, 1.4, 0.35), (x, y, 1.15), lib.STONE, bevel=0.1)

# four leaning posts and cross braces
for i, (x, y) in enumerate([(-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5)]):
    lib.box(f"Post{i}", (0.45, 0.45, 7.4), (x * 0.9, y * 0.9, 4.7), lib.WOOD, bevel=0.06,
            rotation=(math.radians(-y * 1.5), math.radians(x * 1.5), 0))
for z in (3.0, 6.0):
    lib.box(f"BraceX{z}", (3.2, 0.25, 0.3), (0, -1.35, z), lib.WOOD_DARK)
    lib.box(f"BraceY{z}", (0.25, 3.2, 0.3), (1.35, 0, z), lib.WOOD_DARK)

# the platform with a brass-capped railing
lib.box("Platform", (4.8, 4.8, 0.5), (0, 0, 8.55), lib.WOOD, bevel=0.08)
for i in range(4):
    angle = i * math.pi / 2
    x, y = math.cos(angle) * 2.2, math.sin(angle) * 2.2
    lib.box(f"Rail{i}", (0.3 if i % 2 == 0 else 4.6, 4.6 if i % 2 == 0 else 0.3, 0.9), (x, y, 9.2), lib.WOOD_DARK)
for i, (x, y) in enumerate([(-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)]):
    lib.sphere(f"Cap{i}", 0.28, (x, y, 9.8), lib.BRASS, segments=8)

# the archer: green cloak, hood, bow
lib.cone("Cloak", 0.9, 2.2, (0, 0, 10.0), lib.GREEN, vertices=10, radius_top=0.45)
lib.sphere("Hood", 0.62, (0, 0, 11.45), (0.25, 0.5, 0.25), segments=10)
lib.box("Bow", (0.12, 0.2, 2.4), (0, -0.85, 10.4), lib.WOOD_DARK, rotation=(math.radians(10), 0, 0))

# a small flag so the silhouette reads from far away
lib.cylinder("FlagPole", 0.07, 2.2, (-2.2, 2.2, 10.9), lib.WOOD_DARK, vertices=6)
lib.box("Flag", (0.06, 1.1, 0.7), (-2.2, 2.75, 11.6), lib.GREEN)

tower = lib.join_all("RangerTower")
print("TRIANGLES", lib.triangles(tower))
out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "..", "models", "tower_ranger.fbx")
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", os.path.abspath(out))
