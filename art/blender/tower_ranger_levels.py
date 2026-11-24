"""The Ranger at its three levels, built to match the Codex target pictures art/ref3d/tower_ranger_l1..l3.png
(docs/tower-pipeline.md). Sizes come from the pictures' width profiles (scripts/profile.py): heights 10.1 / 15.65 /
17.7 studs. The front (the archer's side) faces -Y. Run: blender -b -P tower_ranger_levels.py -- out.fbx <1|2|3>"""
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sculpt as S  # noqa: E402
from sculpt import ball, cone, limb, chain, rad, glow_ball, box  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, level = args[0], int(args[1])
S.start()
W = (1, 1, 1)
rnd = random.Random(level)
STONE = (1.0, 0.86, 0.66)       # warm pale stone (the pictures are warmer and lighter than the old model)
WOOD = (0.7, 0.5, 0.36)
ROOF = (0.86, 0.45, 0.36)       # red-brown shingles
GREEN = (0.32, 0.62, 0.26)
CREAM = (0.97, 0.92, 0.8)
BRASS = (1.0, 0.78, 0.36)


def tcone(name, pos, r, h, key, tint=W, top=None, verts=16, rot=(0, 0, 0), tile=2.0):
    if top is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=pos, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=top, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = min(0.08, r * 0.1)
    mod.segments = 2
    mod.limit_method = "ANGLE"
    mod.angle_limit = rad(50)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return S.textured(o, key, tint, tile)


def footing(r, h):
    """the round cut-stone footing with grass and pebbles round it (one family for all levels)"""
    tcone("Footing", (0, 0, h / 2), r, h, "stone", STONE, top=r * 0.92, verts=22, tile=2.2)
    for i in range(12):
        a = rad(i * 30 + rnd.uniform(-8, 8))
        if i % 3 == 0:
            ball(f"Pebble{i}", (math.cos(a) * (r + 0.2), math.sin(a) * (r + 0.2), 0.16), 0.3, (0.8, 0.78, 0.74), (1.2, 1, 0.7), seg=6)
        else:
            for k in range(3):
                cone(f"Grass{i}{k}", (math.cos(a) * (r + 0.05) + (k - 1) * 0.14, math.sin(a) * (r + 0.05), 0.25), 0.08, 0.6,
                     (0.42, 0.7, 0.24), (rad((k - 1) * 14), rad((k - 1) * 12), 0), verts=4)


def archer(x, y, z, s=1.0):
    """a hooded green archer with a drawn bow, facing -Y"""
    ball("Legs", (x, y, z + 0.4 * s), 0.34 * s, (0.4, 0.27, 0.17), (1, 0.9, 1.3), seg=10)
    cone("Cloak", (x, y, z + 1.1 * s), 0.62 * s, 1.3 * s, GREEN, top=0.3 * s, verts=12)
    ball("Head", (x, y - 0.04 * s, z + 1.95 * s), 0.36 * s, (0.98, 0.8, 0.64), seg=14)
    ball("Hood", (x, y + 0.08 * s, z + 2.02 * s), 0.43 * s, GREEN, (1.0, 1.0, 1.02), seg=14)
    cone("HoodTip", (x, y + 0.3 * s, z + 2.42 * s), 0.2 * s, 0.4 * s, GREEN, (rad(-40), 0, 0), verts=8)
    chain("Bow", [(x + 0.5 * s, y - 0.6 * s, z + 1.1 * s), (x + 0.62 * s, y - 0.75 * s, z + 1.6 * s),
                  (x + 0.62 * s, y - 0.75 * s, z + 2.1 * s), (x + 0.5 * s, y - 0.6 * s, z + 2.6 * s)],
          [0.05 * s, 0.06 * s, 0.06 * s, 0.05 * s], (0.45, 0.28, 0.15), seg=6)
    limb("Arrow", (x + 0.5 * s, y + 0.1 * s, z + 1.85 * s), (x + 0.5 * s, y - 1.3 * s, z + 1.85 * s), 0.025 * s, 0.025 * s,
         (0.95, 0.9, 0.76), verts=4, end=False)


