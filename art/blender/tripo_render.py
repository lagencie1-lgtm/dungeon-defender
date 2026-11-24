"""Renders a model (glb or fbx, with its texture) from four sides into one picture, for before/after checks.
Run: blender -b -P tripo_render.py -- in.glb out.png [size=512]"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
size = int(args[2]) if len(args) > 2 else 512
bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=src)
else:
    bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
paint_path = src[:-4] + "_paint.png"
if src.lower().endswith(".fbx"):
    # a cleaned model: the body wears its paint picture, the c_R_G_B parts their own colour (as in the game)
    for o in meshes:
        mat = bpy.data.materials.new("show_" + o.name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if o.name.startswith("c_"):
            r, g, b = (int(c) / 255 for c in o.name.split("_")[1:4])
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
        elif os.path.exists(paint_path):
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(paint_path)
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        o.data.materials.clear()
        o.data.materials.append(mat)
lo = Vector((min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
hi = Vector((max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in meshes) for i in range(3)))
center = (lo + hi) / 2
radius = (hi - lo).length / 2

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
world.color = (0.92, 0.92, 0.92)
scene.world = world
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 50

frames = []
for i, angle in enumerate((-90, -45, 0, 90)):
    a = math.radians(angle)
    d = radius * 3.2
    cam.location = center + Vector((math.cos(a) * d, math.sin(a) * d, radius * 0.9))
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = out[:-4] + f"_{i}.png"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    frames.append(path)
print("RENDERED", frames)
