"""The archer visibility test in Blender, measured the way the film now measures it (round C: scripts/film_probe.py):
the run camera (20.5 studs from the tower's middle 4 studs up, 42 degrees down, 70 degrees field of view, 8
directions) renders each archer's head in a flat colour; seen share = its pixels with the tower in the way / its
pixels drawn alone. A head counts as seen at 50 % or more. The archers are the real model (ranger_archer.fbx), scaled
to their game height and stood on the anchors.
Run: blender -b -P archer_visibility_px.py -- tower.fbx archer.fbx out_dir "x,y,z,yaw,height" ["x,y,z,yaw,height" ...]
     (feet in game studs as TowerService's Archers, yaw in degrees)"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
tower_fbx, archer_fbx, out = os.path.abspath(args[0]), os.path.abspath(args[1]), os.path.abspath(args[2])
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
COL = [(1, 0, 1), (0, 1, 1), (1, 1, 0)]


def flat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    return m


white = flat("tower", (0.8, 0.8, 0.8))
grey = flat("archer", (0.5, 0.5, 0.5))
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=tower_fbx)
tower = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
for o in tower:
    o.data.materials.clear()
    o.data.materials.append(white)
heads, others = [], []
for i, a in enumerate(args[3:]):
    gx, gy, gz, yaw, height = (float(v) for v in a.split(","))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=archer_fbx)
    parts = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
    bpy.context.view_layer.update()
    lo = min(min((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in parts)
    hi = max(max((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in parts)
    s = height / (hi - lo)
    root = bpy.data.objects.new(f"Archer{i}", None)
    bpy.context.scene.collection.objects.link(root)
    for o in parts:
        o.parent = root
        o.matrix_parent_inverse = root.matrix_world.inverted()
    root.scale = (s, s, s)
    root.location = Vector((-gx, gz, gy - lo * s))   # game (x, y, z) -> Blender (-x, z, y), feet on the anchor
    root.rotation_euler = (0, 0, math.radians(yaw))
    for o in parts:
        o.data.materials.clear()
        if o.name.split(".")[0] == "Head":
            o.data.materials.append(flat(f"head{i}", COL[i]))
            heads.append(o)
        else:
            o.data.materials.append(grey)
            others.append(o)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "MATERIAL"
sc.view_settings.view_transform = "Standard"
sc.render.resolution_x, sc.render.resolution_y = 640, 360
sc.render.film_transparent = True
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.sensor_fit = "VERTICAL"
cam.data.angle_y = math.radians(70)
focus = Vector((0, 0, 4))
res = {}
both = one = 0
for k in range(8):
    a = math.radians(k * 45)
    look = Vector((-math.sin(a), math.cos(a), 0))   # (the game's (sin a, cos a) in x, z; Blender x is the game's -x)
    eye = focus - look * 20.5 * math.cos(math.radians(42)) + Vector((0, 0, 20.5 * math.sin(math.radians(42))))
    cam.location = eye
    cam.rotation_euler = (focus - eye).to_track_quat("-Z", "Y").to_euler()
    counts = {}
    for mode in ("seen", "whole"):
        for o in tower + others:
            o.hide_render = mode == "whole"
        path = os.path.join(out, f"px_{k * 45}_{mode}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(path)
        px = np.array(im.pixels[:]).reshape(im.size[1], im.size[0], 4)
        counts[mode] = [int(((np.abs(px[..., :3] - np.array(c)).max(-1) < 0.15) & (px[..., 3] > 0.5)).sum()) for c in COL[:len(heads)]]
        bpy.data.images.remove(im)
    shares = [s / w if w else None for s, w in zip(counts["seen"], counts["whole"])]
    seen = [x is not None and x >= 0.5 for x in shares]
    both += all(seen)
    one += any(seen)
    res[k * 45] = {"shares": shares, "counts": counts}
    print("PX %3d: %s" % (k * 45, "  ".join("%.0f%%" % (100 * x) if x is not None else "-" for x in shares)))
print("PX both archers seen in %d of 8, at least one in %d of 8" % (both, one))
json.dump({"directions": res, "both": both, "one": one}, open(os.path.join(out, "visibility_px.json"), "w"), indent=1)
