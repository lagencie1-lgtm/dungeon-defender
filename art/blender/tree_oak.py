"""Cursed Forest tree: a chunky stylised oak with a slightly bent trunk, root flares, a few branches and a
lumpy painted canopy. About 16 studs tall (the game scales each one). Run: blender -b -P tree_oak.py -- out.fbx"""
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import smooth  # noqa: E402

W = (1, 1, 1)
rnd = random.Random(3)
lib.reset()
paint.setup()

# trunk: three tapering pieces, leaning a little
lean = 0
z = 0
for i, (r0, r1, h) in enumerate(((1.5, 1.15, 3.2), (1.15, 0.9, 3.2), (0.9, 0.65, 2.6))):
    seg = lib.cone(f"Trunk{i}", r0, h, (lean, 0, z + h / 2), W, vertices=10, radius_top=r1)
    seg.rotation_euler = (0, math.radians(4 + i * 3), 0)
    paint.paint(smooth(seg), "bark", W, 2.5)
    lean += math.sin(math.radians(4 + i * 3)) * h
    z += h * 0.96
# root flares
for i in range(5):
    a = i / 5 * math.pi * 2 + 0.3
    root = lib.cone(f"Root{i}", 0.55, 1.8, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.5), W, vertices=6, radius_top=0.1)
    root.rotation_euler = (-math.sin(a) * 1.95, math.cos(a) * 1.95, 0)
    paint.paint(root, "bark", W, 2.0)
# branches
for i in range(4):
    a = i / 4 * math.pi * 2 + 0.6
    br = lib.cone(f"Branch{i}", 0.35, 3.2, (lean * 0.8 + math.cos(a) * 1.0, math.sin(a) * 1.0, 7.0 + i * 0.4), W,
                  vertices=6, radius_top=0.12)
    br.rotation_euler = (-math.sin(a) * 0.9, math.cos(a) * 0.9, 0)
    paint.paint(br, "bark", W, 2.0)
# canopy: a cluster of soft blobs
top = (lean, 0, z + 1.6)
blobs = [((0, 0, 1.2), 4.4)] + [((math.cos(a) * 3.6, math.sin(a) * 3.6, rnd.uniform(-0.8, 0.8)), rnd.uniform(2.9, 3.5))
                                 for a in [i / 6 * math.pi * 2 + rnd.uniform(-0.2, 0.2) for i in range(6)]]
blobs.append(((0.4, -0.3, 3.8), 3.0))
for i, ((x, y, dz), r) in enumerate(blobs):
    b = lib.sphere(f"Leaves{i}", r, (top[0] + x, top[1] + y, top[2] + dz), W, segments=12)
    b.scale = (1.0, 1.0, 0.82)
    tint = (0.92 + rnd.uniform(-0.06, 0.06), 1.0, 0.9 + rnd.uniform(-0.06, 0.06))
    paint.paint(smooth(b), "leaves", tint, 2.6)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("tree_oak", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
