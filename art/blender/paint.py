"""Painted-texture models (Lemp 2026-11-18: "proper blender models with painted textures").

Each part gets one of the shared painted materials from art/textures (made by art/make_textures.py), box-projected
in world space so the paint runs on across joins. bake() then joins everything into one mesh, unwraps it and bakes
the paint, a soft top light and ambient occlusion into one texture: the game shows the model as one MeshPart with
that texture. Glowing bits stay separate parts named c_R_G_B (the game makes them Neon), like lib.join_all.
"""
import os

import bpy

import lib

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(HERE, "..", "textures")

_materials = {}
FALLBACK = {"bark": (0.36, 0.26, 0.18), "leaves": (0.30, 0.50, 0.26), "brass": (0.84, 0.67, 0.31), "cloth": (0.95, 0.90, 0.78), "iron": (0.35, 0.36, 0.40)}


def material(key, tint=(1, 1, 1), scale=4.0):
    """One painted material: texture `key` (art/textures/<key>.png), one tile every `scale` studs, times `tint`."""
    if key != "_flat" and not os.path.exists(os.path.join(TEXTURES, key + ".png")):
        # texture not painted yet: a plain stand-in colour so the model still builds
        base = FALLBACK.get(key, (0.6, 0.6, 0.6))
        key, tint = "_flat", tuple(base[i] * tint[i] for i in range(3))
    mkey = (key, tuple(round(t, 3) for t in tint), scale)
    if mkey in _materials:
        return _materials[mkey]
    mat = bpy.data.materials.new(f"{key}_{len(_materials)}")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n = nt.nodes.new
    coords = n("ShaderNodeTexCoord")
    mapping = n("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / scale, 1 / scale, 1 / scale)
    nt.links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    tex = n("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.abspath(os.path.join(TEXTURES, key + ".png")), check_existing=True)
    tex.projection = "BOX"
    tex.projection_blend = 0.25
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    # tint
    tint_node = n("ShaderNodeMix")
    tint_node.data_type = "RGBA"
    tint_node.blend_type = "MULTIPLY"
    tint_node.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], tint_node.inputs[6])
    tint_node.inputs[7].default_value = (*tint, 1)
    # soft light from above: tops a bit brighter, undersides darker
    geo = n("ShaderNodeNewGeometry")
    sep = n("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    light = n("ShaderNodeMapRange")
    light.inputs["From Min"].default_value = -1
    light.inputs["From Max"].default_value = 1
    light.inputs["To Min"].default_value = 0.72
    light.inputs["To Max"].default_value = 1.12
    nt.links.new(sep.outputs["Z"], light.inputs["Value"])
    # ambient occlusion darkens the corners and joins (what makes it look built, not stacked)
    ao = n("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.8
    ao_range = n("ShaderNodeMapRange")
    ao_range.inputs["To Min"].default_value = 0.55
    nt.links.new(ao.outputs["AO"], ao_range.inputs["Value"])
    shade = n("ShaderNodeMath")
    shade.operation = "MULTIPLY"
    nt.links.new(light.outputs["Result"], shade.inputs[0])
    nt.links.new(ao_range.outputs["Result"], shade.inputs[1])
    final = n("ShaderNodeMix")
    final.data_type = "RGBA"
    final.blend_type = "MULTIPLY"
    final.inputs["Factor"].default_value = 1.0
    nt.links.new(tint_node.outputs[2], final.inputs[6])
    nt.links.new(shade.outputs["Value"], final.inputs[7])
    emit = n("ShaderNodeEmission")
    nt.links.new(final.outputs[2], emit.inputs["Color"])
    out = n("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    _materials[mkey] = mat
    return mat


def bevel(obj, width, segments=2):
    """Rounds the edges a little (catches light, looks crafted rather than blocky)."""
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def smooth(obj, angle=35):
    import math
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    return obj


def flat(color):
    """A plain painted colour (faces, small details) that still gets light and occlusion baked in."""
    return material("_flat", tint=color)


def paint(obj, key, tint=(1, 1, 1), scale=4.0):
    obj.data.materials.clear()
    obj.data.materials.append(flat(tint) if key is None else material(key, tint, scale))
    obj["htd_paint"] = True
    return obj


def glow(obj, color):
    """Marks a part as glowing: it stays its own Neon part instead of being baked."""
    obj["htd_color"] = list(color)
    obj["htd_paint"] = False
    return obj


def _flat_texture():
    path = os.path.join(TEXTURES, "_flat.png")
    if not os.path.exists(path):
        img = bpy.data.images.new("_flat", 4, 4)
        img.pixels = [1.0] * 64
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()


def bake(name, texture_out, size=1024):
    """Joins the painted parts into one mesh called Body with the baked texture; glowing parts become c_R_G_B
    parts. Saves the texture to texture_out and returns all parts."""
    scene = bpy.context.scene
    painted = [o for o in scene.objects if o.type == "MESH" and o.get("htd_paint")]
    glowing = [o for o in scene.objects if o.type == "MESH" and not o.get("htd_paint")]
    bpy.ops.object.select_all(action="DESELECT")
    for o in painted:
        o.select_set(True)
    bpy.context.view_layer.objects.active = painted[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "Body"
    body.data.name = "Body"
    # unwrap into one atlas
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    # bake target
    img = bpy.data.images.new(name + "_paint", size, size)
    for mat in body.data.materials:
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        mat.node_tree.nodes.active = node
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.bake.margin = 6
    bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = os.path.abspath(texture_out)
    img.file_format = "PNG"
    img.save()
    # the exported mesh gets one simple material with the baked texture
    body.data.materials.clear()
    final = bpy.data.materials.new(name + "_baked")
    final.use_nodes = True
    tex = final.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = final.node_tree.nodes.get("Principled BSDF")
    final.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    body.data.materials.append(final)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    for o in glowing:
        lib._paint(o, o.get("htd_color", (1, 1, 1)))
    # glowing parts: one part per colour, like lib.join_all (it skips nothing, so run it on those only)
    bpy.ops.object.select_all(action="DESELECT")
    parts = [body]
    groups = {}
    for o in glowing:
        c = o.get("htd_color")
        key = "c_%d_%d_%d" % tuple(round(max(0, min(1, v)) * 255) for v in c[:3])
        groups.setdefault(key, []).append(o)
    for key, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.active_object
        obj.name = key
        obj.data.name = key
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        parts.append(obj)
    return parts


_flat_texture_made = False


def setup():
    """Call once after lib.reset()."""
    _flat_texture()
    _materials.clear()
