"""The seam gate as the player sees it: renders the painted archer (flat texture colour, orthographic) from 8 sides
and, for every mesh edge the camera sees, measures the colour change across it in the picture (2 px either side).
A texture seam that shows is an edge where that change is bigger than across ordinary edges. Passes when the seams'
95th percentile is at most the ordinary edges' 95th percentile x 1.15 + 3 (in 0..255).
Run: blender -b -P archer_seams_seen.py -- <dir>/ranger_archer.fbx     (writes "seen" into <dir>/gates_build.json)"""
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

fbx = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
d = os.path.dirname(fbx)
NAME = "ranger_archer"
SIZE = 1024
PARTS = ("Head", "Body", "ArmR", "ArmL")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
meshes = []
# gate: no vertex colours in the file (Roblox multiplies the texture by them)
VC = sum(len(o.data.color_attributes) for o in bpy.context.scene.objects if o.type == "MESH")
print("VERTEX COLOURS", VC, "ok" if VC == 0 else "FAIL")
for o in list(bpy.context.scene.objects):
    base = o.name.split(".")[0]
    if o.type != "MESH" or base not in PARTS:
        bpy.data.objects.remove(o, do_unlink=True)
        continue
    mat = bpy.data.materials.new("m")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(d, f"{NAME}_{base.lower()}_paint.png"))
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(mat)
    meshes.append(o)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "TEXTURE"
sc.view_settings.view_transform = "Standard"
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.render.film_transparent = True
lo = Vector([min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)])
hi = Vector([max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)])
centre = (lo + hi) / 2
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = (hi - lo).length * 0.9

# edges of each part: seam (its two faces use different texture spots) or ordinary
edges = []
for o in meshes:
    me = o.data
    uv = me.uv_layers.active.data
    seen = {}
    for poly in me.polygons:
        n = poly.loop_total
        for k in range(n):
            li, lj = poly.loop_start + k, poly.loop_start + (k + 1) % n
            a, b = me.loops[li].vertex_index, me.loops[lj].vertex_index
            ua, ub = uv[li].uv.copy(), uv[lj].uv.copy()
            if a > b:
                ua, ub = ub, ua
            seen.setdefault((min(a, b), max(a, b)), []).append((ua, ub))
    mw = o.matrix_world
    for (a, b), sides in seen.items():
        if len(sides) != 2:
            continue
        seam = (sides[0][0] - sides[1][0]).length > 1e-4 or (sides[0][1] - sides[1][1]).length > 1e-4
        edges.append((mw @ me.vertices[a].co, mw @ me.vertices[b].co, seam))
seam_d, plain_d = [], []
dg = bpy.context.evaluated_depsgraph_get()
for k in range(8):
    az = math.radians(-90 + k * 45)
    cam.location = centre + Vector((math.cos(az), math.sin(az), 0.15)) * 8
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    path = os.path.join(d, f"_seen_{k}.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path)
    px = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    im.pixels.foreach_get(px)
    px = px.reshape(SIZE, SIZE, 4)
    for p0, p1, seam in edges:
        mid = (p0 + p1) / 2
        hit, loc, *_ = sc.ray_cast(dg, cam.location, (mid - cam.location).normalized())
        if not hit or (loc - mid).length > 0.01:
            continue
        s0, s1 = world_to_camera_view(sc, cam, p0), world_to_camera_view(sc, cam, p1)
        e = Vector((s1.x - s0.x, s1.y - s0.y))
        if e.length * SIZE < 3:
            continue
        nrm = Vector((-e.y, e.x)).normalized() * (2.5 / SIZE)
        sm = world_to_camera_view(sc, cam, mid)
        pa, pb = (sm.x + nrm.x, sm.y + nrm.y), (sm.x - nrm.x, sm.y - nrm.y)
        ia, ib = (int(pa[1] * SIZE), int(pa[0] * SIZE)), (int(pb[1] * SIZE), int(pb[0] * SIZE))
        if not all(0 <= v < SIZE for v in ia + ib):
            continue
        ca, cb = px[ia], px[ib]
        if ca[3] < 0.99 or cb[3] < 0.99:
            continue   # one side is the background: an outline, not a seam
        diff = float(np.abs(ca[:3] - cb[:3]).max()) * 255
        (seam_d if seam else plain_d).append(diff)
    os.remove(path)
p95s, p95p = float(np.percentile(seam_d, 95)), float(np.percentile(plain_d, 95))
ok = p95s <= p95p * 1.15 + 3
print("SEEN seams %d edges p95 %.1f | ordinary edges %d p95 %.1f | %s" % (len(seam_d), p95s, len(plain_d), p95p, "ok" if ok else "FAIL"))
gp = os.path.join(d, "gates_build.json")
g = json.load(open(gp)) if os.path.exists(gp) else {}
g["vertex_colours"] = VC
g["seen"] = {"seam_p95": round(p95s, 1), "ordinary_p95": round(p95p, 1), "seam_edges": len(seam_d), "ok": ok}
json.dump(g, open(gp, "w"), indent=1)
