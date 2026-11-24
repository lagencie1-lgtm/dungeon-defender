"""Blends the colour across every texture seam of a painted model, in place (coordinator 2026-11-24: a painted
texture can differ a little on the two sides of a cut; blended over about 3 px it does not show as a line).
For each seam edge the two sides are walked together; at each step both texels move toward their common colour, with
a soft falloff 3 px wide. Run after painting: blender -b -P seam_blend.py -- model.fbx [radius=3] [skip=Bow,Quiver]
Textures are found as art/blender/parts_render.py finds them (<stem>_<part>_paint.png, <stem>_paint[_x].png)."""
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
fbx = os.path.abspath(args[0])
R = float(next((a[7:] for a in args[1:] if a.startswith("radius=")), 3))
stem = fbx[:-4]
SKIP = set(next((a[5:].split(",") for a in args[1:] if a.startswith("skip=")), []))   # parts whose paint stays as it is
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)


def tex_of(base):
    for p in (f"{stem}_{base.lower()}_paint.png", f"{stem}_paint_{base[5:]}.png" if base.startswith("Skin_") else "",
              f"{stem}_paint.png" if base == "Body" else ""):
        if p and os.path.exists(p):
            return p
    return None


for o in bpy.context.scene.objects:
    base = o.name.split(".")[0]
    path = tex_of(base) if (o.type == "MESH" and base not in SKIP) else None
    if not path or not o.data.uv_layers:
        continue
    im = bpy.data.images.load(path)
    w, h = im.size
    px = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = o.data.uv_layers.active.data
    sides = {}
    for poly in o.data.polygons:
        n = poly.loop_total
        for k in range(n):
            li, lj = poly.loop_start + k, poly.loop_start + (k + 1) % n
            a, b = o.data.loops[li].vertex_index, o.data.loops[lj].vertex_index
            ua, ub = np.array(uv[li].uv), np.array(uv[lj].uv)
            if a > b:
                ua, ub = ub, ua
            sides.setdefault((min(a, b), max(a, b)), []).append((ua, ub))
    yy, xx = np.mgrid[-int(R) - 1:int(R) + 2, -int(R) - 1:int(R) + 2]
    fall = np.clip(1 - np.sqrt(xx * xx + yy * yy) / (R + 0.5), 0, 1)[..., None]
    n_edges = 0
    for s in sides.values():
        if len(s) != 2:
            continue
        (a0, b0), (a1, b1) = s
        if np.abs(a0 - a1).max() < 1e-4 and np.abs(b0 - b1).max() < 1e-4:
            continue
        n_edges += 1
        steps = int(max(np.abs((b0 - a0) * [w, h]).max(), np.abs((b1 - a1) * [w, h]).max())) + 1
        for t in np.linspace(0, 1, steps + 1):
            p0 = (a0 + (b0 - a0) * t) * [w, h]
            p1 = (a1 + (b1 - a1) * t) * [w, h]
            i0, j0 = int(p0[1]), int(p0[0])
            i1, j1 = int(p1[1]), int(p1[0])
            if not (0 <= i0 < h and 0 <= j0 < w and 0 <= i1 < h and 0 <= j1 < w):
                continue
            c = (px[i0, j0, :3] + px[i1, j1, :3]) / 2
            for (i, j) in ((i0, j0), (i1, j1)):
                y0, y1 = max(0, i - int(R) - 1), min(h, i + int(R) + 2)
                x0, x1 = max(0, j - int(R) - 1), min(w, j + int(R) + 2)
                f = fall[y0 - (i - int(R) - 1):y1 - (i - int(R) - 1), x0 - (j - int(R) - 1):x1 - (j - int(R) - 1)]
                px[y0:y1, x0:x1, :3] = px[y0:y1, x0:x1, :3] * (1 - f) + c * f
    im.pixels.foreach_set(px.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    print("BLENDED", base, n_edges, "seam edges", path)
