"""Small paint fixes on a cleaned image-to-3D model (tripo_clean.py output), and a textured preview picture.
Repaints one colour inside a region of the model, working on the texture through the model's own UVs.
Run: blender -b -P tripo_fix.py -- model.fbx texture.png preview.png [fix-name]
Fixes:
  goblin_cuffs  the smudged gold dots on the wrist cuffs become plain leather (Lemp 2026-11-19)
"""
import math
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
fbx, tex_path, preview = os.path.abspath(args[0]), os.path.abspath(args[1]), os.path.abspath(args[2])
fix = args[3] if len(args) > 3 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
all_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = ([o for o in all_meshes if o.name.startswith("Body")] or all_meshes)[0]
# glowing parts (named c_R_G_B) show in their own colour in the preview
for o in all_meshes:
    if o is not body and o.name.startswith("c_"):
        try:
            r, g, b = [int(v) / 255 for v in o.name.split(".")[0].split("_")[1:4]]
        except ValueError:
            continue
        gm = bpy.data.materials.new("glow")
        gm.use_nodes = True
        em = gm.node_tree.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (r, g, b, 1)
        em.inputs["Strength"].default_value = 1.6
        gm.node_tree.links.new(em.outputs["Emission"], gm.node_tree.nodes.get("Material Output").inputs["Surface"])
        o.data.materials.clear()
        o.data.materials.append(gm)
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        o.select_set(False)
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
image = bpy.data.images.load(tex_path)
W, H = image.size
pixels = list(image.pixels)
mesh = body.data
uv = mesh.uv_layers.active.data
xs = [v.co.x for v in mesh.vertices]
zs = [v.co.z for v in mesh.vertices]
half_w, height = max(abs(min(xs)), abs(max(xs))), max(zs) - min(zs)
z0 = min(zs)


def repaint(in_region, is_bad, patch=4):
    """For every face inside the region: texels that match is_bad take the average colour of the face's other texels."""
    changed = 0
    for poly in mesh.polygons:
        c = poly.center
        if not in_region(c.x / half_w, (c.z - z0) / height):
            continue
        pts = [(uv[li].uv.x * W, uv[li].uv.y * H) for li in poly.loop_indices]
        x0, x1 = int(min(p[0] for p in pts)) - patch, int(max(p[0] for p in pts)) + patch
        y0, y1 = int(min(p[1] for p in pts)) - patch, int(max(p[1] for p in pts)) + patch
        good, bad = [], []
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                i = (y * W + x) * 4
                rgb = pixels[i:i + 3]
                (bad if is_bad(*rgb) else good).append((i, rgb))
        if not bad or len(good) < 4:
            continue
        avg = [sum(g[1][k] for g in good) / len(good) for k in range(3)]
        for i, _ in bad:
            pixels[i:i + 3] = avg
            changed += 1
    return changed


def golden(r, g, b):
    return r > 0.55 and g > 0.42 and b < 0.35 and r - b > 0.35 and abs(r - g) < 0.32 and g < r


def greenish(r, g, b):
    return g > r * 1.05 and g > 0.4


if fix == "goblin_cuffs":
    # wrists: far out to the sides, around 38-56% of the height; gold that is not skin green
    n = repaint(lambda x, z: abs(x) > 0.55 and 0.36 < z < 0.58, lambda r, g, b: golden(r, g, b) and not greenish(r, g, b))
    print("FIXED texels", n)
    image.pixels = pixels
    image.filepath_raw = tex_path
    image.file_format = "PNG"
    image.save()

# textured preview
mat = bpy.data.materials.new("preview")
mat.use_nodes = True
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = image
emit = mat.node_tree.nodes.new("ShaderNodeEmission")
mat.node_tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
out = mat.node_tree.nodes.get("Material Output")
mat.node_tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
mesh.materials.clear()
mesh.materials.append(mat)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"  # true colours (the default look washes them out)
scene.render.resolution_x, scene.render.resolution_y = 700, 700
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.16, 0.16, 0.18)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
angle = math.radians(float(os.environ.get("HTD_ANGLE", "24")))  # 0 = straight from the front, 90 = from its left side
dist = height * (float(os.environ.get("HTD_ZOOM", "1")) * 2.2)
cam.location = (math.sin(angle) * dist, -math.cos(angle) * dist, height * float(os.environ.get("HTD_CAMZ", "0.75")))
target = bpy.data.objects.new("target", None)
target.location = (0, 0, z0 + height * 0.5)
scene.collection.objects.link(target)
track = cam.constraints.new("TRACK_TO")
track.target = target
scene.camera = cam
scene.render.filepath = preview
bpy.ops.render.render(write_still=True)
print("PREVIEW", preview)
