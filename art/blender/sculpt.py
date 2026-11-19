"""The hand-building kit for characters (grown out of art/blender/pet_dragon.py, the Baby Dragon Lemp approved on
2026-11-19): smooth rounded shapes instead of blocks, tapered limbs, big glossy eyes with lids, wing membranes.
Every shape gets a flat painted colour; paint.bake() then merges everything into one skin with soft light and
ambient occlusion baked into one texture. Front of a character faces -Y, up is +Z.
Use:  import sculpt as S;  S.start();  ...shapes...;  S.finish("pet_x", out_fbx, triangles=7000)
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

import lib
import paint

W = (1, 1, 1)
BLACK = (0.05, 0.03, 0.08)
WHITE = (1, 1, 1)
rad = math.radians


def start():
    lib.reset()
    paint.setup()


def finish(name, out, triangles=7000, size=1024):
    out = os.path.abspath(out)
    parts = paint.bake(name, out[:-4] + "_paint.png", size, triangles=triangles)
    print("TRIANGLES", lib.triangles(parts))
    top = max((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
    print("HEIGHT %.2f" % top)
    lib.export_fbx(out)
    print("EXPORTED", out)


def flat(obj, color):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    return paint.paint(obj, None, color)


def glow(obj, color):
    """A part that shines in the game (Neon): stays its own piece."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    return paint.glow(obj, color)


