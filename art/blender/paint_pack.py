"""Packs any painted model's parts into one mesh with one atlas, so the pets' painterly projection
(art/blender/pet_project.py, unchanged) can paint it (towers: Body plus Skin_roof, Skin_props, Skin_barrel ...).
The parts' own texture layouts go side by side in an N x N atlas of 1024 px cells; cells.json says which part is in
which cell and at what size its picture was, so scripts/tower_painterly.py can cut the atlas back.
Textures are found the way art/blender/parts_render.py finds them: Body = <stem>_paint.png, Skin_x =
<stem>_paint_x.png, any other part <stem>_<part>_paint.png.
Run: blender -b -P paint_pack.py -- <model.fbx> <out_dir> [skip=PartA,PartB]"""
import json
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
args = sys.argv[sys.argv.index("--") + 1:]
fbx, out = os.path.abspath(args[0]), os.path.abspath(args[1])
skip = set(next((a[5:].split(",") for a in args[2:] if a.startswith("skip=")), []))
stem = fbx[:-4]
C = 1024


def tex_of(base):
    for p in (f"{stem}_{base.lower()}_paint.png", f"{stem}_paint_{base[5:]}.png" if base.startswith("Skin_") else "",
              f"{stem}_paint.png" if base == "Body" else ""):
        if p and os.path.exists(p):
            return p
    return None


def load(path, size):
    im = bpy.data.images.load(path)
    w = im.size[0]
    if w != size:
        im.scale(size, size)
    a = np.empty(size * size * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    return np.flipud(a.reshape(size, size, 4)), w


def save(path, arr):
    h, w = arr.shape[:2]
    im = bpy.data.images.new("out", w, h, alpha=True)
    im.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()


os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
parts = []
for o in list(bpy.context.scene.objects):
    base = o.name.split(".")[0]
    if o.type != "MESH" or base in skip or base.startswith("c_") or not o.data.uv_layers or not tex_of(base):
        bpy.data.objects.remove(o, do_unlink=True)
        continue
    parts.append((base, o))
parts.sort(key=lambda t: (t[0] != "Body", t[0]))
N = max(1, math.ceil(math.sqrt(len(parts))))
atlas = np.ones((N * C, N * C, 4), dtype=np.float32)
keep = np.zeros((N * C, N * C, 4), dtype=np.float32)
keep[..., 3] = 1
cells = {}
for i, (base, o) in enumerate(parts):
    cx, cy = i % N, i // N
    for d in o.data.uv_layers.active.data:
        d.uv = ((d.uv[0] + cx) / N, (d.uv[1] + (N - 1 - cy)) / N)
    arr, size = load(tex_of(base), C)
    atlas[cy * C:(cy + 1) * C, cx * C:(cx + 1) * C] = arr
    cells[base] = {"cx": cx, "cy": cy, "size": size, "texture": tex_of(base)}
    o.data.materials.clear()
bpy.ops.object.select_all(action="DESELECT")
for _, o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0][1]
bpy.ops.object.join()
j = bpy.context.view_layer.objects.active
j.name = j.data.name = "Body"
save(os.path.join(out, "pack_base.png"), atlas)
save(os.path.join(out, "pack_keep.png"), keep)
json.dump({"n": N, "cell": C, "parts": cells}, open(os.path.join(out, "cells.json"), "w"), indent=1)
import lib  # noqa: E402
lib.export_fbx(os.path.join(out, "pack.fbx"))
print("PACKED", out, len(parts), "parts in", N, "x", N)
