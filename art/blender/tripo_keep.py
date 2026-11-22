"""Cleans a Tripo (image-to-3D) building for the Watch Keep, like tripo_clean.py, with surgery first:
  --drop x,y,z          delete the loose piece whose box holds this point (stray blobs; repeatable)
  --split x,y,z:NAME    make that loose piece its own part called NAME (e.g. a crystal that turns and glows)
  --beam "x,y,z;x,y,z;thick;x,y,z"  add a square timber between two points, painted like the piece at the last point
  --cap  (same)          a short end cap (brass) painted like the piece at its last point
  --tris N              triangle budget for the body (default 9000)    --tex N   texture size (default 1024)
Points are in the imported model's units (find them with tripo_islands.py). Output: out.fbx (Body + named parts,
standing on the ground, 2 units tall: the game scales it) and out_paint.png.
Run: blender -b -P tripo_keep.py -- in.glb out.fbx [options]"""
import os
import sys

import bmesh
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
opts = {"drop": [], "split": [], "beam": [], "cap": [], "tris": "9000", "tex": "1024"}
i = 2
while i < len(args):
    key = args[i].lstrip("-")
    if key in ("drop", "split", "beam", "cap"):
        opts[key].append(args[i + 1])
    else:
        opts[key] = args[i + 1]
    i += 2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.active_object
for mod in list(body.modifiers):
    body.modifiers.remove(mod)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

image = None
for mat in body.data.materials:
    if mat and mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                image = node.image
                break
    if image:
        break


def islands(bm):
    seen, found = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, faces = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            faces.append(g)
            for e in g.edges:
                for n in e.link_faces:
                    if n.index not in seen:
                        seen.add(n.index)
                        stack.append(n)
        vs = [v.co for g in faces for v in g.verts]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        found.append((faces, lo, hi))
    return found


def holding(found, point):
    inside = [isl for isl in found if all(isl[1][k] - 0.005 <= point[k] <= isl[2][k] + 0.005 for k in range(3))]
    return min(inside, key=lambda isl: len(isl[0])) if inside else None


bm = bmesh.new()
bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.faces.ensure_lookup_table()
found = islands(bm)
# mark pieces: 0 keep, -1 drop, >0 split into part n
mark = {}
for text in opts["drop"]:
    isl = holding(found, Vector([float(c) for c in text.split(",")]))
    if isl:
        print("DROP piece of", len(isl[0]), "faces at", tuple(round(c, 3) for c in isl[1]), "..", tuple(round(c, 3) for c in isl[2]))
        for f in isl[0]:
            mark[f.index] = -1
    else:
        print("DROP nothing at", text)
names = []
for text in opts["split"]:
    point, name = text.split(":")
    isl = holding(found, Vector([float(c) for c in point.split(",")]))
    if isl:
        names.append(name)
        print("SPLIT", name, len(isl[0]), "faces")
        for f in isl[0]:
            mark[f.index] = len(names)
    else:
        print("SPLIT nothing at", point)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if mark.get(f.index) == -1], context="FACES")


def add_box(bm, a, b, thick, sample, end_cap=None):
    """a timber from a to b (square, `thick` wide) painted with the texture of the piece at `sample`
    (its UVs copied face by face, so the grain and colour match the neighbouring beams)"""
    found = islands(bm)
    src_isl = holding(found, sample)
    uv = bm.loops.layers.uv.active
    src_faces = src_isl[0] if src_isl else []
    axis = (b - a).normalized()
    up = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    side = axis.cross(up).normalized() * thick / 2
    up = side.cross(axis).normalized() * thick / 2
    corners = [a + s * side + u * up for s, u in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    corners += [b + s * side + u * up for s, u in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    vs = [bm.verts.new(c) for c in corners]
    quads = ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0))
    for n, q in enumerate(quads):
        face = bm.faces.new([vs[k] for k in q])
        if src_faces and uv:
            donor = src_faces[(n * 7) % len(src_faces)]
            uvs = [l[uv].uv.copy() for l in donor.loops]
            for k, loop in enumerate(face.loops):
                loop[uv].uv = uvs[k % len(uvs)]
    print("ADDED timber", tuple(round(c, 3) for c in a), "->", tuple(round(c, 3) for c in b),
          "painted from", len(src_faces), "faces")


for text in opts.get("beam", []):
    p1, p2, thick, wood = text.split(";")
    add_box(bm, Vector([float(c) for c in p1.split(",")]), Vector([float(c) for c in p2.split(",")]), float(thick),
            Vector([float(c) for c in wood.split(",")]))
for text in opts.get("cap", []):
    p1, p2, thick, brass = text.split(";")
    add_box(bm, Vector([float(c) for c in p1.split(",")]), Vector([float(c) for c in p2.split(",")]), float(thick),
            Vector([float(c) for c in brass.split(",")]))
bm.to_mesh(body.data)
bm.free()

# split the named pieces off into their own objects
parts = []
for n, name in enumerate(names, start=1):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.faces.ensure_lookup_table()
    found = islands(bm)
    point = Vector([float(c) for c in opts["split"][n - 1].split(":")[0].split(",")])
    isl = holding(found, point)
    piece_faces = set(f.index for f in isl[0]) if isl else set()
    piece = body.copy()
    piece.data = body.data.copy()
    bpy.context.scene.collection.objects.link(piece)
    pm = bmesh.new()
    pm.from_mesh(piece.data)
    bmesh.ops.remove_doubles(pm, verts=pm.verts, dist=0.0005)
    pm.faces.ensure_lookup_table()
    bmesh.ops.delete(pm, geom=[f for f in pm.faces if f.index not in piece_faces], context="FACES")
    pm.to_mesh(piece.data)
    pm.free()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in piece_faces], context="FACES")
    bm.to_mesh(body.data)
    bm.free()
    piece.name = name
    piece.data.name = name
    parts.append(piece)

# fewer triangles on the body
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
target = int(opts["tris"])
before = len(body.data.polygons)
if before > target * 1.1:
    mod = body.modifiers.new("decimate", "DECIMATE")
    mod.ratio = target / before
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIANGLES body", before, "->", len(body.data.polygons), "parts", [len(p.data.polygons) for p in parts])

# stand everything on the ground, centred, 2 units tall (one transform for the body and its parts)
allv = [v.co for o in [body] + parts for v in o.data.vertices]
lo = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
hi = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
scale = 2.0 / (hi.z - lo.z)
cx, cy = (hi.x + lo.x) / 2, (hi.y + lo.y) / 2
for o in [body] + parts:
    for v in o.data.vertices:
        v.co = Vector(((v.co.x - cx) * scale, (v.co.y - cy) * scale, (v.co.z - lo.z) * scale))
body.name = "Body"
body.data.name = "Body"
for o in [body] + parts:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_smooth()

if image:
    tex = int(opts["tex"])
    image.scale(tex, tex)
    image.filepath_raw = out[:-4] + "_paint.png"
    image.file_format = "PNG"
    image.save()
    print("TEXTURE", image.filepath_raw)
else:
    print("TEXTURE none found (exported without texture?)")
for o in [body] + parts:
    o.data.materials.clear()
    o.data.materials.append(bpy.data.materials.new("baked_" + o.name))
bpy.ops.export_scene.fbx(filepath=out, use_selection=False, apply_unit_scale=True, global_scale=1.0,
                         axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", object_types={"MESH"})
print("EXPORTED", out)
