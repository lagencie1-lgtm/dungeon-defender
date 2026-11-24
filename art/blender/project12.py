"""Twelve-view painterly projection for the towers (coordinator round C: "one trial on Flame Cannon level 2 with 8 views
around plus 4 from above, and where a spot gets no direct paint keep the current paint instead of the painter's
tone"). The pets' pet_project.py stays as it is; this is the towers' own, on the same packed mesh
(art/blender/paint_pack.py).
  blender -b -P project12.py -- views <pack.fbx> <base.png> <out_dir>   renders the 12 views (colour png + where each
                                                                       pixel is on the model, npy) and cams.json
  blender -b -P project12.py -- bake  <pack.fbx> <out_dir> <size>      the atlas' texel positions and normals (npy)"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
mode, fbx = args[0], os.path.abspath(args[1])
CELL = 512
# 8 round the tower a little above the eye, 4 from above (between them)
VIEWS = [(f"round{a}", a, 12) for a in range(0, 360, 45)] + [(f"above{a}", a, 50) for a in (22, 112, 202, 292)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
mw = obj.matrix_world
co = np.array([tuple(mw @ v.co) for v in obj.data.vertices])
lo, hi = co.min(0), co.max(0)
centre = Vector(((lo + hi) / 2).tolist())
span = float(np.linalg.norm(hi - lo)) * 1.02
sc = bpy.context.scene
EXT = float((hi - lo).max()) + 0.2
LO = lo - 0.1   # positions are stored as (p - LO) / EXT, normals as n / 2 + 1/2 (colours stay in 0..1)


def encode(nt, socket, normal=False):
    m = nt.nodes.new("ShaderNodeVectorMath")
    m.operation = "MULTIPLY_ADD"
    nt.links.new(socket, m.inputs[0])
    if normal:
        m.inputs[1].default_value = (0.5, 0.5, 0.5)
        m.inputs[2].default_value = (0.5, 0.5, 0.5)
    else:
        m.inputs[1].default_value = (1 / EXT,) * 3
        m.inputs[2].default_value = tuple(float(-v / EXT) for v in LO)
    return m.outputs[0]


def emission_material(node_fn):
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    node_fn(nt, em)
    return m, nt


if mode == "views":
    base, outd = os.path.abspath(args[2]), os.path.abspath(args[3])
    os.makedirs(outd, exist_ok=True)
    img = bpy.data.images.load(base)

    def tex(nt, em):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        nt.links.new(t.outputs["Color"], em.inputs["Color"])
    colour, _ = emission_material(tex)

    def pos(nt, em):
        g = nt.nodes.new("ShaderNodeNewGeometry")
        nt.links.new(encode(nt, g.outputs["Position"]), em.inputs["Color"])
    where, _ = emission_material(pos)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span
    sc.render.resolution_x = sc.render.resolution_y = CELL
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.cycles.use_denoising = False
    sc.render.filter_size = 0.01
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = True
    cams = []
    for name, az, el in VIEWS:
        a, e = math.radians(az), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), -math.sin(e)))   # looking along d
        cam.location = centre - d * span * 2
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        right = Vector(cam.matrix_world.to_3x3() @ Vector((1, 0, 0)))
        up = Vector(cam.matrix_world.to_3x3() @ Vector((0, 1, 0)))
        cams.append({"name": name, "d": list(d), "right": list(right), "up": list(up)})
        for mat, kind in ((colour, "colour"), (where, "where")):
            obj.data.materials.clear()
            obj.data.materials.append(mat)
            if kind == "colour":
                sc.render.image_settings.file_format = "PNG"
                path = os.path.join(outd, f"{name}.png")
            else:
                sc.render.image_settings.file_format = "OPEN_EXR"
                sc.render.image_settings.color_depth = "32"
                path = os.path.join(outd, f"{name}_where.exr")
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
            if kind == "where":
                im = bpy.data.images.load(path)
                px = np.array(im.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4)[::-1]
                np.save(os.path.join(outd, f"{name}_where.npy"), px)
                bpy.data.images.remove(im)
    json.dump({"lo": LO.tolist(), "ext": EXT, "centre": list(centre), "span": span, "cell": CELL, "views": cams}, open(os.path.join(outd, "cams.json"), "w"), indent=1)
    print("VIEWS12", outd)

elif mode == "bake":
    outd, size = os.path.abspath(args[2]), int(args[3])
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.render.bake.margin = 0
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for kind, socket in (("pos", "Position"), ("nrm", "Normal")):
        def fn(nt, em, socket=socket):
            g = nt.nodes.new("ShaderNodeNewGeometry")
            nt.links.new(encode(nt, g.outputs[socket], normal=socket == "Normal"), em.inputs["Color"])
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = bpy.data.images.new(kind, size, size, float_buffer=True, alpha=True)
            t.image.generated_color = (0, 0, 0, 0)
            nt.nodes.active = t
            return t
        mat, nt = emission_material(lambda nt, em: None)
        node = fn(nt, nt.nodes["Emission"])
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        bpy.ops.object.bake(type="EMIT")
        px = np.array(node.image.pixels[:], dtype=np.float32).reshape(size, size, 4)[::-1]
        np.save(os.path.join(outd, f"atlas_{kind}.npy"), px)
    json.dump({"lo": LO.tolist(), "ext": EXT}, open(os.path.join(outd, "atlas_code.json"), "w"))
    print("BAKED12", outd)