def ring_rail(z, r, gap_front=True, posts=8, h=1.0, key="wood", corner_brass=True):
    """a round wooden parapet with brass corner plates"""
    for i in range(posts):
        a = rad(i * 360 / posts + 90)
        x, y = math.cos(a) * r, math.sin(a) * r
        box(f"RailPost{z}{i}", (x, y, z + h / 2), (0.34, 0.34, h + 0.2), WOOD, rot=(0, 0, a), key="wood_dark", tile=1.2)
        if corner_brass:
            box(f"RailBrass{z}{i}", (x * 1.03, y * 1.03, z + h * 0.75), (0.42, 0.1, 0.42), BRASS, rot=(0, 0, a + rad(90)), key="brass", tile=1.0)
        b = rad((i + 0.5) * 360 / posts + 90)
        if gap_front and abs(((i + 0.5) * 360 / posts + 90) % 360 - 270) < 360 / posts / 2:
            continue
        ln = 2 * r * math.sin(rad(180 / posts))
        box(f"RailPlank{z}{i}", (math.cos(b) * r, math.sin(b) * r, z + h * 0.45), (ln, 0.22, h * 0.8), WOOD,
            rot=(0, 0, b + rad(90)), key="wood", tile=1.6)


def shingle_roof(z0, r, h, sides=8, ribs=False, flare=0.0):
    """a shingled cone; flare > 0 gives the pictures' bell shape: a wide shallow skirt under a steeper top"""
    tcone("Eave", (0, 0, z0), r + 0.15, 0.3, "wood_dark", WOOD, top=r, verts=sides * 2)
    if flare > 0:
        skirt = h * flare
        mid = r * 0.52
        tcone("RoofSkirt", (0, 0, z0 + skirt / 2 + 0.15), r, skirt, "wood", ROOF, top=mid, verts=sides * 2, tile=1.2)
        tcone("Roof", (0, 0, z0 + skirt + (h - skirt) / 2 + 0.1), mid, h - skirt, "wood", ROOF, top=0.18, verts=sides * 2, tile=1.2)
    else:
        tcone("Roof", (0, 0, z0 + h / 2 + 0.15), r, h, "wood", ROOF, top=0.18, verts=sides * 2, tile=1.2)
    if ribs:
        for i in range(sides):
            a = rad(i * 360 / sides + 22.5)
            limb(f"Rib{i}", (math.cos(a) * r, math.sin(a) * r, z0 + 0.2), (0, 0, z0 + h + 0.1), 0.12, 0.08, BRASS, verts=6)


def banner(x, y, z, w, h, facing, emblem=True):
    box("Banner", (x, y, z), (w, 0.08, h), CREAM, rot=(0, 0, facing), key="cloth", tile=1.2)
    box("BannerEdge", (x, y, z), (w * 1.06, 0.06, h * 1.02), GREEN, rot=(0, 0, facing))
    cone("BannerTip", (x, y, z - h / 2 - 0.25), w * 0.53, 0.5, CREAM, (rad(180), 0, facing), verts=3)
    if emblem:
        ball("Leaf", (x - math.sin(facing) * 0.1, y - math.cos(facing) * 0.1, z), w * 0.2, GREEN, (1, 0.3, 1.6), (0, 0, facing), seg=8)


def door(z, r, w=1.4, h=2.2):
    y = -r + 0.05
    box("Door", (0, y, z + h / 2), (w, 0.3, h), WOOD, key="wood_dark", tile=1.4)
    tcone("DoorTop", (0, y, z + h), w / 2, 0.3, "wood_dark", WOOD, verts=14, rot=(rad(90), 0, 0))
    tcone("DoorArch", (0, y + 0.05, z + h), w / 2 + 0.35, 0.36, "stone", STONE, verts=14, rot=(rad(90), 0, 0))
    ball("Ring", (0.35, y - 0.2, z + h * 0.45), 0.14, BRASS, seg=8)
    for k in range(2):
        box(f"Step{k}", (0, y - 0.4 - k * 0.35, 0.15 + (1 - k) * 0.25), (w + 0.8 - k * 0.2, 0.5, 0.3), STONE, key="stone", tile=1.0)


