"""Measures every built map kit piece (art/models/mapkit/*.fbx): its bounding box in the build script's own
coordinates (X along the piece, Y front to back, Z up). Writes art/models/mapkit/boxes.json; scripts/map_kit_data.py
turns that into src/server/MapKit.luau. Run: blender -b -P map_kit_boxes.py"""
import glob
import json
import os

import bpy
from mathutils import Vector

kit = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models", "mapkit")
boxes = {}
for f in sorted(glob.glob(os.path.join(kit, "mapkit_*.fbx"))):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.abspath(f))
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    boxes[os.path.basename(f)[:-4]] = {"min": [round(c, 3) for c in lo], "max": [round(c, 3) for c in hi]}
json.dump(boxes, open(os.path.join(kit, "boxes.json"), "w"), indent=1)
print("BOXES", len(boxes))
