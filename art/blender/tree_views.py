"""Views of map objects from all sides (the tower workflow's "check from all sides"): for each FBX, the run camera's
angle (42 degrees down) and four sides 90 degrees apart, 12 degrees up, in one row; rows stacked for several files.
Shaded like the game (baked paint, a sun from the top-left, sky light), on a meadow-green ground.
Run: blender -b -P tree_views.py -- out.png a.fbx [b.fbx ...]"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, files = os.path.abspath(args[0]), args[1:]
VIEWS = [(42, -28), (12, 0), (12, 90), (12, 180), (12, 270)]
SIZE = 420
tiles = []
for n, f in enumerate(files):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    f = os.path.abspath(f)
    bpy.ops.import_scene.fbx(filepath=f)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    img = bpy.data.images.load(f[:-4] + "_paint.png")
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        mat = bpy.data.materials.new("m")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if o.name.startswith("Body"):
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = img
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            c = [int(v) / 255 for v in o.name.split(".")[0].split("_")[1:4]]
            bsdf.inputs["Base Color"].default_value = (*c, 1)
            bsdf.inputs["Emission Color"].default_value = (*c, 1)
            bsdf.inputs["Emission Strength"].default_value = 2.5
        bsdf.inputs["Roughness"].default_value = 0.95
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(-40))
    scene.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
    g = bpy.data.materials.new("g")
    g.use_nodes = True
    g.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.25, 0.34, 0.17, 1)
    bpy.context.active_object.data.materials.append(g)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2 + 1
    for k, (pitch, yaw) in enumerate(VIEWS):
        p, y = math.radians(pitch), math.radians(yaw)
        d = radius / math.tan(math.radians(17))
        cam.data.angle = math.radians(36)
        cam.location = centre + Vector((math.sin(y) * math.cos(p) * d, -math.cos(y) * math.cos(p) * d, math.sin(p) * d))
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        tile = out[:-4] + f"_{n}_{k}.png"
        scene.render.filepath = tile
        bpy.ops.render.render(write_still=True)
        tiles.append(tile)
print("TILES", "|".join(tiles))
print("ROWS", len(files), "COLS", len(VIEWS))