def ivy(r, z0, z1, a0, n):
    for i in range(n):
        a = rad(a0 + rnd.uniform(-12, 12))
        z = z0 + (z1 - z0) * i / max(1, n - 1)
        ball(f"Ivy{a0}{i}", (math.cos(a) * r, math.sin(a) * r, z), rnd.uniform(0.25, 0.38), (0.36, 0.66, 0.26) if i % 2 else (0.28, 0.55, 0.22), (1, 0.5, 1.1), seg=6)


# ---------------------------------------------------------------------------------------------------------------
if level == 1:
    # a small wooden watch post: stone footing, four braced legs, a plank box lookout, a short gable roof, a ladder
    footing(3.9, 1.0)
    for x in (-2.2, 2.2):
        for y in (-2.2, 2.2):
            box(f"Leg{x}{y}", (x * 0.85, y * 0.85, 2.6), (0.5, 0.5, 3.4), WOOD, key="wood_dark", tile=1.6)
            box(f"LegBrass{x}{y}", (x, y, 1.4), (0.55, 0.55, 0.35), BRASS, key="brass", tile=1.0)
    for y in (-1.9, 1.9):
        box(f"Cross{y}", (0, y, 2.6), (3.6, 0.22, 0.3), WOOD, rot=(0, rad(38), 0), key="wood_dark", tile=1.4)
    box("Floor", (0, 0, 4.3), (5.4, 5.4, 0.35), WOOD, key="wood", tile=1.6)
    for side in range(4):
        a = rad(side * 90)
        x, y = math.cos(a) * 2.6, math.sin(a) * 2.6
        box(f"Box{side}", (x, y, 5.15), (0.35 if abs(x) > 1 else 5.5, 5.5 if abs(x) > 1 else 0.35, 1.7), WOOD, key="wood", tile=1.4)
    for x in (-2.6, 2.6):
        for y in (-2.6, 2.6):
            box(f"BoxBrass{x}{y}", (x, y, 5.6), (0.6, 0.6, 0.6), BRASS, key="brass", tile=1.0)
            box(f"RoofPost{x}{y}", (x * 0.62, y * 0.62, 7.3), (0.36, 0.36, 3.4), WOOD, key="wood_dark", tile=1.4)
    for s in (-1, 1):
        box(f"Gable{s}", (s * 1.85, 0, 8.85), (4.6, 6.0, 0.4), ROOF, rot=(0, rad(s * 34), 0), key="wood", tile=1.2)
        box(f"GableEnd{s}", (0, s * 2.7, 8.7), (3.6, 0.3, 1.6), WOOD, key="wood_dark", tile=1.2)
    box("Ridge", (0, 0, 10.15), (0.5, 6.2, 0.5), WOOD, key="wood_dark", tile=1.4)
    for k in range(4):
        box(f"Rung{k}", (1.3, -3.1, 1.7 + k * 0.75), (1.0, 0.16, 0.16), WOOD, key="wood", tile=1.0)
    for x in (0.85, 1.75):
        box(f"Rail{x}", (x, -3.1, 2.9), (0.18, 0.18, 3.4), WOOD, rot=(rad(-8), 0, 0), key="wood_dark", tile=1.2)
    archer(0, -0.8, 4.45)
    S.finish("tower_ranger_l1", out, triangles=6000)
