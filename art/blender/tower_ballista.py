"""The Ballista, matching its icon: a big wooden crossbow on a turning stand, loaded with a bolt, brass fittings."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

STEEL = (0.75, 0.76, 0.80)
ROPE = (0.88, 0.82, 0.66)

lib.reset()
lib.box("Base", (5.6, 5.6, 0.9), (0, 0, 0.45), lib.STONE_DARK, bevel=0.12)
lib.cylinder("Turntable", 2.2, 0.5, (0, 0, 1.15), lib.WOOD_DARK, vertices=12)
# A-frame stand
for side in (-1, 1):
    lib.box(f"Leg{side}", (0.4, 0.4, 3.0), (side * 0.9, 0, 2.6), lib.WOOD, rotation=(0, math.radians(-side * 14), 0))
lib.box("Axle", (2.4, 0.35, 0.35), (0, 0, 3.9), lib.BRASS)
# the stock (rail), pointing forward (-Y) and tipped up a little
tilt = math.radians(-6)
lib.box("Rail", (0.9, 6.2, 0.55), (0, -0.4, 4.3), lib.WOOD, bevel=0.06, rotation=(tilt, 0, 0))
lib.box("RailTrim", (1.0, 0.4, 0.62), (0, -3.3, 4.62), lib.BRASS, rotation=(tilt, 0, 0))
# the bow arms, swept back
for side in (-1, 1):
    lib.box(f"Arm{side}", (3.4, 0.35, 0.35), (side * 1.7, -2.6, 4.7), lib.WOOD_DARK,
            rotation=(0, 0, math.radians(side * 18)))
    lib.sphere(f"Tip{side}", 0.22, (side * 3.3, -2.05, 4.7), lib.BRASS, segments=8)
    lib.box(f"String{side}", (0.06, 2.6, 0.06), (side * 1.65, -0.85, 4.7), ROPE,
            rotation=(0, 0, math.radians(side * -52)))
# the bolt with a steel head and cream fletching
lib.box("Bolt", (0.16, 5.0, 0.16), (0, -1.2, 4.9), lib.WOOD_DARK, rotation=(tilt, 0, 0))
lib.cone("BoltHead", 0.3, 0.8, (0, -4.0, 5.2), STEEL, vertices=4)
lib.box("Fletch", (0.6, 0.5, 0.05), (0, 1.1, 4.75), lib.CREAM)

parts = lib.join_all("Ballista")
print("TRIANGLES", lib.triangles(parts))
out = sys.argv[sys.argv.index("--") + 1]
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", out)
