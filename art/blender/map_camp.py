"""Cursed Forest: the goblin camp gate where the enemies come out. Two log watch posts with sharpened tops,
a lashed log lintel with a tattered green banner, crossed spears and a stone campfire ring in front.
Opening faces -Y (towards the path). About 18 wide, 15 tall. Run: blender -b -P map_camp.py -- out.fbx"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import smooth  # noqa: E402

W = (1, 1, 1)
FIRE = (1.0, 0.55, 0.15)
lib.reset()
paint.setup()

# two watch posts, each a bundle of upright logs with sharpened tops
for side in (-1, 1):
    cx = side * 6.5
    for i, (dx, dy, h) in enumerate(((-0.9, -0.9, 11.5), (0.9, -0.9, 12.5), (-0.9, 0.9, 12.0), (0.9, 0.9, 11.0), (0, 0, 13.0))):
        log = lib.cylinder(f"Log{side}{i}", 0.62, h, (cx + dx, dy, h / 2), W, vertices=10)
        paint.paint(smooth(log), "bark", W, 2.0)
        tip = lib.cone(f"Tip{side}{i}", 0.62, 1.2, (cx + dx, dy, h + 0.6), W, vertices=10)
        paint.paint(tip, "wood", W, 1.0)
    # rope lashings
    for z in (3.0, 8.0):
        band = lib.cylinder(f"Rope{side}{z}", 1.95, 0.35, (cx, 0, z), W, vertices=12)
        paint.paint(band, "cloth", (0.86, 0.76, 0.56), 0.8)
# the lintel log and a crossbar
lintel = lib.cylinder("Lintel", 0.7, 16.5, (0, 0, 10.2), W, vertices=10, rotation=(0, math.radians(90), 0))
paint.paint(smooth(lintel), "bark", W, 2.0)
bar = lib.cylinder("Bar", 0.45, 14.5, (0, -0.2, 8.6), W, vertices=8, rotation=(0, math.radians(90), 0))
paint.paint(smooth(bar), "wood_dark", W, 1.5)
# tattered banner hanging from the lintel
banner = lib.box("Banner", (5.0, 0.12, 3.6), (0, -0.8, 8.0), W)
paint.paint(banner, "cloth", (0.48, 0.66, 0.34), 1.6)
for i in range(4):
    tooth = lib.cone(f"Tatter{i}", 0.55, 0.9, (-1.9 + i * 1.25, -0.8, 5.85), W, vertices=3)
    tooth.rotation_euler = (math.radians(180), 0, 0)
    paint.paint(tooth, "cloth", (0.48, 0.66, 0.34), 1.0)
# crossed spears on the banner
for side in (-1, 1):
    spear = lib.cylinder(f"Spear{side}", 0.1, 5.2, (0, -1.0, 8.2), W, vertices=6, rotation=(0, math.radians(side * 40), 0))
    paint.paint(spear, "wood_dark", W, 1.0)
    head = lib.cone(f"SpearHead{side}", 0.25, 0.8, (side * 1.95, -1.0, 10.3), W, vertices=4)
    head.rotation_euler = (0, math.radians(side * 40), 0)
    paint.paint(head, "iron", W, 0.8)
# campfire ring in front of the opening
for i in range(9):
    a = i / 9 * math.pi * 2
    stone = lib.sphere(f"FireStone{i}", 0.45, (math.cos(a) * 1.4, -5 + math.sin(a) * 1.4, 0.25), W, segments=8)
    paint.paint(stone, "t_moss_rock", W, 1.0)
for i in range(3):
    a = i / 3 * math.pi
    wood = lib.cylinder(f"FireLog{i}", 0.18, 1.8, (0, -5, 0.35), W, vertices=6, rotation=(math.radians(80), 0, a))
    paint.paint(wood, "bark", W, 1.0)
paint.glow(lib.sphere("Embers", 0.6, (0, -5, 0.35), W, segments=8), FIRE)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("map_camp", out[:-4] + "_paint.png", 1024)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
