"""A quick look at built map kit pieces: renders each FBX with its baked paint from the run camera's angle
(42 degrees down) and tiles the pictures. Run: blender -b -P map_kit_view.py -- out.png a.fbx b.fbx ..."""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, files = os.path.abspath(args[0]), args[1:]
tiles = []
for n, f in enumerate(files):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    f = os.path.abspath(f)
    bpy.ops.import_scene.fbx(filepath=f)
    new = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    img = bpy.data.images.load(f[:-4] + "_paint.png")
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in new:
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
        bsdf.inputs["Roughness"].default_value = 0.9
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 520
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
    g = bpy.data.materials.new("g")
    g.use_nodes = True
    g.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.22, 0.3, 0.16, 1)
    bpy.context.active_object.data.materials.append(g)
    # a 5.5-stud hero for scale
    bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=5.5, location=(hi.x + 2.5, lo.y - 1.0, 2.75))
    h = bpy.data.materials.new("h")
    h.use_nodes = True
    h.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.8, 0.2, 0.2, 1)
    bpy.context.active_object.data.materials.append(h)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2 + 2
    pitch, yaw = math.radians(42), math.radians(-28)
    d = radius / math.tan(math.radians(20)) * 1.05
    cam.data.lens = 50
    cam.data.sensor_width = 36
    cam.data.angle = math.radians(40)
    cam.location = centre + Vector((math.sin(yaw) * math.cos(pitch) * d, -math.cos(yaw) * math.cos(pitch) * d, math.sin(pitch) * d))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    tile = out[:-4] + f"_{n}.png"
    scene.render.filepath = tile
    bpy.ops.render.render(write_still=True)
    tiles.append(tile)
print("TILES", "|".join(tiles))
