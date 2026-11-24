"""Renders the archer (ranger_archer + ranger_archer_arms, each with its <name>_paint.png) like render_match.py:
flat albedo, transparent background, from an angle. Run:
  blender -b -P archer_render.py -- folder out.png [azimuth=-115] [elevation=12] [size=768] [lit]
lit = soft studio light instead of flat albedo (the beauty render)."""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
folder, out = os.path.abspath(args[0]), os.path.abspath(args[1])
az = math.radians(float(args[2]) if len(args) > 2 else -115)
el = math.radians(float(args[3]) if len(args) > 3 else 12)
size = int(args[4]) if len(args) > 4 else 768
lit = len(args) > 5 and args[5] == "lit"
bpy.ops.wm.read_factory_settings(use_empty=True)
meshes = []
for name in ("ranger_archer", "ranger_archer_arms"):
    path = os.path.join(folder, name + ".fbx")
    if not os.path.exists(path):
        continue
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    for o in set(bpy.context.scene.objects) - before:
        if o.type != "MESH":
            continue
        meshes.append(o)
        mat = bpy.data.materials.new("m")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        if o.name.startswith("c_"):
            r, g, b = (int(c) / 255 for c in o.name.split(".")[0].split("_")[1:4])
            img = bpy.data.images.new("c", 2, 2)
            img.pixels = [r ** 2.2, g ** 2.2, b ** 2.2, 1] * 4
            if not o.data.uv_layers:
                o.data.uv_layers.new()
        else:
            img = bpy.data.images.load(os.path.join(folder, name + "_paint.png"))
        tex.image = img
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mat.node_tree.nodes.active = tex
        o.data.materials.clear()
        o.data.materials.append(mat)
lo = Vector((min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
hi = Vector((max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
center = (lo + hi) / 2
radius = (hi - lo).length / 2
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO" if lit else "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.film_transparent = True
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 50
d = radius * 3.0
cam.location = center + Vector((math.cos(az) * math.cos(el) * d, math.sin(az) * math.cos(el) * d, math.sin(el) * d))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
