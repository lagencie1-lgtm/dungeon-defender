"""The Ballista, painted version: a big wooden crossbow on a turning stand, loaded with an iron-headed bolt,
brass fittings, on the same round stone base as the other defenders. Front faces -Y.
Footprint about 6.5 studs, about 6 studs tall. Run: blender -b -P tower_ballista.py -- out.fbx"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel  # noqa: E402

W = (1, 1, 1)
ROPE = (0.88, 0.80, 0.62)
lib.reset()
paint.setup()

paint.paint(bevel(lib.cylinder("Base", 2.95, 0.9, (0, 0, 0.45), W, vertices=18), 0.15), "stone", (0.8, 0.78, 0.76), 2.2)
paint.paint(lib.cylinder("Ring", 3.0, 0.2, (0, 0, 0.95), W, vertices=18), "brass", W, 1.2)
paint.paint(bevel(lib.cylinder("Turntable", 2.2, 0.5, (0, 0, 1.3), W, vertices=16), 0.08), "wood_dark", W, 1.5)
# A-frame stand
for side in (-1, 1):
    leg = lib.box(f"Leg{side}", (0.42, 0.42, 3.0), (side * 0.9, 0, 2.7), W, rotation=(0, math.radians(-side * 14), 0))
    paint.paint(bevel(leg, 0.06), "wood", W, 1.4)
paint.paint(lib.cylinder("Axle", 0.2, 2.4, (0, 0, 4.0), W, vertices=10, rotation=(0, math.radians(90), 0)), "iron", W, 1.0)
# the stock (rail), pointing forward (-Y) and tipped up a little
tilt = math.radians(-6)
paint.paint(bevel(lib.box("Rail", (0.9, 6.2, 0.55), (0, -0.4, 4.4), W, rotation=(tilt, 0, 0)), 0.07), "wood", W, 1.6)
for i, y in enumerate((-3.3, 0.6, 2.3)):
    band = lib.box(f"RailBand{i}", (1.0, 0.3, 0.64), (0, y, 4.4 - y * math.sin(tilt) + 0.0), W, rotation=(tilt, 0, 0))
    paint.paint(band, "brass", W, 1.0)
# the bow arms, swept back, iron-capped
for side in (-1, 1):
    arm = lib.box(f"Arm{side}", (3.4, 0.38, 0.38), (side * 1.7, -2.6, 4.8), W, rotation=(0, 0, math.radians(side * 18)))
    paint.paint(bevel(arm, 0.06), "wood_dark", W, 1.2)
    paint.paint(lib.sphere(f"Tip{side}", 0.25, (side * 3.3, -2.05, 4.8), W, segments=10), "brass", W, 1.0)
    string = lib.box(f"String{side}", (0.07, 2.6, 0.07), (side * 1.65, -0.85, 4.8), W, rotation=(0, 0, math.radians(side * -52)))
    paint.paint(string, None, ROPE)
# the bolt with an iron head (pointing forward) and cream fletching
paint.paint(lib.box("Bolt", (0.17, 5.0, 0.17), (0, -1.2, 5.0), W, rotation=(tilt, 0, 0)), "wood_dark", W, 1.0)
head = lib.cone("BoltHead", 0.32, 0.85, (0, -4.05, 5.3), W, vertices=4)
head.rotation_euler = (math.radians(90) + tilt, 0, 0)
paint.paint(head, "iron", W, 0.8)
for side in (-1, 1):
    fletch = lib.box(f"Fletch{side}", (0.05, 0.6, 0.35), (side * 0.12, 1.15, 4.86), W, rotation=(tilt, 0, math.radians(side * 30)))
    paint.paint(fletch, "cloth", W, 1.0)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("tower_ballista", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
