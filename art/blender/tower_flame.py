"""The Flame Cannon, matching its painted icon (art/icons/tower_flame.png): a stout dark-iron cannon with brass
bands on a round stone base, the muzzle glowing orange. Footprint about 5.5 studs, about 7 studs tall."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

IRON = (0.32, 0.31, 0.33)
IRON_DARK = (0.22, 0.21, 0.23)

lib.reset()

# round stone base in two steps, with a brass ring
lib.cylinder("Base", 2.9, 1.0, (0, 0, 0.5), lib.STONE_DARK, vertices=16)
lib.cylinder("Base2", 2.5, 0.6, (0, 0, 1.3), lib.STONE, vertices=16)
lib.cylinder("Ring", 2.55, 0.18, (0, 0, 1.62), lib.BRASS, vertices=16)

# the carriage: two wooden cheeks
for side in (-1, 1):
    lib.box(f"Cheek{side}", (0.5, 2.6, 1.8), (side * 1.05, 0, 2.5), lib.WOOD, bevel=0.08)
    lib.cylinder(f"Wheel{side}", 0.85, 0.35, (side * 1.45, 0.6, 2.0), lib.WOOD_DARK, vertices=12,
                 rotation=(0, math.radians(90), 0))
    lib.cylinder(f"Hub{side}", 0.25, 0.42, (side * 1.45, 0.6, 2.0), lib.BRASS, vertices=8,
                 rotation=(0, math.radians(90), 0))

# the barrel, tilted up, pointing forward (-Y in Blender = forward in the game)
tilt = math.radians(-22)
lib.cylinder("Barrel", 0.8, 4.2, (0, -0.9, 3.4), IRON, vertices=14, rotation=(math.radians(90) + tilt, 0, 0))
lib.sphere("Breech", 0.95, (0, 0.95, 2.65), IRON_DARK, segments=12)
# brass bands around the barrel, placed along its axis
angle = math.radians(90) + tilt
axis = (0, -math.sin(angle), math.cos(angle))
for i, t in enumerate((0.7, -0.7)):
    lib.cylinder(f"Band{i}", 0.88, 0.25, (0, -0.9 + axis[1] * t, 3.4 + axis[2] * t),
                 lib.BRASS, vertices=14, rotation=(angle, 0, 0))
lib.cylinder("Muzzle", 0.95, 0.4, (0, -2.75, 4.15), IRON_DARK, vertices=14, rotation=(math.radians(90) + tilt, 0, 0))
lib.cylinder("Glow", 0.62, 0.2, (0, -2.95, 4.23), lib.FIRE, vertices=12, rotation=(math.radians(90) + tilt, 0, 0))

parts = lib.join_all("FlameCannon")
print("TRIANGLES", lib.triangles(parts))
out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "..", "models", "tower_flame.fbx")
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", os.path.abspath(out))
