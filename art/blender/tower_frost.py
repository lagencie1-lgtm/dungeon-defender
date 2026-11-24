"""The Frost Crystal, painted version: a tall ice crystal cluster with a glowing core shard, rising from frosted
rocks on the round stone base the other defenders share. About 7.5 studs tall.
Run: blender -b -P tower_frost.py -- out.fbx"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel  # noqa: E402

W = (1, 1, 1)
CORE = (0.55, 0.85, 1.0)
lib.reset()
paint.setup()

paint.paint(bevel(lib.cylinder("Base", 2.95, 0.9, (0, 0, 0.45), W, vertices=18), 0.15), "stone", (0.8, 0.8, 0.84), 2.2)
paint.paint(lib.cylinder("Ring", 3.0, 0.2, (0, 0, 0.95), W, vertices=18), "brass", W, 1.2)
# frosted rocks around the foot
for i in range(6):
    a = i / 6 * math.pi * 2 + 0.4
    rock = lib.sphere(f"Rock{i}", 0.75 + (i % 2) * 0.2, (math.cos(a) * 1.75, math.sin(a) * 1.75, 1.2), W, segments=8)
    rock.scale = (1.2, 1.0, 0.7)
    paint.paint(rock, "stone", (0.86, 0.9, 0.98), 1.4)
# main crystal: six-sided column with a pointed top
paint.paint(bevel(lib.cylinder("Crystal", 1.0, 4.2, (0, 0, 3.3), W, vertices=6), 0.05), "ice", W, 2.0)
paint.paint(lib.cone("CrystalTip", 1.0, 1.7, (0, 0, 6.25), W, vertices=6), "ice", W, 2.0)
# the glowing core showing through a crack in front
paint.glow(lib.box("Core", (0.5, 0.2, 2.6), (0, -0.92, 3.6), W), CORE)
# smaller crystals leaning out
for i in range(6):
    a = i / 6 * math.pi * 2 + 0.25
    h = 1.6 + (i % 3) * 0.7
    x, y = math.cos(a) * 1.3, math.sin(a) * 1.3
    tint = (0.82, 0.9, 1.0) if i % 2 else W
    paint.paint(lib.cylinder(f"Shard{i}", 0.42, h, (x, y, 1.3 + h / 2), W, vertices=6,
                             rotation=(-math.sin(a) * 0.35, math.cos(a) * 0.35, 0)), "ice", tint, 1.5)
    paint.paint(lib.cone(f"ShardTip{i}", 0.42, 0.7, (x * 1.15, y * 1.15, 1.3 + h + 0.3), W, vertices=6), "ice", tint, 1.5)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("tower_frost", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
