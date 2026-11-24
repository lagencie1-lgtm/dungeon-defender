"""The Ranger defender, painted version: a round stone watchtower with a wooden lookout, a green shingled
cone roof with a pennant, and a green-hooded archer. Front (door, archer's bow) faces -Y.
Footprint about 6 studs, about 14 studs tall. Textures from art/textures, baked by paint.bake().
Run: blender -b -P tower_ranger.py -- out.fbx   (also writes out_paint.png next to it)"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402

WHITE = (1, 1, 1)
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


def smooth(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    return obj


# --- stone base: a plinth and a tapering round tower ---------------------------------------------
plinth = lib.cone("Plinth", 2.95, 0.7, (0, 0, 0.35), WHITE, vertices=12, radius_top=2.75)
paint.paint(bevel(plinth, 0.12), "stone", (0.82, 0.80, 0.78), 2.5)
base = lib.cone("Base", 2.55, 4.3, (0, 0, 2.85), WHITE, vertices=14, radius_top=2.2)
paint.paint(smooth(bevel(base, 0.1)), "stone", WHITE, 2.5)
# a band of stones at the top, flaring out, with corbels holding the lookout
band = lib.cone("Band", 2.45, 0.5, (0, 0, 5.15), WHITE, vertices=14, radius_top=2.7)
paint.paint(bevel(band, 0.08), "stone", (0.78, 0.76, 0.74), 2.0)
for i in range(8):
    a = i / 8 * math.pi * 2 + math.pi / 8
    c = lib.box(f"Corbel{i}", (0.55, 0.55, 0.6), (math.cos(a) * 2.45, math.sin(a) * 2.45, 4.8), WHITE,
                rotation=(0, 0, a))
    paint.paint(bevel(c, 0.08), "stone", (0.8, 0.78, 0.76), 2.0)

# arched door and two window slits
door = lib.box("Door", (1.3, 0.5, 2.0), (0, -2.42, 1.7), WHITE, rotation=(math.radians(-4.5), 0, 0))
paint.paint(bevel(door, 0.12), "wood_dark", WHITE, 2.0)
door_arch = lib.cylinder("DoorArch", 0.65, 0.5, (0, -2.36, 2.7), WHITE, vertices=12, rotation=(math.radians(90), 0, 0))
paint.paint(door_arch, "wood_dark", WHITE, 2.0)
frame = lib.cylinder("DoorFrame", 0.85, 0.36, (0, -2.3, 2.7), WHITE, vertices=12, rotation=(math.radians(90), 0, 0))
paint.paint(frame, "stone", (0.7, 0.68, 0.66), 1.5)
ring = lib.cylinder("DoorRing", 0.12, 0.08, (0.35, -2.72, 1.7), WHITE, vertices=8, rotation=(math.radians(90), 0, 0))
paint.paint(ring, "brass", WHITE, 1.0)
for k, (x, y) in enumerate([(2.32, -0.4), (-2.32, 0.6)]):
    slit = lib.box(f"Slit{k}", (0.3, 0.32, 0.9), (x, y, 3.6), WHITE)
    paint.paint(slit, None, (0.12, 0.09, 0.08))

# --- wooden lookout ---------------------------------------------------------------------------------
floor = lib.cylinder("Floor", 3.05, 0.4, (0, 0, 5.55), WHITE, vertices=14)
paint.paint(bevel(floor, 0.1), "wood", WHITE, 2.0)
trim = lib.cylinder("FloorTrim", 3.12, 0.16, (0, 0, 5.38), WHITE, vertices=14)
paint.paint(trim, "brass", WHITE, 1.5)
POSTS = 7
for i in range(POSTS):
    a = i / POSTS * math.pi * 2 + math.pi / 2
    x, y = math.cos(a) * 2.75, math.sin(a) * 2.75
    p = lib.box(f"Post{i}", (0.34, 0.34, 3.4), (x, y, 7.4), WHITE, rotation=(0, 0, a))
    paint.paint(bevel(p, 0.06), "wood_dark", WHITE, 2.0)
    # a low wall and rail to the next post, open at the front where the archer shoots
    b = (i + 1) / POSTS * math.pi * 2 + math.pi / 2
    mid = (a + b) / 2
    if math.sin(mid) < -0.8:
        continue
    length = 2 * 2.75 * math.sin((b - a) / 2)
    r = lib.box(f"Rail{i}", (length, 0.18, 0.2), (math.cos(mid) * 2.62, math.sin(mid) * 2.62, 6.75), WHITE,
                rotation=(0, 0, mid + math.pi / 2))
    paint.paint(r, "wood", WHITE, 2.0)
    w = lib.box(f"Wall{i}", (length - 0.25, 0.14, 0.9), (math.cos(mid) * 2.66, math.sin(mid) * 2.66, 6.2),
                WHITE, rotation=(0, 0, mid + math.pi / 2))
    paint.paint(w, "wood", (0.92, 0.88, 0.84), 1.6)

# --- cone roof with an overhang, a brass finial and a pennant ------------------------------------------
roof = lib.cone("Roof", 3.75, 3.4, (0, 0, 10.6), WHITE, vertices=14, radius_top=0.15)
paint.paint(smooth(roof), "roof", WHITE, 1.8)
eave = lib.cone("Eave", 3.85, 0.3, (0, 0, 8.95), WHITE, vertices=14, radius_top=3.6)
paint.paint(eave, "wood_dark", WHITE, 1.5)
finial = lib.sphere("Finial", 0.32, (0, 0, 12.45), WHITE, segments=12)
paint.paint(finial, "brass", WHITE, 1.0)
pole = lib.cylinder("Pole", 0.07, 1.6, (0, 0, 13.2), WHITE, vertices=6)
paint.paint(pole, "wood_dark", WHITE, 1.0)
flag = lib.box("Pennant", (1.3, 0.05, 0.6), (0.68, 0, 13.65), WHITE, rotation=(0, math.radians(-8), 0))
paint.paint(flag, "cloth", (0.45, 0.78, 0.38), 1.0)

# --- the archer, standing at the front gap with a drawn bow --------------------------------------------
legs = lib.cone("Legs", 0.45, 0.8, (0, -1.5, 6.15), WHITE, vertices=10, radius_top=0.38)
paint.paint(legs, "cloth", (0.45, 0.32, 0.22), 1.0)
cloak = lib.cone("Cloak", 0.72, 1.4, (0, -1.5, 7.1), WHITE, vertices=12, radius_top=0.38)
paint.paint(smooth(cloak), "cloth", (0.42, 0.72, 0.36), 1.0)
face = lib.sphere("Face", 0.36, (0, -1.6, 8.05), WHITE, segments=14)
paint.paint(face, None, (0.96, 0.78, 0.62))
hood = lib.cone("Hood", 0.48, 0.85, (0, -1.42, 8.3), WHITE, vertices=12, radius_top=0.05)
hood.rotation_euler = (math.radians(-12), 0, 0)
paint.paint(smooth(hood), "cloth", (0.34, 0.6, 0.3), 1.0)
bow = lib.box("Bow", (0.12, 0.12, 2.0), (0.42, -2.05, 7.3), WHITE, rotation=(0, math.radians(8), 0))
paint.paint(bow, "wood_dark", WHITE, 1.0)
arrow = lib.box("Arrow", (0.06, 1.4, 0.06), (0.25, -2.0, 7.35), WHITE)
paint.paint(arrow, None, (0.95, 0.9, 0.78))
quiver = lib.cylinder("Quiver", 0.18, 0.8, (-0.3, -1.1, 7.4), WHITE, vertices=8, rotation=(math.radians(15), 0, 0))
paint.paint(quiver, "wood", WHITE, 1.0)

if "--" in sys.argv:
    out = sys.argv[sys.argv.index("--") + 1]
else:
    out = os.path.join(os.path.dirname(__file__), "..", "models", "tower_ranger.fbx")
out = os.path.abspath(out)
parts = paint.bake("tower_ranger", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
