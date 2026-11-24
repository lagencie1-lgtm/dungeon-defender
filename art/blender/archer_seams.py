"""The seam gate for a finished archer (painted or not): across every texture seam of every part the colour must
not jump (both sides of each cut edge sampled; 99th percentile <= 14/255). Also re-checks that
every part is closed. Each side is sampled at the edge's middle (a 3 x 3 mean), as the build does. Updates <dir>/gates_build.json, which scripts/archer_gates.py reads.
Run: blender -b -P archer_seams.py -- <dir>/ranger_archer.fbx"""
import json
import os
import sys

import bmesh
import bpy
import numpy as np

fbx = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
d = os.path.dirname(fbx)
NAME = "ranger_archer"
R = int(os.environ.get("HTD_SEAM_R", "1"))
INSET = 0.0   # (sampling inside each face, 3 texels in, met different surface spots on each side: noisier)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
gates = {"watertight": {}, "seam": {}}
for o in bpy.context.scene.objects:
    base = o.name.split(".")[0]
    if o.type != "MESH" or base not in ("Head", "Body", "ArmR", "ArmL"):
        continue
    bm = bmesh.new()
    bm.from_mesh(o.data)
    gates["watertight"][base] = len([e for e in bm.edges if len(e.link_faces) != 2])
    bm.free()
    im = bpy.data.images.load(os.path.join(d, f"{NAME}_{base.lower()}_paint.png"))
    w, h = im.size
    px = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[:, :, :3]
    uv = o.data.uv_layers.active.data
    by_edge = {}
    for poly in o.data.polygons:
        n = poly.loop_total
        cu = sum((uv[poly.loop_start + k].uv for k in range(n)), uv[poly.loop_start].uv * 0) / n   # the face's UV centre
        for k in range(n):
            li, lj = poly.loop_start + k, poly.loop_start + (k + 1) % n
            a, b = o.data.loops[li].vertex_index, o.data.loops[lj].vertex_index
            ua, ub = uv[li].uv.copy(), uv[lj].uv.copy()
            if a > b:
                ua, ub = ub, ua
            mx, my = (ua.x + ub.x) / 2, (ua.y + ub.y) / 2
            # sampled a few texels in from the edge, inside its own face: the margin beyond the island edge is filler
            dx, dy = cu.x - mx, cu.y - my
            dl = max(1e-9, (dx * dx + dy * dy) ** 0.5)
            step = min(INSET / w, dl * 0.5) if INSET else 0.0
            by_edge.setdefault((min(a, b), max(a, b)), []).append((mx + dx / dl * step, my + dy / dl * step, ua, ub))

    def sample(x, y):
        i, j = int(y * h), int(x * w)
        r = R   # (texels each way: a 7 x 7 mean for a painted texture, so single brush strokes are not seams)
        return px[max(0, i - r):min(h, i + r + 1), max(0, j - r):min(w, j + r + 1)].reshape(-1, 3).mean(axis=0)
    jumps = []
    for sides in by_edge.values():
        if len(sides) != 2:
            continue
        (x0, y0, a0, b0), (x1, y1, a1, b1) = sides
        if (a0 - a1).length < 1e-4 and (b0 - b1).length < 1e-4:
            continue
        jumps.append(float(np.abs(sample(x0, y0) - sample(x1, y1)).max()) * 255)
        if os.environ.get("HTD_SEAM_DEBUG") and jumps[-1] > 60:
            print("  JUMP %.0f uv (%.3f,%.3f) vs (%.3f,%.3f)" % (jumps[-1], x0, y0, x1, y1), (sample(x0, y0) * 255).astype(int), (sample(x1, y1) * 255).astype(int))
    jumps.sort()
    p99 = jumps[int(len(jumps) * 0.99)] if jumps else 0
    gates["seam"][base] = {"edges": len(jumps), "p99": round(p99, 1), "max": round(jumps[-1], 1) if jumps else 0}
    print("SEAM", base, len(jumps), "seam edges, 99th percentile jump %.1f /255" % p99, "ok" if p99 <= 14 else "FAIL")
json.dump(gates, open(os.path.join(d, "gates_build.json"), "w"), indent=1)
print("WROTE", os.path.join(d, "gates_build.json"))
