"""Crystal Caves: a cluster of painted magic crystals growing out of a chunk of cave rock, one bright core shard.
About 8 studs tall (the game scales each one). Run: blender -b -P crystal_cluster.py -- out.fbx"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel  # noqa: E402

W = (1, 1, 1)
rnd = random.Random(5)
lib.reset()
paint.setup()

for i in range(4):
    a = i / 4 * math.pi * 2
    rock = lib.sphere(f"Rock{i}", 1.4 + rnd.uniform(0, 0.5), (math.cos(a) * 1.2, math.sin(a) * 1.2, 0.3), W, segments=7)
    rock.scale = (1.2, 1.0, 0.6)
    paint.paint(rock, "t_cave_wall", W, 2.0)


def shard(name, x, y, r, h, tilt_x, tilt_y, tint, glow=False):
    body = lib.cylinder(name, r, h, (x, y, h / 2), W, vertices=6, rotation=(tilt_x, tilt_y, 0))
    tip = lib.cone(name + "Tip", r, r * 2.2, (x + math.sin(tilt_y) * h, y - math.sin(tilt_x) * h, h + r * 1.1), W, vertices=6)
    tip.rotation_euler = (tilt_x, tilt_y, 0)
    for o in (body, tip):
        if glow:
            paint.glow(o, tint)
        else:
            paint.paint(bevel(o, 0.04), "crystal", tint, 2.0)


shard("Main", 0, 0, 0.95, 5.6, 0.05, -0.08, W)
shard("Core", 0.15, -0.9, 0.35, 4.0, -0.15, 0.05, (0.75, 0.55, 1.0), glow=True)
for i in range(6):
    a = i / 6 * math.pi * 2 + rnd.uniform(-0.3, 0.3)
    d = rnd.uniform(1.0, 1.7)
    h = rnd.uniform(2.0, 3.8)
    tint = (0.85, 0.95, 1.0) if i % 2 else (1.0, 0.85, 1.0)
    shard(f"Side{i}", math.cos(a) * d, math.sin(a) * d, rnd.uniform(0.35, 0.55), h,
          -math.sin(a) * 0.45, math.cos(a) * 0.45, tint)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("crystal_cluster", out[:-4] + "_paint.png", 512)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
