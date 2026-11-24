"""Removes vertex colours from a model file, in place (geometry, UVs and part names unchanged). Roblox multiplies a
MeshPart's texture by its vertex colours: helper colour layers left in a file tint the paint (the archer's face went
dark green, his hood lime). Run: blender -b -P strip_vertex_colours.py -- model.fbx"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
fbx = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
n = 0
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        for ca in list(o.data.color_attributes):
            o.data.color_attributes.remove(ca)
            n += 1
import lib  # noqa: E402
lib.export_fbx(fbx)
print("STRIPPED", n, "colour layers from", fbx)
