"""Archer visibility from the run camera, simulated in Blender on a tower model (the film's test, before a
rebuild is uploaded): 8 directions round the tower, camera 20.5 studs from the tower's middle 4 studs up, 42 degrees
down (src/client/RunCamera.client.luau); a head counts as seen when at least half of 9 points on its camera side have
nothing of the tower in the way. Passes when at least one archer's head is seen in 7 of 8 directions.
Run: blender -b -P archer_visibility_sim.py -- tower.fbx "x,y,z" ["x,y,z" ...]   (archer feet, game studs, from ARCHER)"""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=args[0])
dg = bpy.context.evaluated_depsgraph_get()
heads = []
for a in args[1:]:
    gx, gy, gz = (float(v) for v in a.split(","))
    heads.append(Vector((-gx, gz, gy + 2.55)))   # game (x, y, z) -> Blender (-x, z, y); the head's middle ~2.55 up
focus = Vector((0, 0, 4))
passed, detail = 0, []
for k in range(8):
    a = math.radians(k * 45)
    look = Vector((math.sin(a), math.cos(a), 0))
    eye = focus - look * 20.5 * math.cos(math.radians(42)) + Vector((0, 0, 20.5 * math.sin(math.radians(42))))
    best = 0.0
    for h in heads:
        toward = Vector(((eye - h).x, (eye - h).y, 0)).normalized()
        right = Vector((0, 0, 1)).cross(toward).normalized()
        seen = 0
        offs = [(0, 0), (0.35, 0), (-0.35, 0), (0, 0.35), (0, -0.3), (0.25, 0.25), (-0.25, 0.25), (0.25, -0.2), (-0.25, -0.2)]
        for ox, oz in offs:
            pt = h + right * ox * 1.25 + Vector((0, 0, oz * 1.25)) + toward * 0.2
            d = pt - eye
            hit, loc, *_ = bpy.context.scene.ray_cast(dg, eye, d.normalized(), distance=d.length - 0.05)
            seen += 0 if hit else 1
        best = max(best, seen / len(offs))
    passed += best >= 0.5
    detail.append("%d:%.0f%%" % (k * 45, best * 100))
print("VISIBLE %d of 8 (%s) %s" % (passed, " ".join(detail), "PASS" if passed >= 7 else "FAIL"))
