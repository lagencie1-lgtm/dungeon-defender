"""Carries the paint of one model onto another that shares its surfaces (the barricade's centre section, built alone
with HTD_CENTRE_ONLY=1, takes the paint projected onto the full wall, so it can be scored against the picture, which
shows the centre only). Every texel of the target takes the colour of the nearest point on the source's surface; texels
further than MAX_DIST from it (the sawn ends the centre-only build adds where the full wall's logs run on) keep the
target's own baked colour.

Run: blender -b -P paint_transfer.py -- source.fbx source_paint.png target.fbx target_base.png out.png"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[sys.argv.index("--") + 1:]
src_fbx, src_tex, dst_fbx, dst_tex, out = [os.path.abspath(a) for a in args[:5]]
MAX_DIST = 0.04


def load(fbx):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    body = next((o for o in objs if o.name.startswith("Body")), objs[0])
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return body


def load_png(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    return np.flipud(arr.reshape(h, w, 4))


def save_png(path, arr):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("out", w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def tris(o):
    m = o.data
    m.calc_loop_triangles()
    verts = np.array([v.co[:] for v in m.vertices])
    tv = np.array([lt.vertices[:] for lt in m.loop_triangles])
    uv = m.uv_layers.active.data
    tuv = np.array([[uv[li].uv[:] for li in lt.loops] for lt in m.loop_triangles])
    return verts, tv, tuv


bpy.ops.wm.read_factory_settings(use_empty=True)
src = load(src_fbx)
dst = load(dst_fbx)
sv, stv, suv = tris(src)
bvh = BVHTree.FromPolygons([Vector(v) for v in sv], [tuple(int(i) for i in t) for t in stv], all_triangles=True)
stex = load_png(src_tex)
dtex = load_png(dst_tex)
TS = dtex.shape[0]
SS = stex.shape[0]

dv, dtv, duv = tris(dst)
out_img = dtex.copy()
moved = kept = 0
for i in range(len(dtv)):
    (u0, v0), (u1, v1), (u2, v2) = duv[i] * TS
    y0, y1, y2 = TS - v0, TS - v1, TS - v2
    minx, maxx = int(max(0, math.floor(min(u0, u1, u2)))), int(min(TS - 1, math.ceil(max(u0, u1, u2))))
    miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(TS - 1, math.ceil(max(y0, y1, y2))))
    if maxx < minx or maxy < miny:
        continue
    den = (y1 - y2) * (u0 - u2) + (u2 - u1) * (y0 - y2)
    if abs(den) < 1e-12:
        continue
    ys, xs = np.mgrid[miny:maxy + 1, minx:maxx + 1]
    a = ((y1 - y2) * (xs + 0.5 - u2) + (u2 - u1) * (ys + 0.5 - y2)) / den
    b = ((y2 - y0) * (xs + 0.5 - u2) + (u0 - u2) * (ys + 0.5 - y2)) / den
    c = 1 - a - b
    inside = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
    if not inside.any():
        continue
    P = np.stack([a[inside], b[inside], c[inside]], axis=1) @ dv[dtv[i]]
    for (yy, xx, p) in zip(ys[inside], xs[inside], P):
        loc, _n, fi, dist = bvh.find_nearest(Vector(p))
        if loc is None or dist > MAX_DIST:
            kept += 1
            continue
        t = sv[stv[fi]]
        # barycentric of loc in the source triangle
        e0, e1, ep = t[1] - t[0], t[2] - t[0], np.array(loc[:]) - t[0]
        d00, d01, d11 = e0 @ e0, e0 @ e1, e1 @ e1
        d20, d21 = ep @ e0, ep @ e1
        dd = d00 * d11 - d01 * d01
        if abs(dd) < 1e-14:
            kept += 1
            continue
        bv = (d11 * d20 - d01 * d21) / dd
        bw = (d00 * d21 - d01 * d20) / dd
        uvp = suv[fi][0] * (1 - bv - bw) + suv[fi][1] * bv + suv[fi][2] * bw
        sx = int(np.clip(uvp[0] * SS, 0, SS - 1))
        sy = int(np.clip((1 - uvp[1]) * SS, 0, SS - 1))
        out_img[yy, xx, :3] = stex[sy, sx, :3]
        moved += 1
save_png(out, out_img)
print("TRANSFERRED", out, "texels from the source", moved, "kept own", kept)
