"""Painted hero gear, one model per run: weapons (handle at the bottom, pointing up +Z), head pieces (front -Y,
sized to sit on a Roblox head 1.2 studs wide) and body pieces (around a torso 2 wide, 2 tall, 1 deep, centred).
Run: blender -b -P gear.py -- out.fbx <kind>
kinds: sword_long sword_great sword_twin staff bow wrench | hat_wizard helm hood crown goggles |
       chestplate tunic mail quiver pack"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel, smooth  # noqa: E402

W = (1, 1, 1)
GLOW = (1.0, 1.0, 1.0)  # c_255_255_255: the game tints these parts (rarity colour or weapon skin)
args = sys.argv[sys.argv.index("--") + 1:]
out, kind = os.path.abspath(args[0]), args[1]
lib.reset()
paint.setup()


def P(obj, key, tint=W, scale=1.0):
    return paint.paint(obj, key, tint, scale)


def sword(length, width, guard):
    P(smooth(lib.cylinder("Grip", 0.11, 0.8, (0, 0, 0.4), W, vertices=8)), "wood_dark", W, 0.6)
    P(smooth(lib.sphere("Pommel", 0.17, (0, 0, 0.0), W, segments=10)), "brass", W, 0.5)
    P(bevel(lib.box("Guard", (guard, 0.2, 0.16), (0, 0, 0.88), W), 0.04), "brass", W, 0.5)
    blade = lib.box("Blade", (width, 0.08, length), (0, 0, 0.96 + length / 2), W)
    P(bevel(blade, 0.03), "iron", (1.25, 1.25, 1.3), 1.2)
    tip = lib.cone("Tip", width / 2, width * 1.1, (0, 0, 0.96 + length + width * 0.55), W, vertices=4)
    tip.scale = (1, 0.16, 1)
    tip.rotation_euler = (0, 0, math.radians(45))
    P(tip, "iron", (1.25, 1.25, 1.3), 1.2)
    # the fuller down the middle glows in the item's rarity colour
    paint.glow(lib.box("Fuller", (width * 0.22, 0.1, length * 0.8), (0, 0, 0.96 + length * 0.45), W), GLOW)


if kind == "sword_long":
    sword(3.4, 0.36, 1.1)
elif kind == "sword_great":
    sword(5.0, 0.62, 1.7)
elif kind == "sword_twin":
    sword(2.3, 0.3, 0.8)
elif kind == "staff":
    P(smooth(lib.cylinder("Shaft", 0.1, 5.2, (0, 0, 2.6), W, vertices=8)), "wood", W, 1.0)
    for i in range(3):
        a = i / 3 * math.pi * 2
        claw = lib.cone(f"Claw{i}", 0.09, 0.9, (math.cos(a) * 0.3, math.sin(a) * 0.3, 5.5), W, vertices=6)
        claw.rotation_euler = (-math.sin(a) * 0.5, math.cos(a) * 0.5, 0)
        P(claw, "brass", W, 0.5)
    P(lib.cylinder("Band", 0.14, 0.2, (0, 0, 4.9), W, vertices=8), "brass", W, 0.5)
    paint.glow(smooth(lib.sphere("Orb", 0.42, (0, 0, 5.75), W, segments=14)), GLOW)
elif kind == "bow":
    # a recurve bow standing up (grip in the middle), string behind (+Y)
    P(smooth(lib.cylinder("Grip", 0.13, 0.9, (0, 0, 0), W, vertices=8)), "wood_dark", W, 0.6)
    for side in (-1, 1):
        for i, (z, y, rot) in enumerate(((0.9, -0.05, 12), (1.6, -0.22, 26), (2.15, -0.32, -18))):
            limb = lib.box(f"Limb{side}{i}", (0.16, 0.12, 0.85), (0, y, side * z), W, rotation=(math.radians(side * rot), 0, 0))
            P(bevel(limb, 0.03), "wood", W, 0.8)
        P(lib.sphere(f"Cap{side}", 0.1, (0, -0.2, side * 2.5), W, segments=8), "brass", W, 0.4)
    paint.glow(lib.box("String", (0.03, 0.03, 4.9), (0, 0.12, 0), W), GLOW)
elif kind == "wrench":
    P(bevel(lib.box("Handle", (0.3, 0.14, 2.6), (0, 0, 1.3), W), 0.04), "iron", W, 0.8)
    P(lib.cylinder("GripWrap", 0.2, 0.9, (0, 0, 0.5), W, vertices=8), "wood_dark", W, 0.5)
    head = lib.cylinder("Head", 0.55, 0.2, (0, 0, 2.9), W, vertices=12, rotation=(math.radians(90), 0, 0))
    P(bevel(head, 0.03), "iron", (1.15, 1.15, 1.2), 0.8)
    paint.glow(lib.box("Jaw", (0.36, 0.24, 0.5), (0, 0, 3.25), W), GLOW)
elif kind == "hat_wizard":
    brim = lib.cylinder("Brim", 1.15, 0.1, (0, 0, 0.05), W, vertices=18)
    P(brim, "cloth", (0.42, 0.3, 0.7), 0.8)
    cone = lib.cone("Cone", 0.68, 1.5, (0, 0.05, 0.85), W, vertices=14, radius_top=0.05)
    cone.rotation_euler = (math.radians(8), 0, 0)
    P(smooth(cone), "cloth", (0.42, 0.3, 0.7), 0.8)
    P(lib.cylinder("Band", 0.7, 0.2, (0, 0, 0.2), W, vertices=14), "brass", W, 0.5)
    paint.glow(lib.sphere("Star", 0.12, (0, -0.68, 0.22), W, segments=8), GLOW)
elif kind == "helm":
    dome = lib.sphere("Dome", 0.82, (0, 0, 0.35), W, segments=14)
    dome.scale = (1, 1.05, 0.95)
    P(smooth(dome), "iron", (1.1, 1.1, 1.15), 0.8)
    P(lib.box("Visor", (0.9, 0.12, 0.14), (0, -0.82, 0.3), W), None, (0.06, 0.05, 0.06))
    P(lib.box("Ridge", (0.14, 1.5, 0.14), (0, 0, 1.08), W), "brass", W, 0.5)
    P(lib.cylinder("Rim", 0.86, 0.14, (0, 0, -0.2), W, vertices=14), "brass", W, 0.5)
    paint.glow(lib.cone("Plume", 0.16, 0.7, (0, 0.4, 1.4), W, vertices=6), GLOW)
elif kind == "hood":
    # sits on the back and top of the head, so the hero's own face stays visible in front
    hood = lib.sphere("Hood", 0.84, (0, 0.42, 0.28), W, segments=14)
    hood.scale = (1.04, 0.8, 1.06)
    P(smooth(hood), "cloth", (0.35, 0.58, 0.32), 0.8)
    brow = lib.cylinder("Brow", 0.8, 0.5, (0, 0.05, 0.92), W, vertices=14)
    brow.scale = (1, 0.95, 0.5)
    P(smooth(brow), "cloth", (0.3, 0.5, 0.28), 0.8)
    P(lib.cone("Peak", 0.38, 0.6, (0, 0.85, 0.95), W, vertices=8), "cloth", (0.35, 0.58, 0.32), 0.8)
    paint.glow(lib.sphere("Clasp", 0.11, (0, -0.2, 1.05), W, segments=8), GLOW)
elif kind == "crown":
    P(lib.cylinder("Band", 0.72, 0.3, (0, 0, 0.15), W, vertices=16), "brass", (1.1, 1.05, 0.9), 0.5)
    for i in range(6):
        a = i / 6 * math.pi * 2
        P(lib.cone(f"Point{i}", 0.16, 0.5, (math.cos(a) * 0.66, math.sin(a) * 0.66, 0.5), W, vertices=4), "brass", (1.1, 1.05, 0.9), 0.5)
        if i % 2 == 0:
            paint.glow(lib.sphere(f"Gem{i}", 0.1, (math.cos(a) * 0.74, math.sin(a) * 0.74, 0.18), W, segments=8), GLOW)
elif kind == "goggles":
    P(lib.cylinder("Strap", 0.78, 0.22, (0, 0, 0), W, vertices=16), "wood_dark", W, 0.5)
    for side in (-1, 1):
        ring = lib.cylinder(f"Ring{side}", 0.27, 0.16, (side * 0.3, -0.74, 0), W, vertices=12, rotation=(math.radians(90), 0, 0))
        P(ring, "brass", W, 0.4)
        paint.glow(lib.cylinder(f"Lens{side}", 0.2, 0.18, (side * 0.3, -0.76, 0), W, vertices=12, rotation=(math.radians(90), 0, 0)), GLOW)
elif kind in ("chestplate", "tunic", "mail"):
    key, tint = {"chestplate": ("iron", (1.1, 1.1, 1.15)), "tunic": ("cloth", (0.4, 0.62, 0.36)), "mail": ("iron", (0.8, 0.8, 0.86))}[kind]
    shell = lib.box("Shell", (2.18, 1.2, 2.05), (0, 0, 0), W)
    P(bevel(shell, 0.22, 3), key, tint, 1.0)
    P(lib.box("Belt", (2.24, 1.26, 0.26), (0, 0, -0.72), W), "wood_dark", W, 0.6)
    P(lib.box("Buckle", (0.4, 0.1, 0.32), (0, -0.66, -0.72), W), "brass", W, 0.4)
    if kind == "chestplate":
        for side in (-1, 1):
            P(smooth(lib.sphere(f"Pauldron{side}", 0.55, (side * 1.25, 0, 0.85), W, segments=12)), "iron", tint, 0.8)
            P(lib.cylinder(f"Trim{side}", 0.56, 0.1, (side * 1.25, 0, 0.62), W, vertices=12), "brass", W, 0.4)
    elif kind == "mail":
        P(lib.cylinder("Collar", 0.75, 0.25, (0, 0, 1.02), W, vertices=14), "brass", W, 0.5)
    paint.glow(lib.sphere("Emblem", 0.2, (0, -0.64, 0.35), W, segments=8), GLOW)
elif kind == "quiver":
    q = lib.cylinder("Quiver", 0.3, 2.0, (0, 0, 1.0), W, vertices=10)
    P(smooth(q), "wood_dark", W, 0.8)
    P(lib.cylinder("Rim", 0.33, 0.14, (0, 0, 1.95), W, vertices=10), "brass", W, 0.4)
    for i, (x, y) in enumerate(((0.1, 0.05), (-0.1, 0.08), (0, -0.1))):
        P(lib.cylinder(f"Shaft{i}", 0.03, 0.9, (x, y, 2.4), W, vertices=5), "wood", W, 0.5)
        paint.glow(lib.cone(f"Fletch{i}", 0.1, 0.3, (x, y, 2.75), W, vertices=4), GLOW)
elif kind == "pack":
    P(bevel(lib.box("Pack", (1.5, 0.8, 1.7), (0, 0, 0.85), W), 0.12), "wood", (0.9, 0.75, 0.55), 1.0)
    P(lib.box("Lid", (1.56, 0.86, 0.22), (0, 0, 1.75), W), "brass", W, 0.6)
    for side in (-1, 1):
        P(lib.cylinder(f"Tank{side}", 0.24, 1.3, (side * 0.95, 0, 0.9), W, vertices=10), "iron", W, 0.8)
    paint.glow(lib.cylinder("Gauge", 0.22, 0.1, (0, 0.44, 1.1), W, vertices=12, rotation=(math.radians(90), 0, 0)), GLOW)
    P(lib.cylinder("Pipe", 0.07, 0.9, (0.4, 0, 2.2), W, vertices=6), "iron", W, 0.5)

parts = paint.bake("gear_" + kind, out[:-4] + "_paint.png", 256)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
