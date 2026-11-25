"""Renders a finished pet model (Body + its painted texture, glow parts in their own colour) from several angles
in ONE Blender start, for the comparison sheets and the measured match (scripts/pet_cycle.sh, pet_match.py).
Run: blender -b -P pet_render.py -- model.fbx texture.png out_prefix angle [angle ...]
     angle 0 = straight from the front, 90 = from the pet's left; writes <out_prefix>_<angle>.png (700 x 700)
"""
import math
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
fbx, tex_path, prefix = os.path.abspath(args[0]), os.path.abspath(args[1]), os.path.abspath(args[2])
angles = [float(a) for a in args[3:]] or [24.0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = ([o for o in meshes if o.name.startswith("Body")] or meshes)[0]
for o in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if o is body or not o.name.startswith("c_"):
        continue
    try:
        r, g, b = [int(v) / 255 for v in o.name.split(".")[0].split("_")[1:4]]
    except ValueError:
        continue
    gm = bpy.data.materials.new("glow")
    gm.use_nodes = True
    em = gm.node_tree.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (r, g, b, 1)
    em.inputs["Strength"].default_value = 1.6
    gm.node_tree.links.new(em.outputs["Emission"], gm.node_tree.nodes.get("Material Output").inputs["Surface"])
    o.data.materials.clear()
    o.data.materials.append(gm)

image = bpy.data.images.load(tex_path)
mat = bpy.data.materials.new("preview")
mat.use_nodes = True
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = image
LIT = os.environ.get("HTD_LIT") == "1"
if LIT:
    # lit like the engine lights it (sun + sky on a slightly glossy surface): this is the view that shows facets,
    # lumps and uneven shading, which the flat "paint only" view hides
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
else:
    emit = mat.node_tree.nodes.new("ShaderNodeEmission")
    mat.node_tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
    mat.node_tree.links.new(emit.outputs["Emission"], mat.node_tree.nodes.get("Material Output").inputs["Surface"])
body.data.materials.clear()
body.data.materials.append(mat)

zs = [v.co.z for o in meshes for v in o.data.vertices]
z0, height = min(zs), max(zs) - min(zs)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x, scene.render.resolution_y = 700, 700
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.16, 0.16, 0.18)
if LIT:
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.62, 0.68, 0.78, 1)
    bg.inputs["Strength"].default_value = 0.75
    scene.render.film_transparent = True
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(52), math.radians(8), math.radians(-32))
    scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
target = bpy.data.objects.new("target", None)
target.location = (0, 0, z0 + height * 0.5)
scene.collection.objects.link(target)
track = cam.constraints.new("TRACK_TO")
track.target = target
scene.camera = cam
dist = height * 2.2
for a in angles:
    r = math.radians(a)
    cam.location = (math.sin(r) * dist, -math.cos(r) * dist, z0 + height * 0.75)
    scene.render.filepath = f"{prefix}_{a:g}.png"
    bpy.ops.render.render(write_still=True)
    if LIT:   # put the lit pet on the same dark ground as the other views
        img = bpy.data.images.load(scene.render.filepath)
        import numpy as np
        px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        ground = np.array([0.16, 0.16, 0.18]) ** (1 / 2.2)
        px[:, :3] = px[:, :3] * px[:, 3:4] + ground * (1 - px[:, 3:4])
        px[:, 3] = 1
        img.pixels.foreach_set(px.ravel())
        img.save()
        bpy.data.images.remove(img)
print("RENDERED", len(angles))
