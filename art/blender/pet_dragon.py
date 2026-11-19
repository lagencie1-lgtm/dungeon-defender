"""The Baby Dragon pet, built by hand (Lemp 2026-11-19: the first one was "absolut dogshit", do it properly):
a sitting chubby dragon with a big head, snout with nostrils and a smiling mouth with fangs, big glossy eyes with
lids, curved ringed golden horns, a frill of spikes down the head and back, scalloped bat wings with finger bones,
a segmented cream belly, haunches, clawed feet and hands, and a curled tail with an arrow tip.
Front faces -Y. Run: blender -b -P pet_dragon.py -- out.fbx"""
import math
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402

W = (1, 1, 1)
PURPLE = (0.52, 0.20, 0.82)
PURPLE_D = (0.34, 0.11, 0.58)
PURPLE_L = (0.66, 0.36, 0.92)
CREAM = (0.98, 0.88, 0.68)
CREAM_D = (0.90, 0.76, 0.54)
GOLD = (1.0, 0.72, 0.16)
GOLD_D = (0.78, 0.54, 0.16)
CLAW = (0.42, 0.26, 0.16)
PINK = (0.98, 0.50, 0.58)
MOUTH = (0.55, 0.14, 0.24)
IRIS = (0.50, 0.20, 0.85)

lib.reset()
paint.setup()


def flat(obj, color):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    return paint.paint(obj, None, color)


def ball(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=20):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=seg, ring_count=max(8, seg // 2), location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return flat(o, color)


def cone(name, pos, r, h, color, rot=(0, 0, 0), top=0.0, verts=10):
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=top, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return flat(o, color)


def limb(name, a, b, r0, r1, color, verts=10):
    """A tapered tube from a to b with rounded ends."""
    from mathutils import Vector
    va, vb = Vector(a), Vector(b)
    d = vb - va
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length, vertices=verts, location=(va + vb) / 2)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    flat(o, color)
    ball(name + "End", b, r1, color, seg=verts)


def chain(name, points, radii, color, seg=10):
    """A smooth bending limb (tail, horns): tapered tubes joined at rounded knuckles."""
    ball(name + "Start", points[0], radii[0], color, seg=seg)
    for i in range(len(points) - 1):
        limb(f"{name}{i}", points[i], points[i + 1], radii[i], radii[i + 1], color, verts=seg)


# --- body and belly ---------------------------------------------------------------------------------------
ball("Body", (0, 0.12, 0.72), 0.72, PURPLE, (1.0, 0.95, 1.08))
for i in range(5):  # belly plates, each a little narrower, overlapping like armour
    z = 0.28 + i * 0.2
    w = 0.50 - abs(i - 1.6) * 0.06
    ball(f"Belly{i}", (0, -0.47 + abs(i - 1.8) * 0.045, z), w, CREAM if i % 2 == 0 else CREAM_D, (1.0, 0.42, 0.34), seg=14)

# --- haunches, feet, hands --------------------------------------------------------------------------------
for s in (-1, 1):
    ball(f"Haunch{s}", (s * 0.62, 0.05, 0.42), 0.44, PURPLE, (0.85, 1.05, 1.0))
    ball(f"Foot{s}", (s * 0.6, -0.55, 0.14), 0.26, PURPLE_L, (0.95, 1.5, 0.62))
    for k in (-1, 0, 1):
        cone(f"Toe{s}{k}", (s * 0.6 + k * 0.14, -0.93, 0.11), 0.075, 0.2, CLAW, (math.radians(100), 0, 0), verts=8)
    # arm reaching forward a little, resting on the belly
    ball(f"Arm{s}", (s * 0.56, -0.42, 0.98), 0.17, PURPLE, (0.85, 1.0, 1.45), rot=(math.radians(35), 0, math.radians(s * 14)))
    ball(f"Hand{s}", (s * 0.5, -0.6, 0.78), 0.15, PURPLE_L, (1.0, 1.0, 0.85))
    for k in (-1, 0, 1):
        cone(f"Finger{s}{k}", (s * 0.5 + k * 0.08, -0.72, 0.7), 0.045, 0.14, CLAW, (math.radians(130), 0, 0), verts=6)

