"""The Frost Crystal, matching its icon: a tall pale-blue crystal cluster on a frosty stone base with a brass ring."""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

ICE = (0.70, 0.88, 1.0)
ICE_DEEP = (0.48, 0.74, 0.98)
SNOW = (0.93, 0.96, 1.0)

lib.reset()
lib.cylinder("Base", 2.7, 0.9, (0, 0, 0.45), lib.STONE, vertices=10)
lib.cylinder("Snow", 2.5, 0.25, (0, 0, 1.0), SNOW, vertices=10)
lib.cylinder("Ring", 1.5, 0.3, (0, 0, 1.2), lib.BRASS, vertices=10)

# the main crystal: a tall six-sided column with a pointed top
lib.cylinder("Crystal", 0.95, 4.2, (0, 0, 3.3), ICE, vertices=6)
lib.cone("CrystalTip", 0.95, 1.6, (0, 0, 6.2), ICE, vertices=6)
# smaller crystals leaning out
for i in range(5):
    a = i / 5 * math.pi * 2 + 0.3
    h = 1.8 + (i % 3) * 0.6
    x, y = math.cos(a) * 1.25, math.sin(a) * 1.25
    lib.cylinder(f"Shard{i}", 0.42, h, (x, y, 1.3 + h / 2), ICE_DEEP if i % 2 else ICE, vertices=6,
                 rotation=(-math.sin(a) * 0.35, math.cos(a) * 0.35, 0))
    lib.cone(f"ShardTip{i}", 0.42, 0.7, (x * 1.15, y * 1.15, 1.3 + h + 0.3), ICE_DEEP if i % 2 else ICE, vertices=6)

parts = lib.join_all("FrostCrystal")
print("TRIANGLES", lib.triangles(parts))
out = sys.argv[sys.argv.index("--") + 1]
lib.export_fbx(os.path.abspath(out))
print("EXPORTED", out)
