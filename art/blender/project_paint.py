"""Paints a model with its target picture (6A "a painted picture as the body", Lemp 2026-11-23: a Blender workflow
that comes extremely close to the picture, no Tripo). The Codex picture is projected onto the model from the
picture's own camera angle; faces the picture can't see get the picture mirrored from the opposite side, and what
neither sees keeps the model's own painted texture. The mix is baked into the model's existing texture layout, so
the game keeps its mesh and only gets a new paint image.

Run: blender -b -P project_paint.py -- model.fbx model_paint.png views.json out_paint.png [size=1024]
views.json: [{"image": "front.png", "azimuth": -75, "elevation": 15, "mirror": false}, ...] (a turnaround from Codex);
each face takes the picture that sees it most squarely (and is not hidden); faces no picture sees keep the own paint.
The camera matches art/blender/render_match.py; the picture is aligned to the model by their outlines' boxes."""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
import json  # noqa: E402
src, paint_path, views_path, out_path = (os.path.abspath(a) for a in args[:4])
size = int(args[4]) if len(args) > 4 else 1024
VIEWS = json.load(open(views_path))
base_dir = os.path.dirname(views_path)
R = 768  # the virtual render's resolution (as render_match.py renders for the score)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = next(o for o in meshes if o.name == "Body")
lo = Vector((min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
hi = Vector((max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
center = (lo + hi) / 2
radius = (hi - lo).length / 2

scene = bpy.context.scene
scene.render.resolution_x = scene.render.resolution_y = R


def camera(azimuth, el):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.lens = 50
    d = radius * 3.0
    cam.location = center + Vector((math.cos(azimuth) * math.cos(el) * d, math.sin(azimuth) * math.cos(el) * d, math.sin(el) * d))
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    return cam


from bpy_extras.object_utils import world_to_camera_view  # noqa: E402

mesh = body.data
mw = body.matrix_world
bm = bmesh.new()
bm.from_mesh(mesh)
bm.faces.ensure_lookup_table()
bvh = BVHTree.FromBMesh(bm)


def outline_box(image):
    w, h = image.size
    p = list(image.pixels)
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            k = (y * w + x) * 4
            if min(p[k], p[k + 1], p[k + 2]) < 0.93:
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs), max(ys)), w, h


def projection(view):
    """for every face: how squarely this picture sees it, and each loop's place in the picture"""
    image = bpy.data.images.load(os.path.join(base_dir, view["image"]))
    tbox, tw, th = outline_box(image)
    cam = camera(math.radians(view["azimuth"]), math.radians(view.get("elevation", 15)))
    pts = [world_to_camera_view(scene, cam, mw @ v.co) for v in mesh.vertices]
    bx = (min(p.x for p in pts), min(p.y for p in pts), max(p.x for p in pts), max(p.y for p in pts))
    local_cam = mw.inverted() @ cam.matrix_world.translation
    seen, uv = {}, {}
    for f in bm.faces:
        c = f.calc_center_median()
        to_cam = (local_cam - c).normalized()
        facing = f.normal.dot(to_cam)
        if facing <= 0.08:
            continue
        hit = bvh.ray_cast(c + to_cam * 0.02, to_cam)
        if hit[0] is not None and (hit[0] - c).length < (local_cam - c).length - 0.05:
            continue
        seen[f.index] = facing
        for loop in f.loops:
            p = pts[loop.vert.index]
            fx = (p.x - bx[0]) / max(1e-6, bx[2] - bx[0])
            fy = (p.y - bx[1]) / max(1e-6, bx[3] - bx[1])
            if view.get("mirror"):
                fx = 1 - fx
            uv[loop.index] = ((tbox[0] + fx * (tbox[2] - tbox[0])) / tw, (tbox[1] + fy * (tbox[3] - tbox[1])) / th)
    return image, seen, uv


projections = [projection(v) for v in VIEWS[:3]]
# each face: the view that sees it most squarely
best = {}
for k, (_, seen, _) in enumerate(projections):
    for fi, facing in seen.items():
        if fi not in best or facing > best[fi][1]:
            best[fi] = (k, facing)
print("PROJECTED", len(best), "of", len(bm.faces), "faces;", [sum(1 for b in best.values() if b[0] == k) for k in range(len(projections))])
layers = []
for k in range(len(projections)):
    layers.append(mesh.uv_layers.new(name=f"View{k}"))
mask = mesh.color_attributes.new(name="Mask", type="FLOAT_COLOR", domain="CORNER")
for f in bm.faces:
    pick = best.get(f.index)
    weights = [0.0, 0.0, 0.0]
    if pick:
        weights[pick[0]] = min(1.0, pick[1] / 0.35)
    for loop in f.loops:
        for k, (_, _, uv) in enumerate(projections):
            layers[k].data[loop.index].uv = uv.get(loop.index, (0, 0))
        mask.data[loop.index].color = (weights[0], weights[1], weights[2], 1)
# the bake material: own paint, mixed with the picture through the front and back projections
mat = bpy.data.materials.new("project")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
emit = nt.nodes.new("ShaderNodeEmission")


def tex(image, uvname):
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image
    t.interpolation = "Cubic"
    u = nt.nodes.new("ShaderNodeUVMap")
    u.uv_map = uvname
    nt.links.new(u.outputs["UV"], t.inputs["Vector"])
    return t


own = tex(bpy.data.images.load(paint_path), mesh.uv_layers[0].name)
attr = nt.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "Mask"
sep = nt.nodes.new("ShaderNodeSeparateColor")
nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
current = own.outputs["Color"]
for k, (image, _, _) in enumerate(projections):
    pic = tex(image, f"View{k}")
    # where the picture shows its white background (the outlines never match exactly), keep the own paint
    psep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(pic.outputs["Color"], psep.inputs["Color"])
    lo_rg = nt.nodes.new("ShaderNodeMath")
    lo_rg.operation = "MINIMUM"
    nt.links.new(psep.outputs["Red"], lo_rg.inputs[0])
    nt.links.new(psep.outputs["Green"], lo_rg.inputs[1])
    lo_all = nt.nodes.new("ShaderNodeMath")
    lo_all.operation = "MINIMUM"
    nt.links.new(lo_rg.outputs[0], lo_all.inputs[0])
    nt.links.new(psep.outputs["Blue"], lo_all.inputs[1])
    notwhite = nt.nodes.new("ShaderNodeMapRange")
    notwhite.inputs["From Min"].default_value = 0.97
    notwhite.inputs["From Max"].default_value = 0.85
    nt.links.new(lo_all.outputs[0], notwhite.inputs["Value"])
    weight = nt.nodes.new("ShaderNodeMath")
    weight.operation = "MULTIPLY"
    nt.links.new(sep.outputs[("Red", "Green", "Blue")[k]], weight.inputs[0])
    nt.links.new(notwhite.outputs["Result"], weight.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(weight.outputs[0], mix.inputs["Factor"])
    nt.links.new(current, mix.inputs[6])
    nt.links.new(pic.outputs["Color"], mix.inputs[7])
    current = mix.outputs[2]
nt.links.new(current, emit.inputs["Color"])
nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
baked = bpy.data.images.new("baked", size, size)
bake_node = nt.nodes.new("ShaderNodeTexImage")
bake_node.image = baked
nt.nodes.active = bake_node
mesh.materials.clear()
mesh.materials.append(mat)
mesh.uv_layers.active = mesh.uv_layers[0]

scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.device = "CPU"
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.bake(type="EMIT", margin=8)
baked.filepath_raw = out_path
baked.file_format = "PNG"
baked.save()
print("PAINTED", out_path)