elif level == 2:
    # a round warm-stone tower with ivy, an arched door and a banner, a timber lookout with brass corners, red cone roof
    footing(4.0, 1.3)
    tcone("Tower", (0, 0, 4.3), 3.2, 6.0, "stone", STONE, top=2.95, verts=22, tile=2.4)
    door(1.3, 3.15)
    ivy(3.0, 2.0, 6.5, 205, 6)
    ivy(3.0, 2.0, 5.8, 330, 5)
    tcone("LookoutFloor", (0, 0, 7.35), 3.35, 0.4, "wood", WOOD, verts=20, tile=2.0)
    ring_rail(7.5, 3.3, gap_front=False, posts=8, h=1.4)
    for i in range(6):
        a = rad(i * 60 + 30)
        box(f"Post{i}", (math.cos(a) * 2.55, math.sin(a) * 2.55, 9.4), (0.32, 0.32, 2.6), WOOD, key="wood_dark", tile=1.4)
    banner(0.0, -3.15, 6.0, 1.3, 1.9, 0)
    shingle_roof(10.3, 3.75, 4.3, sides=8, flare=0.35)
    ball("Finial", (0, 0, 14.75), 0.36, BRASS, seg=10)
    limb("Pole", (0, 0, 14.75), (0, 0, 15.65), 0.08, 0.07, (0.4, 0.28, 0.16), verts=6)
    S.membrane("Pennant", [(0, 0, 15.75), (3.4, 0.1, 15.55), (0, 0, 14.75), (1.7, 0.05, 15.2)], [(0, 1, 3), (3, 1, 2), (0, 3, 2)], GREEN, 0.05)
    archer(0, -1.4, 7.55)
    S.finish("tower_ranger_l2", out, triangles=7000)
else:
    # taller: a second stone storey with windows and a brass band, two banners, a wide lookout with two archers,
    # a roof with brass ribs and a glowing green gem on a brass crown
    footing(5.2, 1.8)
    tcone("Tower", (0, 0, 4.6), 4.5, 5.6, "stone", STONE, top=4.2, verts=24, tile=2.4)
    door(1.8, 4.4, w=1.8, h=2.7)
    tcone("Band", (0, 0, 7.5), 4.3, 0.6, "brass", BRASS, verts=24, tile=1.2)
    for i in range(10):
        a = rad(i * 36)
        ball(f"Stud{i}", (math.cos(a) * 4.35, math.sin(a) * 4.35, 7.5), 0.15, BRASS, seg=6)
    tcone("Storey2", (0, 0, 9.1), 4.1, 2.8, "stone", STONE, top=3.9, verts=24, tile=2.4)
    for a in (230, 310):
        ar = rad(a)
        box(f"Window{a}", (math.cos(ar) * 3.4, math.sin(ar) * 3.4, 9.0), (0.8, 0.4, 1.0), (0.15, 0.1, 0.08), rot=(0, 0, ar + rad(90)))
        tcone(f"WindowArch{a}", (math.cos(ar) * 3.45, math.sin(ar) * 3.45, 9.55), 0.55, 0.4, "stone", STONE, verts=12,
              rot=(rad(90), 0, ar + rad(90)))
    ivy(3.8, 2.2, 9.5, 200, 7)
    ivy(3.8, 2.2, 9.0, 340, 6)
    for x in (-2.6, 2.6):
        banner(x, -3.0, 5.0, 1.25, 2.3, rad(x * 9))
    tcone("LookoutFloor", (0, 0, 10.55), 4.0, 0.45, "wood", WOOD, verts=24, tile=2.0)
    ring_rail(10.75, 3.95, gap_front=False, posts=10, h=1.3)
    for i in range(3):
        a = rad(240 + i * 30)
        x, y = math.cos(a) * 4.02, math.sin(a) * 4.02
        box(f"Swag{i}", (x, y, 11.6), (2.2, 0.12, 0.6), GREEN, rot=(0, 0, a + rad(90)), key="cloth", tile=1.0)
    for i in range(8):
        a = rad(i * 45 + 22.5)
        box(f"Post{i}", (math.cos(a) * 3.7, math.sin(a) * 3.7, 12.7), (0.38, 0.38, 2.6), WOOD, key="wood_dark", tile=1.4)
    shingle_roof(13.9, 4.8, 3.9, sides=8, ribs=True)
    cone("Crown", (0, 0, 17.95), 0.6, 0.55, BRASS, top=0.4, verts=8)
    glow_ball("Gem", (0, 0, 18.7), 0.5, (0.35, 1.0, 0.35), (1, 1, 1.5), seg=8)
    archer(-1.1, -2.0, 10.8)
    archer(1.1, -2.0, 10.8)
    S.finish("tower_ranger_l3", out, triangles=8000)
