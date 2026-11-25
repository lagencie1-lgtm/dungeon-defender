"""Renders a model (fbx with its _paint.png, or glb) on a transparent background from a given angle, to compare with
a target picture (scripts/match_score.py). Run:
  blender -b -P render_match.py -- model.fbx out.png [azimuth=-90] [elevation=18] [size=768]
azimuth -90 looks at the model's front (-Y). Elevation in degrees above the horizon."""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
az = math.radians(float(args[2]) if len(args) > 2 else -90)
el = math.radians(float(args[3]) if len(args) > 3 else 18)
size = int(args[4]) if len(args) > 4 else 768
bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=src)
else:
    bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
paint = src[:-4] + "_paint.png"
for o in meshes:
    mat = bpy.data.materials.new("m_" + o.name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if o.name.startswith("c_"):
        r, g, b = (int(c) / 255 for c in o.name.split(".")[0].split("_")[1:4])
        bsdf.inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1)
        # Workbench in texture mode draws a part without an image white: give it a one-colour image
        img = bpy.data.images.new(o.name + "_c", 2, 2)
        img.pixels = [r ** 2.2, g ** 2.2, b ** 2.2, 1] * 4
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mat.node_tree.nodes.active = tex
        if not o.data.uv_layers:   # (no UVs: Workbench would skip the image)
            o.data.uv_layers.new()
    elif os.path.exists(paint):
        # each painted part wears its own texture: Body -> <model>_paint.png, Skin_roof -> <model>_paint_roof.png,
        # picture bodies' Head -> <model>_head_paint.png
        base = o.name.split(".")[0]
        own = [src[:-4] + "_paint_" + base[5:] + ".png"] if base.startswith("Skin_") else []
        own.append(src[:-4] + "_" + base.lower() + "_paint.png")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(next((p for p in own if os.path.exists(p)), paint))
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if src.lower().endswith(".fbx"):
        o.data.materials.clear()
        o.data.materials.append(mat)
lo = Vector((min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
hi = Vector((max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
center = (lo + hi) / 2
radius = (hi - lo).length / 2
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT" # albedo only: the pictures carry their own painted light
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_backface_culling = bool(os.environ.get("HTD_CULL"))   # (HTD_CULL=1: one-sided faces as the game draws them)
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"  # the paint as painted (the default AgX tone curve washes it grey)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 50
d = radius * 3.0
cam.location = center + Vector((math.cos(az) * math.cos(el) * d, math.sin(az) * math.cos(el) * d, math.sin(el) * d))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
# (HTD_ONLY_PART=Skin_barrel: the same camera, only that part drawn: its outline inside the whole model's picture)
only = os.environ.get("HTD_ONLY_PART")
if only:
    import re   # ("re:<pattern>": every mesh whose name matches, e.g. the bow's parts in a fast build)
    for o in meshes:
        o.hide_render = not re.search(only[3:], o.name) if only.startswith("re:") else o.name.split(".")[0] != only
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
