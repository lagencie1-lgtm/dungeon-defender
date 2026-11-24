"""The Watch Keep's painted pieces (the new Outpost, server/OutpostKeep.luau), one model per run:
palisade (a 12-stud wall section), watchtower (a corner tower), pedestal (for the tower showcase).
Front faces -Y (towards the courtyard). Units are studs.
Run: blender -b -P keep_props.py -- out.fbx <name>   (writes keep_<name>_paint.png next to it)"""
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
rnd = random.Random(7)
lib.reset()
paint.setup()


def log(n, r, h, x, y, z0=0.0, tilt=0.0):
    """an upright log with a sharpened top; heights vary a little so the wall never looks copy-pasted"""
    body = lib.cylinder(f"Log{n}", r, h, (x, y, z0 + h / 2), W, vertices=8, rotation=(tilt, 0, 0))
    paint.paint(smooth(body, 50), "bark", (1.0, 0.95, 0.9), 1.6)
    tip = lib.cone(f"Tip{n}", r, r * 2.2, (x, y, z0 + h + r * 1.1), W, vertices=8)
    paint.paint(tip, "wood", (0.95, 0.85, 0.7), 1.0)


if name == "palisade":
    # 12 wide, 10 tall: a stone footing with logs on top and a rail behind; one log in eight leans a touch
    length = 12.0
    paint.paint(bevel(lib.box("Footing", (length, 2.2, 2.0), (0, 0.2, 1.0), W), 0.18), "stone", (0.92, 0.9, 0.86), 2.0)
    n = 13
    for i in range(n):
        x = -length / 2 + (i + 0.5) * length / n
        h = 7.2 + rnd.uniform(-0.5, 0.6)
        log(i, 0.47, h, x, 0.0, 1.9, rnd.uniform(-0.03, 0.03))
    for z in (4.2, 7.4):
        rail = lib.box(f"Rail{z}", (length, 0.45, 0.55), (0, 0.65, z), W)
        paint.paint(bevel(rail, 0.08), "wood_dark", W, 1.5)
    # iron bands binding the logs, on the courtyard side
    for z in (3.0, 7.9):
        paint.paint(lib.box(f"Band{z}", (length, 0.12, 0.3), (0, -0.48, z), W), "iron", W, 1.0)
elif name == "watchtower":
    # a stone base (8 tall), a timber lookout with a railing, a pointed shingle roof with a pennant
    paint.paint(bevel(lib.box("Base", (8.4, 8.4, 8.0), (0, 0, 4.0), W), 0.3), "stone", (0.95, 0.93, 0.88), 2.0)
    paint.paint(bevel(lib.box("Cornice", (9.2, 9.2, 0.7), (0, 0, 8.3), W), 0.12), "stone", (0.8, 0.78, 0.75), 2.0)
    for x in (-3.4, 3.4):
        for y in (-3.4, 3.4):
            post = lib.box(f"Post{x}{y}", (0.7, 0.7, 7.0), (x, y, 12.1), W)
            paint.paint(bevel(post, 0.08), "wood_dark", W, 1.5)
    paint.paint(bevel(lib.box("Floor", (9.0, 9.0, 0.5), (0, 0, 8.9), W), 0.08), "wood", W, 1.5)
    for side in range(4):
        a = side * math.pi / 2
        cx, cy = math.cos(a) * 4.0, math.sin(a) * 4.0
        rail = lib.box(f"Rail{side}", (8.4, 0.3, 0.35), (cx, cy, 10.6), W, rotation=(0, 0, a + math.pi / 2))
        paint.paint(rail, "wood_dark", W, 1.5)
        for k in range(-3, 4):
            px = cx + math.cos(a + math.pi / 2) * k * 1.15
            py = cy + math.sin(a + math.pi / 2) * k * 1.15
            paint.paint(lib.box(f"Bal{side}{k}", (0.22, 0.22, 1.6), (px, py, 9.9), W), "wood", W, 1.0)
    roof = lib.cone("Roof", 6.6, 6.4, (0, 0, 18.8), W, vertices=4)
    roof.rotation_euler = (0, 0, math.pi / 4)
    paint.paint(roof, "roof", (0.95, 0.55, 0.42), 1.6)
    paint.paint(lib.cylinder("Pole", 0.12, 3.0, (0, 0, 23.2), W, vertices=6), "wood_dark", W, 1.0)
    flag = lib.box("Pennant", (0.08, 2.2, 1.1), (0, 1.1, 24.0), W)
    paint.paint(flag, "cloth", (0.3, 0.55, 0.95), 1.0)
    # the arrow slit is real: a dark recess, not a painted window
    paint.paint(lib.box("Slit", (0.5, 0.3, 1.8), (0, -4.15, 5.2), W), None, (0.12, 0.1, 0.09))
