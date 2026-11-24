"""Round D (coordinator D1: "take colour and shading straight from the paintings"): what the archer's clean model
sheet (art/ref3d/archer/ranger_archer_elf.png: front, his right side, back) can paint, and where.
  where <model.fbx> <out>   renders, for the front, back, right side and left side (the right side's painting is mirrored
                            for it), where on the model each pixel of that view is, at the sheet's own scale and place
                            (880 x 880, the sheet's rows 0..880, its view's middle column in the middle); all parts,
                            the bow and quiver too (they hide what is behind them). Saves <view>_where.npy.
  bake <model.fbx> <out>    every part's texel positions and normals at its texture's size (<part>_pos.npy, _nrm.npy)
Positions are stored as (p - LO) / EXT, normals as n / 2 + 1/2 (code.json)."""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
mode, fbx, outd = args[0], os.path.abspath(args[1]), os.path.abspath(args[2])
os.makedirs(outd, exist_ok=True)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = json.load(open(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_loft.json")))
S, CX, SX, G = SPEC["scale"], SPEC["cx"], SPEC["sx"], SPEC["ground"]
BX = 1448.5                       # the back view's middle column (its outline and its legs agree)
N = 880
LO, EXT = Vector((-1.5, -1.5, -0.2)), 3.2
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
sc = bpy.context.scene


def material(normal=False):
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    g = nt.nodes.new("ShaderNodeNewGeometry")
    v = nt.nodes.new("ShaderNodeVectorMath")
    v.operation = "MULTIPLY_ADD"
    nt.links.new(g.outputs["Normal" if normal else "Position"], v.inputs[0])
    if normal:
        v.inputs[1].default_value = (0.5, 0.5, 0.5)
        v.inputs[2].default_value = (0.5, 0.5, 0.5)
    else:
        v.inputs[1].default_value = (1 / EXT,) * 3
        v.inputs[2].default_value = tuple(-c / EXT for c in LO)
    nt.links.new(v.outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m, nt


json.dump({"lo": list(LO), "ext": EXT, "bx": BX, "n": N}, open(os.path.join(outd, "code.json"), "w"))
sc.render.engine = "CYCLES"
sc.cycles.samples = 1
sc.cycles.use_denoising = False
if mode == "where":
    m, _ = material()
    for o in meshes:
        o.data.materials.clear()
        o.data.materials.append(m)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = N * S
    sc.render.resolution_x = sc.render.resolution_y = N
    sc.render.filter_size = 0.01
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "OPEN_EXR"
    sc.render.image_settings.color_depth = "32"
    zc = (G - N / 2) * S
    # view: camera direction (looking along), the model point at the picture's middle
    views = {"front": (Vector((0, 1, 0)), Vector((0, 0, zc))),
             "back": (Vector((0, -1, 0)), Vector(((BX - BX) * S, 0, zc))),
             "right": (Vector((1, 0, 0)), Vector((0, 0, zc))),
             "left": (Vector((-1, 0, 0)), Vector((0, 0, zc)))}
    for name, (d, c) in views.items():
        cam.location = c - d * 10
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(outd, f"{name}_where.exr")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(path)
        px = np.array(im.pixels[:], dtype=np.float32).reshape(N, N, 4)[::-1]
        np.save(os.path.join(outd, f"{name}_where.npy"), px)
        bpy.data.images.remove(im)
    print("WHERE", outd)
elif mode == "bake":
    # (4 px past every island's edge: the edge texels need a position too, or they keep the old paint and show as a
    # thin line along every cut)
    sc.render.bake.margin = 4
    sc.render.bake.margin_type = "EXTEND"
    for o in meshes:
        base = o.name.split(".")[0]
        if base not in ("Head", "Body", "ArmL", "ArmR"):
            continue
        size = 1024 if base in ("Head", "Body") else 512
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for kind, normal in (("pos", False), ("nrm", True)):
            m, nt = material(normal)
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = bpy.data.images.new(kind, size, size, float_buffer=True, alpha=True)
            t.image.generated_color = (0, 0, 0, 0)
            nt.nodes.active = t
            o.data.materials.clear()
            o.data.materials.append(m)
            bpy.ops.object.bake(type="EMIT")
            px = np.array(t.image.pixels[:], dtype=np.float32).reshape(size, size, 4)[::-1]
            np.save(os.path.join(outd, f"{base.lower()}_{kind}.npy"), px)
    print("BAKED", outd)
