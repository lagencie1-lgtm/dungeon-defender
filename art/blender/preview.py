"""Renders a quick look-sheet picture of a built model (FBX) so it can be checked without Studio.
Run: blender -b -P art/blender/preview.py -- art/models/tower_ranger.fbx out.png"""
import math
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
fbx, out = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.context.view_layer.update()
top = max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in objs)
print("TOP", top)

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "VERTEX"
scene.display.shading.show_shadows = True
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.12, 0.10, 0.09)

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
dist = top * 1.9
cam.location = (dist * 0.75, -dist * 0.75, top * 0.75)
target = bpy.data.objects.new("target", None)
target.location = (0, 0, top * 0.45)
scene.collection.objects.link(target)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("PREVIEW", out)
