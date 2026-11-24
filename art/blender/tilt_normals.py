"""Tilts a model's stored vertex normals toward the sky (coordinator round C, C4: "keep the paint at the painting's
colours and tilt the vertex normals of the upright surfaces toward the sky ... Roblox keeps the normals stored in the
file, so upright surfaces should catch more light"). Each normal is blended with straight up and normalised again:
  the face (Head, inside the hood's opening, looking to the front)   share 0.40
  the tunic (Body between the boots' top and the collar) and both arms   share 0.25
  everything else unchanged. Paint and shape are untouched; the textures are copied beside the new file.
Run: blender -b -P tilt_normals.py -- in.fbx out.fbx [face=0.4] [cloth=0.25]"""
import os
import shutil
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import lib  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = os.path.abspath(args[0]), os.path.abspath(args[1])
opt = dict(a.split("=") for a in args[2:] if "=" in a)
FACE, CLOTH = float(opt.get("face", 0.4)), float(opt.get("cloth", 0.25))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
UP = Vector((0, 0, 1))
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    base = o.name.split(".")[0]
    me = o.data
    mw = o.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
    out = []
    n_tilted = 0
    for loop in me.loops:
        n = (nm @ loop.normal).normalized()
        p = mw @ me.vertices[loop.vertex_index].co
        w = 0.0
        if base == "Head" and n.y < -0.4 and abs(p.x) < 0.32 and 1.5 < p.z < 2.15:
            w = FACE
        elif base == "Body" and 0.62 < p.z < 1.5:
            w = CLOTH
        elif base in ("ArmL", "ArmR"):
            w = CLOTH
        if w:
            n = (n * (1 - w) + UP * w).normalized()
            n_tilted += 1
        out.append(tuple(nm.inverted() @ n))
    if n_tilted:
        me.normals_split_custom_set([Vector(v).normalized() for v in out])
    print("TILTED", base, n_tilted, "of", len(me.loops), "corners")
lib.export_fbx(dst)
d0, d1 = os.path.dirname(src), os.path.dirname(dst)
if d0 != d1:
    for f in os.listdir(d0):
        if f.endswith("_paint.png") or f == "gates_build.json":
            shutil.copy(os.path.join(d0, f), os.path.join(d1, f))
print("EXPORTED", dst)
