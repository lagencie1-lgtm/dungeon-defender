"""Cleans an image-to-3D model (Tripo: .glb, .fbx or .obj) for the game: joins it into one mesh called Body,
reduces it to a phone-friendly triangle count, stands it on the ground at the origin and saves its texture as one
picture, like the models from paint.bake(). The game then treats it like any other painted model.
Run: blender -b -P tripo_clean.py -- in.glb out.fbx [triangles=2500] [texture=512]
Writes out.fbx and out_paint.png."""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
target = int(args[2]) if len(args) > 2 else 2500
tex_size = int(args[3]) if len(args) > 3 else 512

bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(src)[1].lower()
if ext in (".glb", ".gltf"):
    bpy.ops.import_scene.gltf(filepath=src)
elif ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=src)
elif ext == ".obj":
    bpy.ops.wm.obj_import(filepath=src)
else:
    sys.exit("unknown model format: " + ext)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    sys.exit("no mesh in " + src)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
# drop skeletons and parents but keep where things are
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.active_object
for mod in list(body.modifiers):
    body.modifiers.remove(mod)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# the texture: the base colour image of the first material that has one
image = None
for mat in body.data.materials:
    if mat and mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                image = node.image
                break
    if image:
        break

# fewer triangles
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005)
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
before = len(body.data.polygons)
if before > target * 1.15:  # (close enough: leave it, every cut costs a little paint quality)
    mod = body.modifiers.new("decimate", "DECIMATE")
    mod.ratio = target / before
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIANGLES", before, "->", len(body.data.polygons))

# stand it on the ground, centred, about 2 units tall (the game scales it per enemy anyway)
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
zs = [v.co.z for v in body.data.vertices]
height = max(zs) - min(zs)
scale = 2.0 / height if height > 0 else 1.0
cx, cy, base = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs)
for v in body.data.vertices:
    v.co.x = (v.co.x - cx) * scale
    v.co.y = (v.co.y - cy) * scale
    v.co.z = (v.co.z - base) * scale
body.name = "Body"
body.data.name = "Body"
bpy.ops.object.shade_smooth()

if image:
    image.scale(tex_size, tex_size)
    image.filepath_raw = out[:-4] + "_paint.png"
    image.file_format = "PNG"
    image.save()
    print("TEXTURE", image.filepath_raw)
else:
    print("TEXTURE none found")

# one plain material (the game applies the texture itself)
body.data.materials.clear()
body.data.materials.append(bpy.data.materials.new("baked"))
bpy.ops.export_scene.fbx(filepath=out, use_selection=False, apply_unit_scale=True, global_scale=1.0,
                         axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", object_types={"MESH"})
print("EXPORTED", out)
