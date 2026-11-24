"""The Storm Obelisk, painted version: a carved rune-stone obelisk with brass bands and glowing rune lines,
on the round stone base the other defenders share, holding a crackling violet orb in brass claws.
About 12 studs tall. Run: blender -b -P tower_storm.py -- out.fbx"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel, smooth  # noqa: E402

W = (1, 1, 1)
ORB = (0.72, 0.45, 1.0)
lib.reset()
paint.setup()

paint.paint(bevel(lib.cylinder("Base", 2.95, 1.0, (0, 0, 0.5), W, vertices=18), 0.15), "stone", (0.8, 0.78, 0.76), 2.2)
paint.paint(lib.cylinder("Ring", 3.0, 0.2, (0, 0, 1.05), W, vertices=18), "brass", W, 1.2)
paint.paint(bevel(lib.box("Step", (3.6, 3.6, 0.7), (0, 0, 1.45), W), 0.12), "rune_stone", (0.85, 0.82, 0.9), 2.0)
pillar = lib.cone("Pillar", 1.45, 8.0, (0, 0, 5.8), W, vertices=4, radius_top=0.78)
pillar.rotation_euler = (0, 0, math.radians(45))
paint.paint(bevel(pillar, 0.1), "rune_stone", W, 2.5)
for z, r in ((3.0, 1.33), (6.8, 1.05)):
    band = lib.cone(f"Band{z}", r + 0.14, 0.38, (0, 0, z), W, vertices=4, radius_top=r + 0.1)
    band.rotation_euler = (0, 0, math.radians(45))
    paint.paint(band, "brass", W, 1.0)
# glowing rune strips down each face
for i in range(4):
    a = i * math.pi / 2
    x, y = math.cos(a), math.sin(a)
    strip = lib.box(f"Rune{i}", (0.16, 0.12, 2.2), (x * 0.95, y * 0.95, 4.9), W, rotation=(-y * 0.08, x * 0.08, a))
    paint.glow(strip, ORB)
cap = lib.cone("Cap", 1.0, 0.9, (0, 0, 10.25), W, vertices=4, radius_top=0.42)
cap.rotation_euler = (0, 0, math.radians(45))
paint.paint(cap, "brass", W, 1.0)
for i in range(4):
    a = i * math.pi / 2 + math.pi / 4
    claw = lib.cone(f"Claw{i}", 0.16, 1.4, (math.cos(a) * 0.58, math.sin(a) * 0.58, 11.1), W, vertices=6, radius_top=0.05)
    claw.rotation_euler = (-math.sin(a) * 0.45, math.cos(a) * 0.45, 0)
    paint.paint(claw, "brass", W, 1.0)
paint.glow(smooth(lib.sphere("Orb", 1.05, (0, 0, 11.9), W, segments=16)), ORB)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("tower_storm", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
