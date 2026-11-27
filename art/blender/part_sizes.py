"""How much of the phone silhouette each part of a tower covers (coordinator 2026-11-27, busy-detail round): the
model seen along the run camera (Blender az -53, el 32), each part's projected outline area (convex hull) over the
whole tower's projected outline. Parts are grouped by name without their trailing numbers.
Run: blender -b -P part_sizes.py -- model.fbx [threshold=0.02]   -> PART lines, smallest groups first"""
import math
import re
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src = args[0]
thr = float(args[1]) if len(args) > 1 else 0.02
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
az, el = math.radians(-53), math.radians(32)
fwd = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))   # (toward the camera)
right = Vector((0, 0, 1)).cross(fwd).normalized()
up = fwd.cross(right).normalized()


def hull_area(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return 0.0
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    h = lo[:-1] + hi[:-1]
    return abs(sum(h[i][0] * h[i - 1][1] - h[i - 1][0] * h[i][1] for i in range(len(h)))) / 2


allp, parts = [], {}
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    pts = [(round((o.matrix_world @ v.co).dot(right), 3), round((o.matrix_world @ v.co).dot(up), 3)) for v in o.data.vertices]
    allp += pts
    parts[o.name] = hull_area(pts)
total = hull_area(allp)
groups = {}
for n, a in parts.items():
    g = re.sub(r"[\d.\-]+$", "", re.sub(r"\.\d+$", "", n)) or n
    groups.setdefault(g, []).append(a / total)
for g, v in sorted(groups.items(), key=lambda kv: max(kv[1])):
    small = sum(1 for x in v if x < thr)
    print("PART %-28s n=%3d  largest %5.2f %%  under %.0f %%: %d  (sum %.1f %%)" % (g, len(v), 100 * max(v), 100 * thr, small, 100 * sum(v)))
print("PARTS total %d objects, %d under %.0f %%" % (len(parts), sum(1 for a in parts.values() if a / total < thr), 100 * thr))
