"""Magma Fortress: the demon gate where the enemies come out, painted version. Two tapering basalt towers with
lava-cracked bands and bone horns, a heavy lintel with iron spikes, a glowing lava maw in a carved frame.
Opening faces -Y (towards the path). About 20 wide, 21 tall.
Run: blender -b -P map_gate.py -- out.fbx   (also writes out_paint.png)"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402

W = (1, 1, 1)
BONE = (0.93, 0.87, 0.74)
IRON = (0.32, 0.30, 0.32)
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


# stepped base
paint.paint(bevel(lib.box("Step1", (21, 8, 1.2), (0, 0, 0.6), W), 0.3), "t_cliff", W, 4)
paint.paint(bevel(lib.box("Step2", (18, 6.5, 1.0), (0, 0.3, 1.7), W), 0.25), "basalt", W, 4)
for side in (-1, 1):
    # tower: three tapering octagonal drums, a lava band between them
    for i, (r, h, z) in enumerate(((3.2, 5.0, 4.7), (2.8, 4.6, 9.5), (2.4, 4.0, 13.8))):
        drum = lib.cone(f"Drum{side}{i}", r, h, (side * 6.6, 0.4, z), W, vertices=8, radius_top=r - 0.35)
        paint.paint(bevel(drum, 0.18), "basalt", (0.62, 0.58, 0.6), 3.5)
        if i < 2:
            band = lib.cylinder(f"Band{side}{i}", r - 0.1, 0.5, (side * 6.6, 0.4, z + h / 2), W, vertices=8)
            paint.paint(band, "lava_rock", W, 2.0)
    crown = lib.cone(f"Crown{side}", 2.6, 0.7, (side * 6.6, 0.4, 16.15), W, vertices=8, radius_top=2.9)
    paint.paint(bevel(crown, 0.1), "basalt", (0.8, 0.75, 0.75), 3)
    # big bone horns curving outwards
    horn = lib.cone(f"Horn{side}", 1.0, 3.6, (side * 7.3, 0.4, 18.0), W, vertices=12, radius_top=0.55)
    horn.rotation_euler = (0, math.radians(side * 28), 0)
    paint.paint(horn, None, BONE)
    tip = lib.cone(f"HornTip{side}", 0.55, 2.6, (side * 8.8, 0.4, 20.2), W, vertices=12, radius_top=0.0)
    tip.rotation_euler = (0, math.radians(side * 55), 0)
    paint.paint(tip, None, BONE)
    # a brazier glow on each tower's front
    paint.glow(lib.sphere(f"Ember{side}", 0.45, (side * 6.6, -2.4, 12.3), W, segments=10), (1.0, 0.55, 0.12))
# lintel with iron spikes and a lava stripe
paint.paint(bevel(lib.box("Lintel", (11, 4.4, 3.0), (0, 0.4, 12.6), W), 0.3), "basalt", (0.62, 0.58, 0.6), 3.5)
paint.paint(lib.box("LintelBand", (11.1, 4.5, 0.5), (0, 0.4, 11.4), W), "lava_rock", W, 2.0)
for i in range(-2, 3):
    spike = lib.cone(f"Spike{i}", 0.4, 1.6, (i * 2.0, -1.4, 14.9), W, vertices=6)
    paint.paint(spike, "iron", W, 1.0)
# carved frame and the glowing maw
frame = lib.box("MawFrame", (9.4, 1.4, 10.0), (0, 0.6, 6.2), W)
paint.paint(bevel(frame, 0.25), "t_cliff", (0.7, 0.62, 0.6), 3)
paint.glow(lib.box("Maw", (7.6, 0.6, 8.6), (0, 0.1, 6.0), W), (1.0, 0.45, 0.1))

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("map_gate", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
