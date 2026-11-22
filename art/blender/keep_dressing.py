"""Small painted pieces that dress the Watch Keep (each placed for a reason, see HubLayout.Dressing):
barrel, crate, lantern (a post with a lantern, lights the paths), flowerbed (a stone-edged bed), well (the plaza's
water), banner (hangs on the palisade), rack (weapons by the forge), coal (a coal heap by the forge),
ring (the stone rune ring a station opens from; its runes are a glow part the game tints per station).
Front faces -Y. Run: blender -b -P keep_dressing.py -- out.fbx <name>"""
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
rnd = random.Random(3)
lib.reset()
paint.setup()

if name == "barrel":
    body = lib.cylinder("Barrel", 1.0, 2.4, (0, 0, 1.2), W, vertices=14)
    for v in body.data.vertices:  # a little belly
        v.co.x *= 1 + 0.12 * (1 - abs(v.co.z - 1.2) / 1.2)
        v.co.y *= 1 + 0.12 * (1 - abs(v.co.z - 1.2) / 1.2)
    paint.paint(smooth(body), "wood", W, 1.4)
    for z in (0.35, 2.05):
        paint.paint(lib.cylinder(f"Hoop{z}", 1.04, 0.16, (0, 0, z), W, vertices=14), "iron", W, 1.0)
    paint.paint(lib.cylinder("Lid", 0.92, 0.08, (0, 0, 2.42), W, vertices=14), "wood_dark", W, 1.0)
elif name == "crate":
    paint.paint(bevel(lib.box("Crate", (2.0, 2.0, 2.0), (0, 0, 1.0), W), 0.08), "wood", W, 1.4)
    for x in (-1, 1):
        for y in (-1, 1):
            paint.paint(lib.box(f"Edge{x}{y}", (0.25, 0.25, 2.04), (x * 0.9, y * 0.9, 1.0), W), "wood_dark", W, 1.0)
    paint.paint(lib.box("Brace", (0.2, 2.05, 0.25), (0, 0, 1.0), W, rotation=(math.radians(45), 0, 0)), "wood_dark", W, 1.0)
elif name == "lantern":
    paint.paint(bevel(lib.box("Base", (0.9, 0.9, 0.5), (0, 0, 0.25), W), 0.06), "stone", W, 1.5)
    paint.paint(lib.cylinder("Post", 0.18, 6.0, (0, 0, 3.3), W, vertices=8), "wood_dark", W, 1.5)
    paint.paint(lib.box("Arm", (1.4, 0.16, 0.16), (0.6, 0, 6.1), W), "wood_dark", W, 1.0)
    paint.paint(lib.box("Cap", (0.7, 0.7, 0.18), (1.2, 0, 5.75), W), "iron", W, 1.0)
    paint.glow(lib.box("Light", (0.45, 0.45, 0.6), (1.2, 0, 5.3), W), (1.0, 0.78, 0.4))
    paint.paint(lib.box("Bottom", (0.6, 0.6, 0.12), (1.2, 0, 4.94), W), "iron", W, 1.0)
elif name == "flowerbed":
    # 8 x 4, a low stone edge, soil and clumps of flowers in two colours
    for i in range(10):
        a = i / 10 * math.pi * 2
        st = lib.box(f"Edge{i}", (1.6, 0.7, 0.6), (math.cos(a) * 3.6, math.sin(a) * 1.7, 0.3), W, rotation=(0, 0, a + math.pi / 2))
        paint.paint(bevel(st, 0.12), "stone", (0.9, 0.88, 0.84), 1.2)
    soil = lib.cylinder("Soil", 1.0, 0.4, (0, 0, 0.3), W, vertices=16)
    soil.scale = (3.4, 1.55, 1)
    paint.paint(soil, None, (0.36, 0.25, 0.16))
    for i in range(14):
        x, y = rnd.uniform(-2.8, 2.8), rnd.uniform(-1.1, 1.1)
        paint.paint(lib.sphere(f"Leaf{i}", 0.45, (x, y, 0.75), W, segments=8), "leaves", W, 1.0)
        col = (1.0, 0.55, 0.65) if i % 2 else (1.0, 0.85, 0.35)
        paint.paint(lib.sphere(f"Bloom{i}", 0.2, (x + 0.1, y, 1.15), W, segments=6), None, col)