elif name == "pedestal":
    # a round stone plinth with a brass band and a step, for one defender in the showcase
    paint.paint(bevel(lib.cylinder("Step", 3.9, 0.5, (0, 0, 0.25), W, vertices=24), 0.1), "stone", (0.82, 0.8, 0.77), 2.0)
    paint.paint(bevel(lib.cylinder("Drum", 3.4, 1.1, (0, 0, 1.05), W, vertices=24), 0.12), "stone", (0.95, 0.93, 0.9), 2.0)
    paint.paint(lib.cylinder("Band", 3.45, 0.18, (0, 0, 1.45), W, vertices=24), "brass", W, 1.0)
elif name == "beacon":
    # The Beacon Tower (Lemp's pick, 2026-11-22): the Keep's landmark and its PLAY gate in one. A pale stone tower
    # with a real archway at its foot (the portal stands inside it), a timber lookout and a lantern cage on top
    # holding a big violet crystal that turns slowly in the game. 22 wide, 14 deep, 48 tall; front faces -Y.
    stone, pale = (0.95, 0.93, 0.88), (0.86, 0.84, 0.8)
    # the two legs of the arch and the wall above it (the opening is 16 wide and 24 tall: a real opening)
    for x in (-9.5, 9.5):
        paint.paint(bevel(lib.box(f"Leg{x}", (3.0, 14.0, 26.0), (x, 0, 13.0), W), 0.3), "stone", stone, 2.4)
        paint.paint(bevel(lib.box(f"Buttress{x}", (4.0, 4.0, 9.0), (x * 1.08, -6.4, 4.5), W), 0.3), "stone", pale, 2.4)
    paint.paint(bevel(lib.box("Lintel", (22.0, 14.0, 8.0), (0, 0, 30.0), W), 0.3), "stone", stone, 2.4)
    paint.paint(lib.box("Back", (16.0, 1.0, 24.0), (0, 6.5, 12.0), W), "stone", (0.7, 0.68, 0.66), 2.4)
    # a carved frame round the opening on the front, with a brass keystone
    for x in (-8.3, 8.3):
        paint.paint(bevel(lib.box(f"Jamb{x}", (1.2, 0.8, 26.0), (x, -7.2, 13.0), W), 0.12), "stone", pale, 1.5)
    paint.paint(bevel(lib.box("Head", (18.0, 0.8, 1.4), (0, -7.2, 26.3), W), 0.12), "stone", pale, 1.5)
    paint.paint(bevel(lib.box("Keystone", (2.6, 1.2, 3.0), (0, -7.4, 26.6), W), 0.15), "brass", W, 1.0)
    # battlements
    paint.paint(bevel(lib.box("Cornice", (23.4, 15.4, 1.0), (0, 0, 34.5), W), 0.12), "stone", pale, 2.0)
    for x in range(-5, 6):
        for y in (-7.2, 7.2):
            if x % 2 == 0:
                paint.paint(bevel(lib.box(f"Merlon{x}{y}", (1.8, 1.0, 1.8), (x * 2.0, y, 35.9), W), 0.1), "stone", stone, 1.5)
    # the lantern cage: four timber posts, a pointed roof, the crystal inside
    for x in (-3.2, 3.2):
        for y in (-3.2, 3.2):
            paint.paint(bevel(lib.box(f"Cage{x}{y}", (0.8, 0.8, 8.0), (x, y, 39.0), W), 0.08), "wood_dark", W, 1.5)
    paint.paint(bevel(lib.box("CageFloor", (8.4, 8.4, 0.6), (0, 0, 35.3), W), 0.08), "wood", W, 1.5)
    roof = lib.cone("CageRoof", 6.4, 5.0, (0, 0, 45.5), W, vertices=4)
    roof.rotation_euler = (0, 0, math.pi / 4)
    paint.paint(roof, "roof", (0.55, 0.6, 0.95), 1.6)
    crystal = lib.cone("Crystal", 2.7, 6.5, (0, 0, 40.2), W, vertices=6)
    paint.glow(crystal, (0.66, 0.55, 1.0))
    under = lib.cone("CrystalBase", 2.7, 3.0, (0, 0, 35.4), W, vertices=6)
    under.rotation_euler = (math.pi, 0, 0)
    paint.glow(under, (0.66, 0.55, 1.0))
    # banners hanging from the lintel, one each side of the arch (cloth, blue with a brass hem)
    for x in (-7.0, 7.0):
        paint.paint(lib.box(f"Banner{x}", (3.2, 0.15, 7.0), (x, -7.15, 29.0), W), "cloth", (0.3, 0.55, 0.95), 1.2)
        paint.paint(lib.box(f"Hem{x}", (3.3, 0.18, 0.4), (x, -7.2, 25.6), W), "brass", W, 1.0)
else:
    raise SystemExit("unknown piece " + name)

parts = paint.bake("keep_" + name, out[:-4] + "_paint.png", 512)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
