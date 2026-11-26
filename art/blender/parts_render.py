"""Renders a model whose parts each wear their own paint (picture_body: <name>_<part>_paint.png; tower kit: Body =
<name>_paint.png, Skin_x = <name>_paint_x.png), flat albedo on a transparent ground.
Run: blender -b -P parts_render.py -- model.fbx out.png [azimuth=-90] [elevation=0] [size=768] [ortho|persp] [lit]"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
az = math.radians(float(args[2]) if len(args) > 2 else -90)
el = math.radians(float(args[3]) if len(args) > 3 else 0)
size = int(args[4]) if len(args) > 4 else 768
ortho = (args[5] if len(args) > 5 else "ortho") == "ortho"
lit = len(args) > 6 and args[6] == "lit"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
stem = src[:-4]
# (2026-11-26) HTD_EXTRA="model.fbx|gx,gy,gz|yaw|height;...": more models placed as the game places them (the Ranger's
# archers: feet at the game position relative to the look's bottom centre, turned by yaw about the up axis, scaled to
# that height); game (x, y, z) is Blender (-x, z, y), and a turn about the game's up axis is the same turn here
for spec in filter(None, os.environ.get("HTD_EXTRA", "").split(";")):
    path, pos, yaw, height = spec.split("|")
    gx, gy, gz = (float(v) for v in pos.split(","))
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    new = [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in new for c in o.bound_box]
    lo_ = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi_ = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    feet = Vector(((lo_.x + hi_.x) / 2, (lo_.y + hi_.y) / 2, lo_.z))
    k = float(height) / max(1e-6, hi_.z - lo_.z)
    from mathutils import Matrix
    m = Matrix.Translation(Vector((-gx, gz, gy))) @ Matrix.Rotation(math.radians(float(yaw)), 4, "Z") @ Matrix.Scale(k, 4) @ Matrix.Translation(-feet)
    for o in [o for o in set(bpy.context.scene.objects) - before]:
        if o.parent is None:
            o.matrix_world = m @ o.matrix_world
    for o in new:
        o["htd_stem"] = os.path.abspath(path)[:-4]
skip = set(filter(None, os.environ.get("HTD_SKIP", "").split(",")))
for o in [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.split(".")[0] in skip]:
    bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    base = o.name.split(".")[0]
    mat = bpy.data.materials.new("m")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    if base.startswith("c_"):
        r, g, b = (int(c) / 255 for c in base.split("_")[1:4])
        img = bpy.data.images.new("c", 2, 2)
        img.pixels = [r ** 2.2, g ** 2.2, b ** 2.2, 1] * 4
        if not o.data.uv_layers:
            o.data.uv_layers.new()
    elif os.environ.get("HTD_GREY") and not o.get("htd_stem"):   # (extras keep their paint)
        img = bpy.data.images.new("grey", 2, 2)
        img.pixels = [0.6, 0.6, 0.6, 1] * 4
        if not o.data.uv_layers:
            o.data.uv_layers.new()
    else:
        st_ = o.get("htd_stem", stem)
        cands = [f"{st_}_{base.lower()}_paint.png", f"{st_}_paint_{base[5:]}.png" if base.startswith("Skin_") else "", f"{st_}_paint.png"]
        path = next(p for p in cands if p and os.path.exists(p))
        img = bpy.data.images.load(path)
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat.node_tree.nodes.active = tex
    o.data.materials.clear()
    o.data.materials.append(mat)
lo = Vector((min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
hi = Vector((max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
center = (lo + hi) / 2
radius = (hi - lo).length / 2
frame = os.environ.get("HTD_FRAME")   # close-up: "x,y,z,width" (the view's centre and its width, Blender units)
if frame:
    fx, fy, fz, fw = (float(v) for v in frame.split(","))
    center = Vector((fx, fy, fz))
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO" if lit else "FLAT"
scene.display.shading.show_specular_highlight = False   # matte, like the paintings (no studio gloss)
scene.display.shading.color_type = "TEXTURE"
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.film_transparent = True
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
if ortho:
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = fw if frame else (hi - lo).length * 1.05
else:
    cam.data.lens = 50
d = radius * 3.0
cam.location = center + Vector((math.cos(az) * math.cos(el) * d, math.sin(az) * math.cos(el) * d, math.sin(el) * d))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
