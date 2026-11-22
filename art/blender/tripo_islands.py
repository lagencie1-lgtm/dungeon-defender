"""Lists the loose pieces ("islands") of an image-to-3D model with their size, place and average painted colour,
so stray blobs can be found and removed by number (tripo_keep.py).
Run: blender -b -P tripo_islands.py -- in.glb"""
import os
import sys

import bmesh
import bpy

args = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args[0]))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.active_object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

image = None
for slot in body.material_slots:
    for node in slot.material.node_tree.nodes if slot.material and slot.material.node_tree else []:
        if node.type == "TEX_IMAGE" and node.image:
            image = node.image
            break
pixels = list(image.pixels) if image else None
w, h = (image.size[0], image.size[1]) if image else (0, 0)

bm = bmesh.new()
bm.from_mesh(body.data)
# the export splits vertices at every texture seam: weld them so islands are real loose pieces
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.active
seen = set()
islands = []
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
    verts = {v for g in faces for v in g.verts}
    xs = [v.co.x for v in verts]
    ys = [v.co.y for v in verts]
    zs = [v.co.z for v in verts]
    col = (0.0, 0.0, 0.0)
    if pixels and uv:
        r = gg = b = 0.0
        n = 0
        for g in faces[::max(1, len(faces) // 200)]:
            for loop in g.loops:
                u, v = loop[uv].uv
                px = int((u % 1) * (w - 1))
                py = int((v % 1) * (h - 1))
                i = (py * w + px) * 4
                r += pixels[i]
                gg += pixels[i + 1]
                b += pixels[i + 2]
                n += 1
        col = (r / n, gg / n, b / n) if n else col
    islands.append((len(faces), (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs)), col))
islands.sort(key=lambda i: -i[0])
lo = min(i[3][0] for i in islands)
hi = max(i[3][1] for i in islands)
print("MODEL height", round(hi - lo, 3), "faces", len(bm.faces), "islands", len(islands), "texture", image and image.size[:])
for n, (faces, x, y, z, c) in enumerate(islands[:40]):
    print("ISLAND %2d faces %6d  x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f  rgb %.2f %.2f %.2f" % (
        n, faces, x[0], x[1], y[0], y[1], z[0], z[1], c[0], c[1], c[2]))
