"""Shared helpers for building game models as code in Blender (6A: models as code).
Units are Roblox studs (1 Blender unit = 1 stud), Y is up in Roblox, Z is up in Blender:
the exporter converts axes. Colours are baked into vertex colours (no textures), with a soft
top-down shade so the models read well on phones.
"""
import math

import bpy
import bmesh

# the game's palette (art/STYLE.md)
WOOD_DARK = (0.27, 0.19, 0.12)
WOOD = (0.45, 0.31, 0.19)
BRASS = (0.84, 0.67, 0.31)
CREAM = (0.95, 0.90, 0.78)
STONE = (0.47, 0.44, 0.42)
STONE_DARK = (0.33, 0.31, 0.30)
GREEN = (0.37, 0.71, 0.35)
FIRE = (1.0, 0.48, 0.16)
FROST = (0.55, 0.82, 1.0)
STORM = (0.59, 0.47, 1.0)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _paint(obj, color):
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
    """Joins every mesh into one object (one MeshPart in Roblox), origin at the base centre."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_fbx(path):
    bpy.ops.export_scene.fbx(filepath=path, use_selection=False, apply_unit_scale=True, global_scale=1.0,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", colors_type="SRGB")