elif name == "well":
    ring = lib.cylinder("Wall", 2.2, 1.6, (0, 0, 0.8), W, vertices=18)
    paint.paint(bevel(ring, 0.1), "stone", (0.92, 0.9, 0.86), 2.0)
    paint.paint(lib.cylinder("Water", 1.8, 0.1, (0, 0, 1.45), W, vertices=18), None, (0.3, 0.55, 0.7))
    for x in (-1.9, 1.9):
        paint.paint(lib.box(f"Post{x}", (0.35, 0.35, 3.8), (x, 0, 3.3), W), "wood_dark", W, 1.4)
    roof = lib.cone("Roof", 3.0, 1.6, (0, 0, 5.9), W, vertices=4)
    roof.rotation_euler = (0, 0, math.pi / 4)
    roof.scale = (1.0, 0.75, 1.0)
    paint.paint(roof, "roof", (0.95, 0.55, 0.42), 1.4)
    paint.paint(lib.cylinder("Axle", 0.12, 3.8, (0, 0, 4.4), W, vertices=8, rotation=(0, math.radians(90), 0)), "wood", W, 1.0)
    paint.paint(lib.cylinder("Bucket", 0.4, 0.6, (0, 0, 3.3), W, vertices=10), "wood", W, 1.0)
elif name == "banner":
    # hangs on the inside of the palisade: a pole with a blue cloth and brass hem, 7 tall
    paint.paint(lib.cylinder("Pole", 0.12, 3.4, (0, 0, 7.0), W, vertices=8, rotation=(0, math.radians(90), 0)), "wood_dark", W, 1.0)
    for end in (-1.75, 1.75):
        paint.paint(lib.sphere(f"Knob{end}", 0.22, (end, 0, 7.0), W, segments=8), "brass", W, 1.0)
    cloth = lib.box("Cloth", (2.8, 0.12, 5.2), (0, -0.1, 4.3), W)
    paint.paint(cloth, "cloth", (0.3, 0.55, 0.95), 1.2)
    paint.paint(lib.box("Hem", (2.85, 0.16, 0.35), (0, -0.14, 1.8), W), "brass", W, 1.0)
    crest = lib.cone("Crest", 0.8, 0.12, (0, -0.2, 4.8), W, vertices=6)
    crest.rotation_euler = (math.radians(90), 0, 0)
    paint.paint(crest, "brass", W, 1.0)
elif name == "rack":
    for x in (-1.6, 1.6):
        paint.paint(lib.box(f"Leg{x}", (0.3, 0.6, 3.2), (x, 0, 1.6), W), "wood_dark", W, 1.4)
    for z in (1.2, 2.8):
        paint.paint(lib.box(f"Bar{z}", (3.6, 0.3, 0.25), (0, 0, z), W), "wood", W, 1.2)
    for i, x in enumerate((-1.0, -0.3, 0.4, 1.1)):
        blade = lib.box(f"Blade{i}", (0.22, 0.06, 2.4), (x, -0.25, 2.2), W)
        paint.paint(blade, "iron", (0.9, 0.92, 0.95), 1.0)
        paint.paint(lib.box(f"Guard{i}", (0.6, 0.12, 0.12), (x, -0.25, 0.95), W), "brass", W, 1.0)
elif name == "coal":
    for i in range(16):
        r = rnd.uniform(0.25, 0.45)
        a, d = rnd.uniform(0, math.pi * 2), rnd.uniform(0, 1.0)
        lump = lib.sphere(f"Coal{i}", r, (math.cos(a) * d, math.sin(a) * d, r * 0.7 + (1.0 - d) * 0.5), W, segments=6)
        paint.paint(lump, None, (0.16, 0.15, 0.16))
    paint.paint(lib.cylinder("Shovel", 0.06, 2.4, (0.9, 0.4, 1.0), W, vertices=6, rotation=(0.6, 0.4, 0)), "wood", W, 1.0)
elif name == "ring":
    # 10 wide: a flat ring of pale stones inset in the paving, six rune stones that glow (tinted per station)
    n = 16
    for i in range(n):
        a = i / n * math.pi * 2
        st = lib.box(f"Stone{i}", (1.95, 1.0, 0.24), (math.cos(a) * 4.5, math.sin(a) * 4.5, 0.12), W, rotation=(0, 0, a + math.pi / 2))
        paint.paint(bevel(st, 0.08), "stone", (0.95, 0.93, 0.88), 1.2)
    for i in range(6):
        a = i / 6 * math.pi * 2 + 0.26
        paint.glow(lib.box(f"Rune{i}", (0.55, 0.32, 0.06), (math.cos(a) * 4.5, math.sin(a) * 4.5, 0.27), W,
                           rotation=(0, 0, a + math.pi / 2)), (1.0, 1.0, 1.0))
else:
    raise SystemExit("unknown piece " + name)

parts = paint.bake("keep_" + name, out[:-4] + "_paint.png", 256)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
