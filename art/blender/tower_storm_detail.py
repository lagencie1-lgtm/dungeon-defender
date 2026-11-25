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
    # (round 2: the skirt is tall and the obelisk stands on its whole top, one tapering shape from foot to cap)
    2: dict(foot_r=3.2, foot_h=0.8, foot_n=10, plinth_r=2.4, plinth_h=2.6, ob_w=3.4, ob_top=0.45, ob_h=4.2, rod=1.6),
    3: dict(foot_r=3.4, foot_h=0.8, foot_n=10, plinth_r=2.5, plinth_h=2.8, ob_w=3.5, ob_top=0.45, ob_h=5.2, orb_r=1.1),
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
    # (pebbles dropped 2026-11-24: on the turntable they read as thin glassy plates floating at the foot)


def post(name, a, r, z0, h, strap_z=None, w=0.62):
    K.block(name, K.at(a, r, z0 + h / 2), (w, w * 0.8, h), K.WOOD_DARK if (hash(name) % 2) else K.WOOD, (0, 0, a + rad(90)),
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
    if coils:   # round 2: two thick copper rings round the obelisk with gold clamps (as painted), not a thin helix
        for j, t in enumerate((0.3, 0.62)):
            rr = (w + (top_w - w) * t) * 0.74 + 0.3
            pts = [(math.cos(a0 + 2 * math.pi * k / 24) * rr, math.sin(a0 + 2 * math.pi * k / 24) * rr, z0 + h * t) for k in range(25)]
            K.chain(f"Coil{j}", pts, [0.22] * len(pts), COPPER, seg=8)
            for c in range(4):
                a = a0 + rad(45 + c * 90)
                K.block(f"Clamp{j}{c}", (math.cos(a) * rr, math.sin(a) * rr, z0 + h * t), (0.42, 0.42, 0.55), K.BRASS, (0, 0, a), key="brass", tile=0.6, bevel=0.06)
    return z0 + h


footing()
fz = P["foot_h"]
if level == 1:
    # the rune stone: a rough boulder, taller than wide
    # round 2 (2026-11-24): a chunky cut rock with flat facets, not an egg (few segments, big chips, a flat top)
    o = K.ball("RuneStone", (0, 0, fz + P["stone_h"] * 0.45), 1.0, K.STONE, (P["stone_w"], P["stone_d"], P["stone_h"] * 0.55), seg=8, key=None)
    for v in o.data.vertices:
        v.co += Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.06, 0.06)))
    # (2026-11-25, towers tell apart: the painted stone is tall with a blunt point, not a round dome; its upper half
    # narrows toward a point so its top reads unlike the Flame Cannon's barrel at level 1)
    zs = [v.co.z for v in o.data.vertices]
    z0, z1 = min(zs), max(zs)
    for v in o.data.vertices:
        t = (v.co.z - z0) / (z1 - z0)
        if t > 0.5:
            k = 1.0 - P.get("point", 0.55) * ((t - 0.5) / 0.5) ** 1.5
            v.co.x *= k
            v.co.y *= k
            v.co.z += (t - 0.5) * 0.35
    rune("Rune", FWD * (P["stone_d"] * 1.0) + Vector((0, 0, fz + P["stone_h"] * 0.48)), FWD, 2.0)
    # (2026-11-24 review, from the painting: two thick short posts at each front corner of the stone, about 0.4 of its
    # height, gold bands round each pair; at the sides behind it they hid and the stone looked too big for them)
    for s_ in (-1, 1):
        for k, da in enumerate((38, 68)):
            a = a0 + rad(da * s_)
            post(f"Post{s_}{k}", a, P["stone_w"] * 1.0, fz, 1.75 - 0.25 * k, strap_z=fz + 1.15 - 0.2 * k, w=0.85)
        a = a0 + rad(53 * s_)
        K.block(f"PostBand{s_}", K.at(a, P["stone_w"] * 1.02, fz + 1.15), (1.9, 0.95, 0.34), K.BRASS, (0, 0, a + rad(90)), key="brass", tile=0.6, bevel=0.05)
    muzzle_z = fz + P["stone_h"] * 0.8
