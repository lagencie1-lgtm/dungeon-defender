"""The Flame Cannon, painted version: a stout riveted-iron cannon with brass bands on a wooden carriage,
standing on a round stone base; the muzzle glows orange. Front (muzzle) faces -Y.
Footprint about 6 studs, about 7 studs tall. Run: blender -b -P tower_flame.py -- out.fbx"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel, smooth  # noqa: E402

W = (1, 1, 1)
lib.reset()
paint.setup()

# round stone base in two steps with a brass ring, and a few stacked cannonballs
paint.paint(bevel(lib.cylinder("Base", 2.95, 1.0, (0, 0, 0.5), W, vertices=18), 0.15), "stone", (0.8, 0.78, 0.76), 2.2)
paint.paint(bevel(lib.cylinder("Base2", 2.55, 0.6, (0, 0, 1.3), W, vertices=18), 0.1), "stone", W, 2.2)
paint.paint(lib.cylinder("Ring", 2.6, 0.2, (0, 0, 1.62), W, vertices=18), "brass", W, 1.2)
for i, (x, y, z) in enumerate([(1.7, 1.4, 1.95), (2.15, 0.9, 1.95), (1.95, 1.2, 2.45)]):
    paint.paint(lib.sphere(f"Ball{i}", 0.3, (x, y, z), W, segments=10), "iron", (0.6, 0.6, 0.65), 0.8)

# the carriage: two wooden cheeks with brass caps, big spoked wheels
for side in (-1, 1):
    cheek = lib.box(f"Cheek{side}", (0.5, 2.8, 1.9), (side * 1.05, 0.1, 2.55), W)
    paint.paint(bevel(cheek, 0.1), "wood", W, 1.6)
    paint.paint(lib.box(f"CheekCap{side}", (0.56, 2.9, 0.16), (side * 1.05, 0.1, 3.5), W), "brass", W, 1.0)
    wheel = lib.cylinder(f"Wheel{side}", 0.9, 0.32, (side * 1.48, 0.6, 2.0), W, vertices=16, rotation=(0, math.radians(90), 0))
    paint.paint(bevel(wheel, 0.06), "wood_dark", W, 1.2)
    tyre = lib.cylinder(f"Tyre{side}", 0.95, 0.2, (side * 1.5, 0.6, 2.0), W, vertices=16, rotation=(0, math.radians(90), 0))
    paint.paint(tyre, "iron", W, 1.0)
    paint.paint(lib.cylinder(f"Hub{side}", 0.27, 0.46, (side * 1.48, 0.6, 2.0), W, vertices=10,
                             rotation=(0, math.radians(90), 0)), "brass", W, 1.0)

# the barrel, tilted up, pointing forward (-Y)
tilt = math.radians(-22)
angle = math.radians(90) + tilt
axis = (0, -math.sin(angle), math.cos(angle))
barrel = lib.cone("Barrel", 0.88, 4.2, (0, -0.9, 3.4), W, vertices=18, radius_top=0.72)
barrel.rotation_euler = (angle, 0, 0)
paint.paint(smooth(barrel), "iron", W, 1.6)
paint.paint(smooth(lib.sphere("Breech", 0.98, (0, 0.95, 2.65), W, segments=16)), "iron", (0.8, 0.8, 0.85), 1.4)
paint.paint(lib.sphere("Knob", 0.3, (0, 1.95, 2.35), W, segments=10), "brass", W, 1.0)
for i, t in enumerate((1.3, 0.2, -1.0)):
    band = lib.cylinder(f"Band{i}", 0.9 - i * 0.05, 0.28, (0, -0.9 + axis[1] * t, 3.4 + axis[2] * t), W, vertices=18,
                        rotation=(angle, 0, 0))
    paint.paint(band, "brass", W, 1.0)
muzzle = lib.cone("Muzzle", 0.82, 0.55, (0, -2.78, 4.16), W, vertices=18, radius_top=1.05)
muzzle.rotation_euler = (angle, 0, 0)
paint.paint(bevel(muzzle, 0.05), "brass", W, 1.0)
paint.glow(lib.cylinder("Glow", 0.66, 0.2, (0, -2.99, 4.25), W, vertices=14, rotation=(angle, 0, 0)), (1.0, 0.48, 0.16))

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("tower_flame", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
