"""Tones the pencil points (or, given spheres, the leafy crown) of a barricade's paint down to a darker, warmer wood after the grade (on a phone the bright
points stole the eye). Only texels inside a point's cone change.
Run: blender -b -P tone_tips.py -- model.fbx paint.png posts.json out.png [r g b]"""
import json
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[sys.argv.index("--") + 1:]
fbx, paint, posts_path, out = [os.path.abspath(a) for a in args[:4]]
gain = np.array([float(v) for v in args[4:7]]) if len(args) >= 7 else np.array([0.72, 0.62, 0.52])
posts = json.load(open(posts_path))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
body = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("Body"))
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

img = bpy.data.images.load(paint)
w, h = img.size
px = np.empty(w * h * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = np.flipud(px.reshape(h, w, 4))

m = body.data
m.calc_loop_triangles()
verts = np.array([v.co[:] for v in m.vertices])
uv = m.uv_layers.active.data
changed = np.zeros((h, w), dtype=bool)


def in_tip(p):
    for entry in posts:
        if len(entry) == 4:   # a sphere [x, y, z, radius] (the Rootwall's leafy crown)
            x, y, z, rad_ = entry
            if (p[0] - x) ** 2 + (p[1] - y) ** 2 + (p[2] - z) ** 2 <= rad_ * rad_:
                return True
            continue
        x, y, r, top, tip = entry
        if top - tip - 0.03 <= p[2] <= top + 0.03:
            rr = r * 1.06 * max(0.0, (top - p[2]) / tip) + 0.04
            if math.hypot(p[0] - x, p[1] - y) <= rr:
                return True
    return False


for lt in m.loop_triangles:
    tri = verts[list(lt.vertices)]
    cen = tri.mean(axis=0)
    if not in_tip(cen):
        continue
    uvs = np.array([uv[li].uv[:] for li in lt.loops]) * [w, h]
    uvs[:, 1] = h - uvs[:, 1]
    x0, x1 = int(max(0, math.floor(uvs[:, 0].min()) - 1)), int(min(w - 1, math.ceil(uvs[:, 0].max()) + 1))
    y0, y1 = int(max(0, math.floor(uvs[:, 1].min()) - 1)), int(min(h - 1, math.ceil(uvs[:, 1].max()) + 1))
    (ax, ay), (bx, by), (cx, cy) = uvs
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9:
        continue
    ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    a = ((by - cy) * (xs + 0.5 - cx) + (cx - bx) * (ys + 0.5 - cy)) / den
    b = ((cy - ay) * (xs + 0.5 - cx) + (ax - cx) * (ys + 0.5 - cy)) / den
    inside = (a >= -0.05) & (b >= -0.05) & (1 - a - b >= -0.05)
    changed[ys[inside], xs[inside]] = True

px[changed, :3] *= gain
out_img = bpy.data.images.new("out", w, h, alpha=True)
out_img.pixels.foreach_set(np.flipud(px).ravel())
out_img.filepath_raw = out
out_img.file_format = "PNG"
out_img.save()
print("TONED", out, "texels", int(changed.sum()))
