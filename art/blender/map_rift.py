"""Crystal Caves: the shadow rift where the enemies come out. A jagged arch of cave rock with crystals growing
from it, around a glowing violet tear. Opening faces -Y. About 18 wide, 20 tall.
Run: blender -b -P map_rift.py -- out.fbx"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel  # noqa: E402

W = (1, 1, 1)
VOID = (0.62, 0.32, 1.0)
rnd = random.Random(11)
lib.reset()
paint.setup()

# the arch: rock chunks stacked along a pointed arc
n = 16
for i in range(n + 1):
    t = i / n
    a = math.pi * t
    x = -math.cos(a) * 7.5
    z = math.sin(a) * 14 + 1.0
    size = 3.2 - abs(t - 0.5) * 1.6 + rnd.uniform(-0.3, 0.3)
    rock = lib.box(f"Arch{i}", (size, 3.4, size), (x, 0, z), W,
                   rotation=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.3)))
    paint.paint(bevel(rock, 0.25), "t_cave_wall", W, 2.5)
# crystals growing from the arch
for i in range(9):
    t = rnd.uniform(0.05, 0.95)
    a = math.pi * t
    x, z = -math.cos(a) * 8.6, math.sin(a) * 15.2 + 1.0
    body = lib.cone(f"Crystal{i}", 0.5, rnd.uniform(1.8, 3.2), (x, rnd.uniform(-1, 1), z), W, vertices=6, radius_top=0.0)
    body.rotation_euler = (rnd.uniform(-0.4, 0.4), math.cos(a) * -1.2, 0)
    paint.paint(body, "crystal", (1.0, 0.85, 1.0) if i % 2 else (0.85, 0.95, 1.0), 1.5)
# base rubble
for i in range(7):
    rub = lib.sphere(f"Rubble{i}", rnd.uniform(1.0, 1.8), (rnd.uniform(-9, 9), rnd.uniform(-1.5, 1.5), 0.3), W, segments=7)
    rub.scale = (1.2, 1, 0.6)
    paint.paint(rub, "t_cave_wall", W, 2.0)
# the glowing tear inside the arch
paint.glow(lib.box("Void", (11.5, 0.4, 13.5), (0, 0.2, 7.2), W), VOID)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("map_rift", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
