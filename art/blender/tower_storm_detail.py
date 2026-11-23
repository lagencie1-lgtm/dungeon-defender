"""The Storm Obelisk at its three levels, built with the tower kit to match art/ref3d/tower_storm_l1..l3.png.
Part list from the pictures:
  level 1  stone ring footing; a big rough rune stone with a glowing violet lightning rune and two small diamonds;
           four wooden posts round its foot, bound by riveted brass straps
  level 2  footing; a stone plinth with arched niches and wooden posts; a brass collar; a slate obelisk with the
           glowing rune; a brass cap with two horns; a copper rod with a ball on top
  level 3  as level 2 but taller, copper coils wound round the obelisk, and a floating glowing violet orb between the
           horns instead of the rod
The runes and the orb glow (Neon). FRONT faces the picture's camera.
Run: blender -b -P tower_storm_detail.py -- out.fbx <1|2|3> [params.json]"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import sculpt as S  # noqa: E402
import tower_kit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, level = args[0], int(args[1])
FRONT = -75
rad = math.radians
SLATE = (0.42, 0.36, 0.44)
SLATE_DARK = (0.3, 0.26, 0.33)
COPPER = (0.78, 0.45, 0.28)
VIOLET = (0.72, 0.45, 1.0)
rnd = random.Random(level)

DEFAULTS = {
    1: dict(foot_r=3.2, foot_h=0.8, foot_n=10, stone_w=2.0, stone_h=4.4, stone_d=1.5),
    2: dict(foot_r=3.0, foot_h=0.8, foot_n=10, plinth_r=2.4, plinth_h=1.8, ob_w=2.2, ob_top=0.55, ob_h=3.6, rod=1.6),
    3: dict(foot_r=3.0, foot_h=0.8, foot_n=10, plinth_r=2.4, plinth_h=1.8, ob_w=2.0, ob_top=0.6, ob_h=4.4, orb_r=0.75),
}
P = dict(DEFAULTS[level])
saved = os.path.join(HERE, "params", f"tower_storm_l{level}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()
a0 = rad(FRONT)
FWD = Vector((math.cos(a0), math.sin(a0), 0))
SIDE = Vector((-math.sin(a0), math.cos(a0), 0))


def rune(name, center, normal, size):
    """the glowing lightning rune: a zigzag plate standing just off a face (Neon), with two small diamonds"""
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1))
    side = up.cross(n).normalized()
    up = n.cross(side).normalized()
    zig = [(-0.15, 0.5), (0.25, 0.5), (0.02, 0.08), (0.28, 0.08), (-0.2, -0.5), (0.0, -0.08), (-0.26, -0.08)]
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(Vector(center) + n * 0.06 + side * (x * size) + up * (y * size))) for x, y in zig]
    bm.faces.new(vs)
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.06)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    S.glow(o, VIOLET)
    for k, dy in enumerate((0.78, -0.78)):
        p = Vector(center) + n * 0.05 + up * (dy * size)
        bpy.ops.mesh.primitive_cube_add(size=size * 0.22, location=p, rotation=(0, 0, 0))
        d = bpy.context.active_object
        d.rotation_euler = (n.to_track_quat("Z", "Y") @ __import__("mathutils").Quaternion((0, 0, 1), rad(45))).to_euler()
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        S.glow(d, VIOLET)


def footing():
    K.stone_ring("Foot", 0, P["foot_r"], P["foot_h"], P["foot_n"], depth=1.1)
    K.lathe("FootCore", [(P["foot_r"] - 0.9, 0), (P["foot_r"] - 0.9, P["foot_h"] - 0.02)], K.MORTAR)
    K.grass(P["foot_r"] - 0.05, 22, h=0.75)
    K.pebbles(P["foot_r"] + 0.2, 5)


def post(name, a, r, z0, h, strap_z=None):
    K.block(name, K.at(a, r, z0 + h / 2), (0.62, 0.5, h), K.WOOD_DARK if (hash(name) % 2) else K.WOOD, (0, 0, a + rad(90)),
            key="wood", tile=1.0, bevel=0.1)
    if strap_z:
        K.block(name + "Strap", K.at(a, r + 0.2, strap_z), (0.8, 0.18, 0.45), K.BRASS, (0, 0, a + rad(90)), key="brass", tile=0.6, bevel=0.05)
        K.ball(name + "Rivet", K.at(a, r + 0.32, strap_z), 0.09, K.BRASS, seg=6)


def obelisk(z0, w, top_w, h, coils=False):
    """a four-sided slate obelisk with a bevelled edge, the rune on the front face"""
    bm = bmesh.new()
    corners = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
    lo = [bm.verts.new((x * w / 2, y * w / 2, z0)) for x, y in corners]
    hi = [bm.verts.new((x * top_w / 2, y * top_w / 2, z0 + h)) for x, y in corners]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.08, segments=2, affect="EDGES")
    # a face (not an edge) looks to the front: the rune sits on it
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(a0, 3, "Z"))
    mesh = bpy.data.meshes.new("Obelisk")
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new("Obelisk", mesh)
    bpy.context.scene.collection.objects.link(o)
    o["htd_atlas"] = "body"
    K.paint.paint(o, None, SLATE)
    face_c = FWD * ((w + top_w) / 4 + 0.04) + Vector((0, 0, z0 + h * 0.48))
    rune("Rune", face_c, FWD + Vector((0, 0, (w - top_w) / (2 * h))), 0.75 * (w + top_w) / 2)
    if coils:
        pts = []
        for k in range(40):
            t = k / 39
            ang = a0 + t * 2 * math.pi * 2.2
            rr = (w + (top_w - w) * (0.25 + 0.5 * t)) * 0.72 + 0.28   # outside the obelisk's corners
            pts.append((math.cos(ang) * rr, math.sin(ang) * rr, z0 + h * (0.25 + 0.5 * t)))
        K.chain("Coil", pts, [0.14] * len(pts), COPPER, seg=6)
    return z0 + h


footing()
fz = P["foot_h"]
if level == 1:
    # the rune stone: a rough boulder, taller than wide
    o = K.ball("RuneStone", (0, 0, fz + P["stone_h"] * 0.45), 1.0, K.STONE, (P["stone_w"], P["stone_d"], P["stone_h"] * 0.55), seg=12, key=None)
    for v in o.data.vertices:   # chipped, uneven faces
        v.co += Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08)))
    rune("Rune", FWD * (P["stone_d"] * 1.0) + Vector((0, 0, fz + P["stone_h"] * 0.5)), FWD, 1.45)
    for i in range(4):
        a = a0 + rad(45 + i * 90)
        post(f"Post{i}", a, P["stone_w"] * 0.92, fz, 1.9, strap_z=fz + 1.2)
    muzzle_z = fz + P["stone_h"] * 0.8
else:
    # the plinth: a stone drum with arched niches, wooden posts, a brass collar on top
    pr, ph = P["plinth_r"], P["plinth_h"]
    K.lathe("Plinth", [(pr, fz), (pr * 0.9, fz + ph)], K.STONE, key=None, verts=24)
    for i in range(6):
        a = a0 + rad(30 + i * 60)
        post(f"Post{i}", a, pr * 0.95, fz, ph + 0.2)
        na = a0 + rad(i * 60)
        K.block(f"Niche{i}", K.at(na, pr * 0.95, fz + ph * 0.42), (0.7, 0.2, ph * 0.6), (0.36, 0.3, 0.3), (0, 0, na + rad(90)), key=None, bevel=0.05)
    K.brass_band("Collar", fz + ph + 0.1, pr * 0.85, 0.5, 14)
    top = obelisk(fz + ph + 0.3, P["ob_w"], P["ob_w"] * P["ob_top"], P["ob_h"], coils=(level == 3))
    K.lathe("Cap", [(P["ob_w"] * 0.65, top - 0.1), (P["ob_w"] * 0.75, top + 0.1), (P["ob_w"] * 0.6, top + 0.35), (0.2, top + 0.4)], K.BRASS, key="brass", verts=8)
    for s in (-1, 1):
        base = SIDE * (s * P["ob_w"] * 0.55) + Vector((0, 0, top + 0.25))
        horn = [tuple(base + SIDE * (s * 0.25 * t) + Vector((0, 0, 0.8 * t))) for t in (0, 0.5, 1.0)]
        K.chain(f"Horn{s}", horn, [0.16, 0.12, 0.05], COPPER, seg=6)
    if level == 2:
        K.limb("Rod", (0, 0, top + 0.35), (0, 0, top + 0.35 + P["rod"]), 0.09, 0.08, COPPER, verts=8, end=False)
        K.ball("RodBall", (0, 0, top + 0.45 + P["rod"]), 0.24, COPPER, seg=10)
        K.lathe("RodRing", [(0.25, top + 0.75), (0.28, top + 0.8), (0.25, top + 0.85)], COPPER, verts=10)
        muzzle_z = top + 0.45 + P["rod"]
    else:
        S.glow_ball("Orb", (0, 0, top + 0.6 + P["orb_r"]), P["orb_r"], (0.75, 0.5, 1.0), seg=16)
        muzzle_z = top + 0.6 + P["orb_r"]

print("MUZZLE Vector3.new(0.00, %.2f, 0.00)" % muzzle_z)
if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_storm_l{level}", out, budget=9000)