def _sphere(name, pos, radius, scale, rot, seg):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=seg, ring_count=max(6, seg // 2), location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def ball(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=18, key=None, tile=1.2):
    """key = a painted texture from art/textures (stone, bark...), tinted with color, instead of a flat colour."""
    o = _sphere(name, pos, radius, scale, rot, seg)
    return textured(o, key, color, tile) if key else flat(o, color)


def glow_ball(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=12):
    return glow(_sphere(name, pos, radius, scale, rot, seg), color)


def cone(name, pos, r, h, color, rot=(0, 0, 0), top=0.0, verts=10, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=top, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    return flat(o, color)


def cyl(name, pos, r, h, color, rot=(0, 0, 0), verts=14, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    return flat(o, color)


def box(name, pos, size, color, rot=(0, 0, 0), bevel=0.06, key=None, tile=1.5):
    """A box with rounded edges. key = a painted texture from art/textures (wood, stone...) instead of a flat colour."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    if key:
        return paint.paint(o, key, color, tile)
    return paint.paint(o, None, color)


def textured(obj, key, tint=W, tile=1.5):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    return paint.paint(obj, key, tint, tile)


def limb(name, a, b, r0, r1, color, verts=10, end=True):
    """A tapered tube from a to b with a rounded end."""
    va, vb = Vector(a), Vector(b)
    d = vb - va
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length, vertices=verts, location=(va + vb) / 2)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    flat(o, color)
    if end:
        ball(name + "End", b, r1, color, seg=verts)
    return o


def chain(name, points, radii, color, seg=10):
    """A smooth bending limb (tail, horn, neck): tapered tubes joined at rounded knuckles."""
    ball(name + "Start", points[0], radii[0], color, seg=seg)
    for i in range(len(points) - 1):
        limb(f"{name}{i}", points[i], points[i + 1], radii[i], radii[i + 1], color, verts=seg)


def arc(center, radius, a0, a1, n, plane="xz", lift=0.0):
    """Points along an arc (degrees), for tails, horns and handles."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        a = rad(a0 + (a1 - a0) * t)
        u, v = math.cos(a) * radius, math.sin(a) * radius
        if plane == "xz":
            pts.append((center[0] + u, center[1] + lift * t, center[2] + v))
        elif plane == "yz":
            pts.append((center[0] + lift * t, center[1] + u, center[2] + v))
        else:
            pts.append((center[0] + u, center[1] + v, center[2] + lift * t))
    return pts


def eyes(center_z, y, spread, r, iris, lid=None, tilt=12, look=(0, 0), happy=True, pupil=True):
    """Two big glossy eyes on the front of a head, in the cute-pet style: a large dark eye with a ring of colour at
    the bottom, a thin white rim and two bright highlights. lid = the head's colour for a soft upper lid (optional).
    y = how far forward they sit."""
    for s in (-1, 1):
        ex, ey, ez = s * spread, y, center_z
        t = (rad(-6), 0, rad(s * tilt))
        ball(f"EyeRim{s}", (ex, ey, ez), r * 1.04, WHITE, (1.0, 0.42, 1.14), rot=t, seg=16)
        ix, iz = ex + look[0] * r * 0.2, ez + look[1] * r * 0.2
        ball(f"Iris{s}", (ix, ey - r * 0.2, iz), r * 0.93, iris, (1.0, 0.4, 1.14), rot=t, seg=16)
        if pupil:
            ball(f"Pupil{s}", (ix, ey - r * 0.34, iz + r * 0.12), r * 0.74, BLACK, (1.0, 0.36, 1.1), rot=t, seg=14)
        ball(f"Shine{s}", (ix - r * 0.26, ey - r * 0.62, iz + r * 0.42), r * 0.3, WHITE, (1, 0.4, 1), seg=8)
        ball(f"Shine2{s}", (ix + r * 0.28, ey - r * 0.6, iz - r * 0.36), r * 0.13, WHITE, (1, 0.4, 1), seg=6)
        if lid:
            ball(f"Lid{s}", (ex, ey + r * 0.26, ez + r * 1.12), r * 0.98, lid, (1.08, 0.6, 0.26), rot=(rad(-14), 0, rad(s * tilt)), seg=12)


def membrane(name, points, faces, color, thickness=0.035):
    """A thin skin between points (wings, fins, ears, flags): points = [(x,y,z)], faces = [(i,j,k)]."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    for f in faces:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    paint.paint(obj, None, color)
    return obj


def bat_wing(s, root, elbow, tips, bone_color, skin_color, bone_r=0.08):
    """A bat or dragon wing on side s (-1 left, 1 right): arm, finger bones and a scalloped skin."""
    def dip(a, b, amount=0.24):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        return tuple(mid[i] + (root[i] - mid[i]) * amount for i in range(3))

    pts = [root, elbow] + list(tips)
    faces = [(0, 1, 2)]
    for i in range(len(tips) - 1):
        d = dip(tips[i], tips[i + 1])
        pts.append(d)
        k = len(pts) - 1
        anchor = 1 if i == 0 else 0
        faces += [(anchor, k, 2 + i), (anchor, 3 + i, k)]
        if i == 0:
            faces.append((0, 3, 1))
    low = dip(tips[-1], (root[0], root[1], root[2] - 0.45), 0.3)
    pts.append(low)
    faces.append((0, len(pts) - 1, 1 + len(tips)))
    membrane(f"Wing{s}", pts, faces, skin_color)
    limb(f"WArm{s}", root, elbow, bone_r, bone_r * 0.8, bone_color, verts=8)
    for i, tip in enumerate(tips):
        limb(f"WFinger{s}{i}", elbow if i < len(tips) - 1 else root, tip, bone_r * 0.7, bone_r * 0.3, bone_color, verts=8)


def feather_wing(s, root, length, color, tip_color, n=4, up=0.5, back=0.25):
    """A bird wing on side s: overlapping feathers fanning out and up."""
    for i in range(n):
        t = i / max(1, n - 1)
        ln = length * (1 - t * 0.35)
        a = rad(20 + t * 55)
        end = (root[0] + s * math.cos(a) * ln, root[1] + back * (0.4 + t), root[2] + math.sin(a) * ln * up + (0.5 - t) * 0.1)
        mid = tuple((root[k] + end[k]) / 2 for k in range(3))
        d = Vector(end) - Vector(root)
        o = _sphere(f"Feather{s}{i}", mid, ln / 2, (1, 0.16, 0.42), (0, 0, 0), 12)
        o.rotation_euler = d.to_track_quat("X", "Z").to_euler()
        flat(o, tip_color if i == 0 else color)


def paws(color, y=-0.5, spread=0.3, r=0.2, z=0.12, toes=None):
    """Two front feet; toes = a colour for three little toe beans."""
    for s in (-1, 1):
        ball(f"Paw{s}", (s * spread, y, z), r, color, (1.0, 1.35, 0.65))
        if toes:
            for k in (-1, 0, 1):
                ball(f"Toe{s}{k}", (s * spread + k * r * 0.5, y - r * 1.1, z - r * 0.05), r * 0.26, toes, (1, 1, 0.8), seg=8)