else:
    # the plinth: a stone drum with arched niches, wooden posts, a brass collar on top
    pr, ph = P["plinth_r"], P["plinth_h"]
    # round 2 (2026-11-24): the paintings' skirt: cut stone flaring out at the foot, arched doors all round, dark wood
    # planks between them, a gold trim band at the top (not a ring of posts)
    # (2026-11-25 review, from the paintings: the skirt is dark wooden planks standing round a tapering drum, gold
    # strapped, with one cut-stone arched door at the front and one at the back; a pale stone drum with arches all
    # round read as a different tower and pulled the colour off)
    K.lathe("Skirt", [(pr * 1.12, fz), (pr * 0.86, fz + ph)], K.WOOD_DARK, key="wood_dark", verts=16)
    for i in range(16):
        a = a0 + rad(i * 22.5 + 11.25)
        if min(abs(((i * 22.5 + 11.25) - d + 180) % 360 - 180) for d in (0, 180)) < 20:
            continue   # (the doors)
        ra, rb = pr * 1.12 + 0.04, pr * 0.86 + 0.04
        lean = math.atan2(ra - rb, ph)
        K.block(f"Plank{i}", K.at(a, (ra + rb) / 2, fz + ph / 2), (0.75, 0.22, ph / math.cos(lean)), K.WOOD if i % 2 else K.WOOD_DARK,
                (lean, 0, a + rad(90)), key="wood", tile=1.0, bevel=0.06)
    for d in (0, 180):
        K.arched_door(FRONT + d, pr * 1.0, fz + 0.02, 0.95, ph * 0.7, steps=0, arch_stones=5)
    K.brass_band("SkirtBand", fz + ph * 0.45, pr * 0.99 + 0.06, 0.3, 10)
    K.brass_band("Collar", fz + ph + 0.05, pr * 0.84, 0.55, 14)
    for i in range(12):   # the gold band's pointed scallops, as painted
        a = a0 + rad(i * 30 + 15)
        K.cone(f"Scallop{i}", K.at(a, pr * 0.86, fz + ph - 0.25), 0.26, 0.5, K.BRASS, rot=(rad(180), 0, 0), verts=4)
    top = obelisk(fz + ph + 0.3, P["ob_w"], P["ob_w"] * P["ob_top"], P["ob_h"], coils=(level == 3))
    tw = P["ob_w"] * P["ob_top"]
    K.lathe("Cap", [(tw * 0.75, top - 0.15), (tw * 0.85, top + 0.1), (tw * 0.7, top + 0.35), (0.2, top + 0.42)], K.BRASS, key="brass", verts=8)
    for s in (-1, 1):   # two big horns curving out and up (they hold the orb on level 3)
        base = SIDE * (s * tw * 0.45) + Vector((0, 0, top + 0.25))
        horn = [tuple(base + SIDE * (s * 0.55 * math.sin(t * 1.4)) + Vector((0, 0, 1.5 * t))) for t in (0, 0.33, 0.66, 1.0)]
        K.chain(f"Horn{s}", horn, [0.24, 0.2, 0.13, 0.05], COPPER, seg=8)
    if level == 2:
        K.limb("Rod", (0, 0, top + 0.35), (0, 0, top + 0.35 + P["rod"]), 0.09, 0.08, COPPER, verts=8, end=False)
        K.ball("RodBall", (0, 0, top + 0.45 + P["rod"]), 0.24, COPPER, seg=10)
        K.lathe("RodRing", [(0.25, top + 0.75), (0.28, top + 0.8), (0.25, top + 0.85)], COPPER, verts=10)
        muzzle_z = top + 0.45 + P["rod"]
    else:
        # the orb: round, the brightest thing on the tower (Neon), held between the horns' tips
        # (2026-11-24 review: an all-Neon ball draws as a flat purple disc, a sticker. The orb is a shaded violet
        # sphere, light at the top and dark below, with a small glowing core showing through a slit ring, so it is
        # round and still the brightest thing on the tower)
        oc = Vector((0, 0, top + 0.5 + P["orb_r"]))
        K.ball("Orb", tuple(oc), P["orb_r"], (0.55, 0.3, 0.85), seg=20, key=None)
        K.lathe("OrbBand", [(P["orb_r"] * 1.02, oc.z - 0.1), (P["orb_r"] * 1.06, oc.z), (P["orb_r"] * 1.02, oc.z + 0.1)], K.BRASS, key="brass", verts=20)
        S.glow_ball("OrbCore", tuple(oc + FWD * (P["orb_r"] * 0.55) + Vector((0, 0, P["orb_r"] * 0.25))), P["orb_r"] * 0.5, (0.9, 0.75, 1.0), seg=14)
        muzzle_z = top + 0.5 + P["orb_r"]

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