# --- tail: curls round to the right side, with an arrow tip -------------------------------------------------
tail_pts, tail_r = [], []
for i in range(11):
    t = i / 10
    a = math.radians(200 + t * 150)  # sweeps from behind round to the side and forward
    rad = 0.75 + t * 0.35
    tail_pts.append((math.cos(a) * rad * 0.9 + 0.1, 0.35 + math.sin(a) * rad * 0.2 - t * 0.55, 0.22 + t * 0.06))
    tail_r.append(0.34 - t * 0.24)
chain("Tail", tail_pts, tail_r, PURPLE, seg=12)
tx, ty, tz = tail_pts[-1]
cone("TailTip", (tx + 0.12, ty - 0.1, tz + 0.02), 0.2, 0.36, PURPLE_D, (math.radians(90), 0, math.radians(-50)), verts=4)

# --- head ----------------------------------------------------------------------------------------------------
HZ = 1.72
ball("Head", (0, -0.08, HZ), 0.66, PURPLE, (1.08, 1.0, 0.95), seg=24)
ball("Cheek-1", (-0.42, -0.32, HZ - 0.2), 0.26, PURPLE_L, (1.0, 0.9, 0.85), seg=14)
ball("Cheek1", (0.42, -0.32, HZ - 0.2), 0.26, PURPLE_L, (1.0, 0.9, 0.85), seg=14)
# snout: a rounded muzzle with a lighter chin, nostrils and an open smiling mouth
ball("Snout", (0, -0.62, HZ - 0.16), 0.34, PURPLE_L, (1.12, 1.05, 0.72), seg=18)
ball("Chin", (0, -0.62, HZ - 0.53), 0.26, CREAM, (1.15, 1.0, 0.5), seg=14)
ball("Mouth", (0, -0.8, HZ - 0.37), 0.24, MOUTH, (1.2, 0.62, 0.5), seg=14)
ball("Tongue", (0, -0.88, HZ - 0.44), 0.15, PINK, (1.1, 0.6, 0.4), seg=10)
for s in (-1, 1):
    ball(f"Nostril{s}", (s * 0.13, -0.95, HZ - 0.07), 0.04, PURPLE_D, (1, 0.6, 1), seg=8)
    cone(f"Fang{s}", (s * 0.17, -0.95, HZ - 0.33), 0.045, 0.13, (1, 1, 0.96), (math.radians(180), 0, 0), verts=6)

# --- eyes: big and glossy, with lids that give the friendly look -----------------------------------------------
for s in (-1, 1):
    ex, ey, ez = s * 0.3, -0.56, HZ + 0.12
    tilt = (math.radians(-8), 0, math.radians(s * 16))
    ball(f"EyeWhite{s}", (ex, ey, ez), 0.215, (1, 1, 1), (1.0, 0.5, 1.12), rot=tilt, seg=18)
    ball(f"Iris{s}", (ex + s * 0.005, ey - 0.075, ez - 0.01), 0.165, IRIS, (1.0, 0.35, 1.1), rot=tilt, seg=16)
    ball(f"Pupil{s}", (ex + s * 0.005, ey - 0.115, ez - 0.02), 0.105, (0.06, 0.03, 0.1), (1.0, 0.3, 1.12), rot=tilt, seg=14)
    ball(f"Shine{s}", (ex - 0.06, ey - 0.15, ez + 0.075), 0.062, (1, 1, 1), (1, 0.4, 1), seg=8)
    ball(f"Shine2{s}", (ex + 0.05, ey - 0.15, ez - 0.07), 0.025, (1, 1, 1), (1, 0.4, 1), seg=6)
    # upper lid and brow ridge
    ball(f"Lid{s}", (ex, ey + 0.04, ez + 0.23), 0.215, PURPLE, (1.06, 0.62, 0.36), rot=(math.radians(-18), 0, math.radians(s * 16)), seg=14)

