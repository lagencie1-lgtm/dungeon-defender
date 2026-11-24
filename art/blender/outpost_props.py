"""The Outpost's painted props, one model per run: forge, stall, altar, mapboard, questboard, chest, nest, campfire.
Front faces -Y. Run: blender -b -P outpost_props.py -- out.fbx <name>   (writes outpost_<name>_paint.png next to it)"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel, smooth  # noqa: E402

W = (1, 1, 1)
args = sys.argv[sys.argv.index("--") + 1:]
out, name = os.path.abspath(args[0]), args[1]
rnd = random.Random(1)
lib.reset()
paint.setup()


def post(x, y, h, r=0.3, key="wood_dark"):
    p = lib.box(f"Post{x}{y}", (r * 2, r * 2, h), (x, y, h / 2), W)
    paint.paint(bevel(p, 0.05), key, W, 1.5)


def crate(x, y, z, s):
    c = lib.box(f"Crate{x}{y}{z}", (s, s, s), (x, y, z + s / 2), W, rotation=(0, 0, rnd.uniform(-0.3, 0.3)))
    paint.paint(bevel(c, 0.06), "wood", W, 1.2)


if name == "forge":
    # stone forge with a chimney, glowing coals, an anvil on a stump, a quench barrel
    paint.paint(bevel(lib.box("Forge", (6, 4.5, 3.2), (0, 1, 1.6), W), 0.2), "stone", W, 2.0)
    paint.paint(bevel(lib.box("Chimney", (2.4, 2.4, 6), (1.6, 2.2, 5.5), W), 0.15), "stone", (0.85, 0.82, 0.8), 2.0)
    paint.paint(lib.box("ChimneyCap", (2.9, 2.9, 0.4), (1.6, 2.2, 8.6), W), "iron", W, 1.0)
    paint.glow(lib.box("Coals", (3.6, 2.6, 0.3), (-0.6, 0.3, 3.25), W), (1.0, 0.5, 0.12))
    paint.paint(lib.box("Hood", (4.0, 3.0, 0.3), (-0.6, 0.6, 5.2), W, rotation=(0.25, 0, 0)), "iron", W, 1.2)
    stump = lib.cylinder("Stump", 0.9, 1.6, (-1.2, -3.2, 0.8), W, vertices=10)
    paint.paint(smooth(stump), "bark", W, 1.5)
    anvil = lib.box("Anvil", (2.2, 0.9, 0.7), (-1.2, -3.2, 2.0), W)
    paint.paint(bevel(anvil, 0.1), "iron", W, 1.0)
    horn = lib.cone("Horn", 0.45, 1.0, (-2.7, -3.2, 2.05), W, vertices=8)
    horn.rotation_euler = (0, math.radians(-90), 0)
    paint.paint(horn, "iron", W, 1.0)
    barrel = lib.cylinder("Barrel", 0.9, 1.8, (2.6, -2.4, 0.9), W, vertices=12)
    paint.paint(smooth(barrel), "wood", W, 1.2)
    for z in (0.4, 1.4):
        paint.paint(lib.cylinder(f"Hoop{z}", 0.95, 0.15, (2.6, -2.4, z), W, vertices=12), "iron", W, 1.0)
    paint.glow(lib.cylinder("Water", 0.8, 0.05, (2.6, -2.4, 1.78), W, vertices=12), (0.35, 0.7, 1.0))
elif name == "stall":
    # a market stall with a striped canopy, a counter, crates and glittering gems
    for x in (-3, 3):
        for y in (-1.5, 1.5):
            post(x, y, 5.5, 0.22)
    paint.paint(bevel(lib.box("Counter", (6.8, 1.6, 2.2), (0, -1.8, 1.1), W), 0.1), "wood", W, 1.5)
    paint.paint(lib.box("CounterTop", (7.2, 1.9, 0.25), (0, -1.8, 2.3), W), "wood_dark", W, 1.5)
    for i in range(6):
        stripe = lib.box(f"Canopy{i}", (1.25, 4.4, 0.15), (-3.1 + i * 1.24, -0.3, 5.9), W, rotation=(0.22, 0, 0))
        paint.paint(stripe, "cloth", (0.35, 0.6, 0.95) if i % 2 else W, 1.5)
    for i, (x, col) in enumerate(((-2, (0.35, 0.86, 1.0)), (-0.6, (0.75, 0.45, 1.0)), (0.9, (0.4, 1.0, 0.6)), (2.2, (1.0, 0.8, 0.3)))):
        gem = lib.cone(f"Gem{i}", 0.35, 0.7, (x, -1.8, 2.75), W, vertices=6)
        paint.glow(gem, col)
    crate(2.5, 1.0, 0, 1.4)
    crate(2.4, 1.1, 1.4, 1.0)
    crate(-2.6, 1.2, 0, 1.2)
elif name == "altar":
    # a round stone plinth with a heroic statue raising a sword, green runes around the base
    paint.paint(bevel(lib.cylinder("Plinth", 3.2, 1.0, (0, 0, 0.5), W, vertices=20), 0.12), "stone", (0.85, 0.85, 0.82), 2.0)
    paint.paint(bevel(lib.cylinder("Plinth2", 2.4, 1.6, (0, 0, 1.8), W, vertices=20), 0.12), "stone", W, 2.0)
    paint.paint(lib.cylinder("Trim", 2.5, 0.2, (0, 0, 2.6), W, vertices=20), "brass", W, 1.0)
    for i in range(6):
        a = i / 6 * math.pi * 2
        paint.glow(lib.box(f"Rune{i}", (0.5, 0.1, 0.5), (math.cos(a) * 3.22, math.sin(a) * 3.22, 0.5), W,
                           rotation=(0, 0, a + math.pi / 2)), (0.45, 1.0, 0.55))
    marble = (0.92, 0.92, 0.95)
    for side in (-1, 1):
        paint.paint(lib.box(f"Leg{side}", (0.55, 0.6, 2.2), (side * 0.4, 0, 3.8), W), "stone", marble, 1.5)
    paint.paint(bevel(lib.box("Body", (1.6, 0.9, 2.0), (0, 0, 5.8), W), 0.12), "stone", marble, 1.5)
    paint.paint(lib.cone("Cape", 1.1, 2.6, (0, 0.5, 5.4), W, vertices=10, radius_top=0.6), "stone", (0.85, 0.85, 0.9), 1.5)
    paint.paint(smooth(lib.sphere("Head", 0.62, (0, 0, 7.3), W, segments=14)), "stone", marble, 1.5)
    arm = lib.box("Arm", (0.4, 0.4, 1.8), (0.95, 0, 7.0), W, rotation=(0, math.radians(-20), 0))
    paint.paint(arm, "stone", marble, 1.5)
    paint.paint(lib.box("Blade", (0.2, 0.08, 3.0), (1.45, 0, 9.2), W, rotation=(0, math.radians(-12), 0)), "iron", (1.2, 1.2, 1.25), 1.0)
    paint.paint(lib.box("Guard", (1.0, 0.25, 0.2), (1.2, 0, 7.75), W), "brass", W, 1.0)
elif name in ("mapboard", "questboard"):
    # a signboard on two posts with a little roof: the map, or notes pinned up
    for x in (-2.6, 2.6):
        post(x, 0, 6.2, 0.25)
    paint.paint(bevel(lib.box("Board", (5.4, 0.3, 3.4), (0, -0.1, 3.8), W), 0.06), "wood", W, 1.4)
    for side in (-1, 1):
        roof = lib.box(f"Roof{side}", (6.4, 1.3, 0.2), (0, side * 0.55, 6.5), W, rotation=(side * -0.6, 0, 0))
        paint.paint(roof, "roof", W, 1.2)
    if name == "mapboard":
        paint.paint(lib.box("Map", (4.6, 0.1, 2.7), (0, -0.3, 3.8), W), "cloth", (1.0, 0.92, 0.75), 2.0)
        for i, (x, z, col) in enumerate(((-1.4, 4.4, (0.95, 0.35, 0.2)), (0.2, 3.3, (0.35, 0.8, 0.35)), (1.5, 4.2, (0.6, 0.45, 1.0)))):
            paint.glow(lib.sphere(f"Pin{i}", 0.22, (x, -0.4, z), W, segments=8), col)
    else:
        for i, (x, z, rot) in enumerate(((-1.6, 4.2, 0.08), (0, 3.6, -0.05), (1.6, 4.0, 0.1), (-0.8, 2.9, -0.1))):
            note = lib.box(f"Note{i}", (1.3, 0.08, 1.6), (x, -0.3, z), W, rotation=(0, rot, 0))
            paint.paint(note, "cloth", W, 1.0)
            paint.paint(lib.sphere(f"Tack{i}", 0.1, (x, -0.36, z + 0.65), W, segments=6), None, (0.85, 0.2, 0.2))
elif name == "chest":
    # a big treasure chest, lid open a crack with gold light spilling out
    paint.paint(bevel(lib.box("Base", (3.4, 2.2, 1.6), (0, 0, 0.8), W), 0.1), "wood", W, 1.2)
    lid = lib.cylinder("Lid", 1.1, 3.4, (0, 0.15, 1.75), W, vertices=12, rotation=(0, math.radians(90), 0))
    lid.scale = (1, 1, 0.75)
    paint.paint(lid, "wood", W, 1.2)
    for x in (-1.2, 0, 1.2):
        paint.paint(lib.box(f"Band{x}", (0.25, 2.3, 1.7), (x, 0, 0.85), W), "brass", W, 0.8)
    paint.paint(lib.box("Lock", (0.6, 0.15, 0.7), (0, -1.15, 1.4), W), "brass", W, 0.6)
    paint.glow(lib.box("Glow", (3.0, 1.8, 0.15), (0, 0, 1.68), W), (1.0, 0.8, 0.3))
elif name == "nest":
    # a big straw nest with three speckled eggs
    nest = lib.cylinder("Nest", 3.0, 1.2, (0, 0, 0.6), W, vertices=20)
    paint.paint(bevel(nest, 0.4, 3), "cloth_basket", (1.0, 0.92, 0.7), 1.2)
    for i, col in enumerate(((0.55, 0.85, 0.45), (0.95, 0.75, 0.4), (0.65, 0.6, 1.0))):
        a = i / 3 * math.pi * 2
        egg = lib.sphere(f"Egg{i}", 0.75, (math.cos(a) * 1.2, math.sin(a) * 1.2, 1.8), W, segments=14)
        egg.scale = (1, 1, 1.3)
        paint.paint(smooth(egg), "stone", col, 0.8)
elif name == "campfire":
    # a stone fire ring with crossed logs and three log benches around it
    for i in range(10):
        a = i / 10 * math.pi * 2
        st = lib.sphere(f"Stone{i}", 0.5, (math.cos(a) * 1.6, math.sin(a) * 1.6, 0.25), W, segments=8)
        paint.paint(st, "stone", (0.8, 0.78, 0.76), 1.0)
    for i in range(4):
        a = i / 4 * math.pi
        paint.paint(lib.cylinder(f"Log{i}", 0.22, 2.2, (0, 0, 0.45), W, vertices=7, rotation=(math.radians(75), 0, a)), "bark", W, 1.0)
    paint.glow(lib.sphere("Embers", 0.7, (0, 0, 0.4), W, segments=8), (1.0, 0.55, 0.15))
    for i in range(3):
        a = i / 3 * math.pi * 2 + 0.5
        bench = lib.cylinder(f"Bench{i}", 0.45, 3.2, (math.cos(a) * 4.2, math.sin(a) * 4.2, 0.45), W, vertices=10,
                             rotation=(0, math.radians(90), a + math.pi / 2))
        paint.paint(smooth(bench), "bark", W, 1.5)

parts = paint.bake("outpost_" + name, out[:-4] + "_paint.png", 512)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
