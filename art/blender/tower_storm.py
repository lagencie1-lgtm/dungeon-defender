"""The Storm Obelisk, matching its icon: a dark stone obelisk with brass bands and a crackling violet orb on top."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

DARK_STONE = (0.40, 0.36, 0.48)
ORB = (0.72, 0.45, 1.0)

lib.reset()
lib.box("Base", (4.8, 4.8, 1.0), (0, 0, 0.5), lib.STONE_DARK, bevel=0.12)
lib.box("Step", (3.6, 3.6, 0.6), (0, 0, 1.3), lib.STONE, bevel=0.1)
# tapered obelisk: a 4-sided cone section
lib.cone("Pillar", 1.4, 8.0, (0, 0, 5.6), DARK_STONE, vertices=4, radius_top=0.75)
for z, r in ((3.0, 1.25), (6.6, 1.0)):
    lib.cone(f"Band{z}", r + 0.12, 0.35, (0, 0, z), lib.BRASS, vertices=4, radius_top=r + 0.08)
lib.cone("Cap", 0.95, 0.9, (0, 0, 10.05), lib.BRASS, vertices=4, radius_top=0.4)
# claws holding the orb
for i in range(4):
    a = i * math.pi / 2 + math.pi / 4
    lib.box(f"Claw{i}", (0.18, 0.18, 1.3), (math.cos(a) * 0.55, math.sin(a) * 0.55, 10.9), lib.BRASS,
            rotation=(-math.sin(a) * 0.4, math.cos(a) * 0.4, 0))
lib.sphere("Orb", 1.05, (0, 0, 11.7), ORB, segments=14)

parts = lib.join_all("StormObelisk")
print("TRIANGLES", lib.triangles(parts))
out = sys.argv[sys.argv.index("--") + 1]
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", out)