# --- horns: curve up and back, with rings ----------------------------------------------------------------------
for s in (-1, 1):
    pts, radii = [], []
    for i in range(9):
        t = i / 8
        pts.append((s * (0.36 + t * 0.2), 0.05 + t * 0.34 + t * t * 0.2, HZ + 0.5 + t * 0.62 - t * t * 0.18))
        radii.append(0.15 - t * 0.115)
    chain(f"Horn{s}", pts, radii, GOLD, seg=10)
    for i in (2, 4):
        ball(f"HornRing{s}{i}", pts[i], radii[i] * 1.12, GOLD_D, (1, 1, 0.3), rot=(math.radians(-35), 0, 0), seg=10)

# --- frill: spikes over the head and down the back; little fins on the cheeks ------------------------------------
spine = [(0.0, -0.3, HZ + 0.62, 0.3, -20), (0.0, 0.05, HZ + 0.68, 0.36, 10), (0.0, 0.38, HZ + 0.48, 0.34, 45),
         (0.0, 0.62, HZ + 0.1, 0.3, 75), (0.0, 0.72, 1.25, 0.3, 80), (0.0, 0.82, 0.9, 0.28, 85), (0.0, 0.8, 0.55, 0.24, 95)]
for i, (x, y, z, h, ang) in enumerate(spine):
    c = cone(f"Spike{i}", (x, y, z), 0.12, h, PURPLE_D, (math.radians(-ang), 0, 0), verts=6)
    c.scale = (0.55, 1, 1)
for s in (-1, 1):
    for k in range(3):
        c = cone(f"Fin{s}{k}", (s * (0.66 + k * 0.03), 0.05 + k * 0.02, HZ - 0.02 - k * 0.19), 0.1, 0.3 - k * 0.04, PURPLE_D,
                 (0, math.radians(s * (80 + k * 14)), 0), verts=6)
        c.scale = (1, 0.5, 1)


# --- wings: three finger bones and a scalloped membrane between them ---------------------------------------------
def wing(s):
    root = (s * 0.42, 0.5, 1.28)
    tips = [(s * 1.28, 0.62, 1.95), (s * 1.62, 0.7, 1.42), (s * 1.42, 0.66, 0.88)]
    elbow = (s * 0.86, 0.62, 1.78)
    mesh = bpy.data.meshes.new(f"Membrane{s}")
    bm = bmesh.new()

    def v(p):
        return bm.verts.new(p)

    r, e = v(root), v(elbow)
    t = [v(p) for p in tips]
    # scallops: the edge between two finger tips dips towards the root
    def dip(a, b, amount=0.24):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        return tuple(mid[i] + (root[i] - mid[i]) * amount for i in range(3))

    d1, d2 = v(dip(tips[0], tips[1])), v(dip(tips[1], tips[2]))
    d3 = v(dip(tips[2], (root[0], root[1], 0.8), 0.3))
    for tri in ((r, e, t[0]), (e, d1, t[0]), (e, t[1], d1), (r, t[1], e), (r, d2, t[1]), (r, t[2], d2), (r, d3, t[2])):
        try:
            bm.faces.new(tri)
        except ValueError:
            pass
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"Membrane{s}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.035
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    paint.paint(obj, None, (0.78, 0.42, 0.95))

    def bone(a, b, r0, r1, name):
        limb(name, a, b, r0, r1, PURPLE_D, verts=8)

    bone(root, elbow, 0.09, 0.07, f"WArm{s}")
    for i, tip in enumerate(tips):
        bone(elbow if i < 2 else root, tip, 0.06, 0.025, f"WFinger{s}{i}")
    cone(f"WClaw{s}", (elbow[0], elbow[1], elbow[2] + 0.1), 0.045, 0.16, CLAW, verts=6)


wing(-1)
wing(1)

# --- a few lighter scale spots on the forehead and back -----------------------------------------------------------
for i, (x, y, z) in enumerate(((-0.2, -0.5, HZ + 0.44), (0.2, -0.5, HZ + 0.44), (0, -0.56, HZ + 0.36), (-0.42, 0.5, 1.1), (0.42, 0.5, 1.1),
                               (-0.3, 0.62, 0.72), (0.3, 0.62, 0.72), (-0.62, 0.2, 0.82), (0.62, 0.2, 0.82))):
    ball(f"Spot{i}", (x, y, z), 0.085, PURPLE_L, (1, 1, 1), seg=8)

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
parts = paint.bake("pet_babydragon", out[:-4] + "_paint.png", 1024, triangles=7000)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
