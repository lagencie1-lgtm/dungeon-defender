"""Shared helpers for building game models as code in Blender (6A: models as code).
Units are Roblox studs (1 Blender unit = 1 stud), Y is up in Roblox, Z is up in Blender:
the exporter converts axes. Colours are baked into vertex colours (no textures), with a soft
top-down shade so the models read well on phones.
"""
import math

import bpy
import bmesh

# the game's palette (art/STYLE.md), a bit lighter than the paintings because
# the game's maps are lit at dusk and night (6A: never let a map go too dark)
WOOD_DARK = (0.45, 0.31, 0.19)
WOOD = (0.66, 0.46, 0.28)
BRASS = (0.84, 0.67, 0.31)
CREAM = (0.95, 0.90, 0.78)
STONE = (0.66, 0.63, 0.60)
STONE_DARK = (0.52, 0.50, 0.48)
GREEN = (0.45, 0.82, 0.40)
FIRE = (1.0, 0.48, 0.16)
FROST = (0.55, 0.82, 1.0)
STORM = (0.59, 0.47, 1.0)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _paint(obj, color):
    obj["htd_color"] = list(color)
    mesh = obj.data
    if not mesh.color_attributes:
        mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    attr = mesh.color_attributes["Col"]
    # soft shade: faces looking down are darker, faces looking up are lighter (baked light from above)
    for poly in mesh.polygons:
        shade = 0.78 + 0.22 * max(-1.0, min(1.0, poly.normal.z))
        for li in poly.loop_indices:
            attr.data[li].color = (color[0] * shade, color[1] * shade, color[2] * shade, 1.0)


def box(name, size, location, color, bevel=0.0, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    _paint(obj, color)
    return obj


def cylinder(name, radius, depth, location, color, vertices=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=vertices, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    _paint(obj, color)
    return obj


def cone(name, radius, depth, location, color, vertices=12, radius_top=0.0):
    bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius_top, depth=depth, vertices=vertices, location=location)
    obj = bpy.context.active_object
    obj.name = name
    _paint(obj, color)
    return obj


def sphere(name, radius, location, color, segments=12):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=max(6, segments // 2), location=location)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.shade_smooth()
    _paint(obj, color)
    return obj


def join_all(name):
    """Joins the meshes into one object per colour (Roblox shows colours per MeshPart, not per vertex).
    Each part is named c_R_G_B so the game can colour it. Returns the parts; origin at the base centre."""
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        c = obj.get("htd_color", (0.5, 0.5, 0.5))
        key = "c_%d_%d_%d" % tuple(round(max(0, min(1, v)) * 255) for v in c[:3])
        groups.setdefault(key, []).append(obj)
    parts = []
    bpy.context.scene.cursor.location = (0, 0, 0)
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


def triangles(objs):
    if not isinstance(objs, list):
        objs = [objs]
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def export_fbx(path):
    bpy.ops.export_scene.fbx(filepath=path, use_selection=False, apply_unit_scale=True, global_scale=1.0,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", colors_type="SRGB")
