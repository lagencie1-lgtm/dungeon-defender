"""Cursed Forest dead tree: a twisted bare trunk with crooked branches and glowing violet mushrooms at its foot.
About 15 studs tall. Run: blender -b -P tree_dead.py -- out.fbx"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import smooth  # noqa: E402

W = (1, 1, 1)
GLOW = (0.72, 0.42, 1.0)
rnd = random.Random(9)
lib.reset()
paint.setup()

x, z = 0.0, 0.0
for i in range(5):
    r0 = 1.1 - i * 0.18
    h = 3.0
    tilt = math.radians((-1) ** i * 10)
    seg = lib.cone(f"Trunk{i}", r0, h, (x, 0, z + h / 2), W, vertices=8, radius_top=r0 - 0.18)
    seg.rotation_euler = (0, tilt, 0)
    paint.paint(smooth(seg), "bark", (0.78, 0.74, 0.8), 2.0)
    x += math.sin(tilt) * h
    z += h * 0.95
    if i >= 2:
        for side in (-1, 1):
            a = rnd.uniform(0, math.pi * 2)
            br = lib.cone(f"Branch{i}{side}", 0.3, 3.4 - i * 0.3, (x + math.cos(a) * 0.8, math.sin(a) * 0.8, z - 0.5), W,
                          vertices=6, radius_top=0.05)
            br.rotation_euler = (-math.sin(a) * 1.0, math.cos(a) * 1.0, 0)
            paint.paint(br, "bark", (0.78, 0.74, 0.8), 1.5)
for i in range(5):
    a = i / 5 * math.pi * 2
    root = lib.cone(f"Root{i}", 0.45, 1.8, (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.35), W, vertices=6, radius_top=0.08)
    root.rotation_euler = (-math.sin(a) * 1.95, math.cos(a) * 1.95, 0)
    paint.paint(root, "bark", (0.78, 0.74, 0.8), 1.5)
# glowing mushrooms
for i in range(4):
    a = rnd.uniform(0, math.pi * 2)
    d = rnd.uniform(1.4, 2.2)
    mx, my = math.cos(a) * d, math.sin(a) * d
    paint.paint(lib.cylinder(f"Stem{i}", 0.12, 0.6, (mx, my, 0.3), W, vertices=6), None, (0.9, 0.86, 0.8))
    cap = lib.sphere(f"Cap{i}", 0.38, (mx, my, 0.65), W, segments=10)
    cap.scale = (1, 1, 0.5)
    paint.glow(cap, GLOW)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("tree_dead", out[:-4] + "_paint.png", 512)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
