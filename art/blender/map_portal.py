"""The portal you defend, painted version: a carved stone ring arch with glowing violet runes and a keystone gem,
on a round two-step dais. The game's own glowing disc sits inside it. The ring faces -Y. About 22 wide, 22 tall.
Run: blender -b -P map_portal.py -- out.fbx   (also writes out_paint.png)"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402

W = (1, 1, 1)
LILAC = (0.86, 0.82, 0.95)
RUNE = (0.72, 0.42, 1.0)
lib.reset()
paint.setup()


def bevel(obj, width, segments=2):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


paint.paint(bevel(lib.cylinder("Dais", 11.5, 1.0, (0, 0, 0.5), W, vertices=28), 0.2), "stone", (0.8, 0.78, 0.84), 3)
paint.paint(bevel(lib.cylinder("Dais2", 9.5, 0.8, (0, 0, 1.4), W, vertices=28), 0.15), "t_cobble", LILAC, 3)
ring_r, center_z = 9.0, 11.0
for i in range(20):
    a = i / 20 * math.pi * 2
    x, z = math.cos(a) * ring_r, center_z + math.sin(a) * ring_r
    block = lib.box(f"Block{i}", (2.9, 2.6, 2.0), (x, 0, z), W, rotation=(0, -a + math.pi / 2, 0))
    paint.paint(bevel(block, 0.22), "stone", LILAC if i % 2 == 0 else (0.72, 0.68, 0.8), 2.2)
    if i % 2 == 0:
        paint.glow(lib.box(f"Rune{i}", (0.9, 0.2, 0.5), (x * 0.99, -1.35, z), W, rotation=(0, -a + math.pi / 2, 0)), RUNE)
key = lib.box("Keystone", (3.4, 3.0, 2.8), (0, 0, center_z + ring_r + 0.4), W)
paint.paint(bevel(key, 0.3), "stone", (0.7, 0.66, 0.78), 2.2)
paint.glow(lib.sphere("KeyGem", 0.75, (0, -1.6, center_z + ring_r + 0.4), W, segments=12), RUNE)
for side in (-1, 1):
    foot = lib.box(f"Foot{side}", (3.6, 3.2, 3.0), (side * 7.6, 0, 3.2), W)
    paint.paint(bevel(foot, 0.3), "stone", (0.72, 0.68, 0.8), 2.2)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("map_portal", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
