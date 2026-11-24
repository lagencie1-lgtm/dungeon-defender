"""The Oak Barricade (Lemp 2026-11-24: "do the oak barricade"), the first defender that stands ON the path, built with
the tower kit. Four looks, one per stage, told apart by shape on a phone (target: art/ref3d/tower_barricade_sheet.png):
  l1     a wall of three oak logs held by a front and a back post at each end, pale sharpened tips, rope lashing
  l2     taller: four logs, thicker posts with iron bands and brass rivets, a solid round shield (wooden planks,
         brass rim with studs, brass boss) on both faces
  thorn  (level 3, Thornwall) the level 2 wall behind a rack of long fire-hardened stakes (red, charred points) that
         cross through a rail and point out and up at the enemies; braces behind
  root   (level 3, Rootwall) the level 2 wall gripped by thick living roots that climb over it, wind round a post and
         spread over the road on both faces, moss on top and a leafy sapling
Axes: Blender X runs ALONG the wall (across the path, the game's local X), +Y is the side enemies come from (the game
puts the wall with CFrame.lookAt(spot, spot + walk direction): enemies arrive from its local +Z, which the FBX export
makes of Blender +Y), Z is up. Keep the plan view centred on the wall line: the game stands the middle of the model's
box on the path, so anything sticking out in front needs a match behind (the thorn wall's braces, the roots both ways).
Heights must match LEVEL_LOOKS / BRANCH_LOOKS in src/server/TowerService.luau (the game scales each look to them).

Round 2 (2026-11-24, after the round 1 turntables): every part is built in place (no obj.location afterwards: the
hidden-face cull used to test moved parts where they were made and deleted the shield disc, the stake tips and the
iron bands); logs are 12-sided swept tubes 1.72 radii apart over a dark core, so no light shows between them; the oak
uses the warm wood texture with its grain turned along each log instead of the dark bark times a dark tint.
Run: blender -b -P tower_barricade_detail.py -- out.fbx <l1|l2|thorn|root> [params.json]"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import sculpt as S  # noqa: E402
import tower_kit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, stage = args[0], args[1]
assert stage in ("l1", "l2", "thorn", "root"), stage
rad = math.radians
rnd = random.Random(11)

# textured parts: the tint multiplies the texture in linear light (about tint ** 0.45 on screen)
LOG = (0.8, 1.0, 1.9)           # wood.png -> warm mid oak like the sheet's logs (about 0.62, 0.37, 0.16 on screen)
POST = (0.95, 1.08, 1.9)        # a touch lighter than the logs
SHIELD = (0.42, 0.52, 1.3)      # darker planks, so the brass reads
RAIL = (1.8, 1.9, 2.0)          # wood_dark.png, lifted
IRON_T = (0.62, 0.62, 0.68)
BRASS_T = (1.3, 1.4, 1.6)       # brass.png -> the sheet's warm brass, not orange
ROOT_T = (1.6, 2.6, 3.0)        # bark.png -> living root brown (about 0.5, 0.33, 0.18)
MOSS_T = (2.6, 2.0, 1.4)        # leaves.png -> yellow-green moss
CROWN_T = (2.2, 2.1, 1.6)
# flat parts: colours as they should look on screen
TIP = (0.9, 0.72, 0.5)          # the pale sharpened post tips
CUT = (0.93, 0.74, 0.48)        # sawn log ends
HEART = (0.78, 0.53, 0.3)       # the darker heart rings of a sawn end
KNOT = (0.42, 0.25, 0.13)
ROPE = (0.9, 0.8, 0.6)
STUD = (0.93, 0.68, 0.27)
RED = (0.68, 0.24, 0.13)        # fire-hardened stake (the Thornwall's colour)
CHAR = (0.26, 0.1, 0.07)        # the charred point
DIRT = (0.5, 0.36, 0.23)
LEAF = (0.45, 0.74, 0.3)

DEFAULTS = {
    # length along the path (the road is 10 studs wide), log radius, logs stacked, post radius, post height
    "l1": dict(length=11.0, log_r=0.56, logs=3, post_r=0.46, post_h=3.8, post_x=4.4),
    "l2": dict(length=11.2, log_r=0.58, logs=4, post_r=0.6, post_h=5.0, post_x=4.3),
    "thorn": dict(length=11.2, log_r=0.58, logs=4, post_r=0.6, post_h=5.0, post_x=4.3, stakes=7, stake_len=3.4,
                  stake_tilt=52, front=5, front_len=1.6),
    "root": dict(length=11.2, log_r=0.58, logs=4, post_r=0.6, post_h=5.0, post_x=4.3, reach=3.0, sapling=1.4),
}
P = dict(DEFAULTS[stage])
saved = os.path.join(HERE, "params", f"tower_barricade_{stage}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()

R = P["log_r"]
STEP = R * 1.72           # logs pressed into each other: the 12-sided tube is 0.966 R thick at a face centre
POST_Y = R + P["post_r"] * 0.85
FACE_Y = {1: Quaternion((1, 0, 0), rad(-90)), -1: Quaternion((1, 0, 0), rad(90))}   # turns a lathe's +Z to +Y / -Y


def moved(o, loc=(0, 0, 0), quat=None):
    """moves a part's mesh itself (never obj.location: see the round 2 note above)"""
    m = Matrix.Translation(Vector(loc))
    if quat is not None:
        m = m @ quat.to_matrix().to_4x4()
    o.data.transform(m)
    o.data.update()
    return o


def grain_x(o):
    """turns the texture so the wood's grain runs along X (along a log), not up the face"""
    mat = o.data.materials[0]
    name = mat.name + "_alongx"
    turned = bpy.data.materials.get(name)
    if turned is None:
        turned = mat.copy()
        turned.name = name
        for n in turned.node_tree.nodes:
            if n.type == "MAPPING":
                n.inputs["Rotation"].default_value = (0.0, math.pi / 2, 0.0)
    o.data.materials[0] = turned
    return o


def tube(name, pts, radii, color, key=None, tile=1.4, verts=10):
    """one seamless swept tube through pts (rings kept square to the path by parallel transport), capped both ends"""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tans = [(pts[min(n - 1, i + 1)] - pts[max(0, i - 1)]).normalized() for i in range(n)]
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = (ref - tans[0] * ref.dot(tans[0])).normalized()
    bm = bmesh.new()
    rings = []
    for i in range(n):
        t = tans[i]
        nrm = (nrm - t * nrm.dot(t)).normalized()
        side = t.cross(nrm)
        rings.append([bm.verts.new(pts[i] + (nrm * math.cos(a) + side * math.sin(a)) * radii[i])
                      for a in (2 * math.pi * k / verts for k in range(verts))])
    for a, b in zip(rings, rings[1:]):
        for k in range(verts):
            j = (k + 1) % verts
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    return K._link(name, mesh, color, key, tile)


def cone_to(name, a, b, r0, color, key=None, tile=1.0, verts=8):
    """a point from a to b (a limb that ends in a tip: no turning needed)"""
    K.limb(name, a, b, r0, 0.012, color, verts=verts, end=False, key=key, tile=tile)


def log(name, z, length, r, seed):
    """an oak log along X: a slightly crooked swept trunk with the grain along it, sawn ends with a pale face and a
    darker heart, a knot or two on the faces"""
    g = random.Random(seed)
    pts, radii = [], []
    for k in range(7):
        t = k / 6
        pts.append(Vector(((t - 0.5) * length, g.uniform(-0.04, 0.04), z + g.uniform(-0.025, 0.025))))
        radii.append(r * (1.0 - 0.05 * abs(t - 0.5) * 2) * g.uniform(0.97, 1.03))
    grain_x(tube(name, pts, radii, LOG, "wood", 2.4, verts=12))
    for p, q, rr, s in ((pts[0], pts[1], radii[0], 0), (pts[-1], pts[-2], radii[-1], 1)):
        d = (p - q).normalized()
        K.limb(f"{name}Cut{s}", p - d * 0.02, p + d * 0.05, rr * 1.0, rr * 0.93, CUT, verts=12, end=False)
        K.limb(f"{name}Heart{s}", p + d * 0.04, p + d * 0.065, rr * 0.5, rr * 0.42, HEART, verts=10, end=False)
    for k in range(g.randint(1, 2)):
        x = g.uniform(-0.38, 0.38) * length
        face = 1 if g.random() < 0.5 else -1
        ang = g.uniform(rad(-25), rad(25))
        K.ball(f"{name}Knot{k}", (x, face * math.cos(ang) * r * 0.95, z + math.sin(ang) * r * 0.95), r * 0.17, KNOT, (1.5, 0.6, 1.0),
               seg=8)


def post(name, x, y, h, r, tip, tip_key=None):
    """an upright post with the grain running up it and a sharpened top"""
    K.limb(name, (x, y, 0.0), (x, y, h - r * 1.7), r, r * 0.96, POST, verts=12, end=False, key="wood", tile=2.4)
    cone_to(name + "Tip", (x, y, h - r * 1.72), (x, y, h), r * 0.96, tip, verts=12)


def lashing(name, x, z, thick=0.1, turns=2):
    """rope wound round a front and a back post and the logs between them"""
    for turn in range(turns):
        zz = z + turn * 0.21
        pts = []
        for k in range(17):
            a = 2 * math.pi * k / 16
            pts.append((x + math.cos(a) * (P["post_r"] + thick), math.sin(a) * (POST_Y + P["post_r"] + thick * 0.6), zz))
        tube(f"{name}{turn}", pts, [thick] * len(pts), ROPE, verts=6)


def iron_band(name, x, y, z, r):
    band = K.lathe(name, [(r + 0.05, z - 0.15), (r + 0.09, z - 0.1), (r + 0.09, z + 0.1), (r + 0.05, z + 0.15)], IRON_T, key="iron",
                   verts=16, cap=False)
    moved(band, (x, y, 0))
    for k in range(5):
        a = rad(k * 72 + 90 * (1 if y > 0 else -1))
        K.ball(f"{name}Rivet{k}", (x + math.cos(a) * (r + 0.1), y + math.sin(a) * (r + 0.1), z), 0.065, STUD, seg=6)


def shield(name, z, facing):
    """a solid round shield hung on the middle of the wall: a thick disc of planks, a raised brass rim with studs and a
    brass boss on a brass plate (round 1 lost the disc, so it read as a ship's wheel)"""
    rr = 1.0
    y0, y1 = R * 0.78, R * 0.78 + 0.24
    K.limb(name, (0, facing * y0, z), (0, facing * y1, z), rr, rr, SHIELD, verts=28, end=False, key="wood", tile=2.4)
    rim = K.lathe(name + "Rim", [(rr - 0.1, y0 + 0.02), (rr + 0.07, y0 + 0.02), (rr + 0.09, y1 + 0.06), (rr - 0.02, y1 + 0.1),
                                 (rr - 0.12, y1 + 0.03)], BRASS_T, key="brass", verts=28, cap=False)
    moved(rim, (0, 0, z), FACE_Y[facing])
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        K.ball(f"{name}Stud{k}", (math.cos(a) * (rr - 0.02), facing * (y1 + 0.1), z + math.sin(a) * (rr - 0.02)), 0.075, STUD, seg=6)
    K.limb(name + "Plate", (0, facing * (y1 - 0.02), z), (0, facing * (y1 + 0.05), z), 0.42, 0.38, BRASS_T, verts=16, end=False,
           key="brass", tile=1.0)
    K.ball(name + "Boss", (0, facing * (y1 + 0.06), z), 0.3, BRASS_T, (1, 0.72, 1), seg=14, key="brass", tile=1.0)


def wall(n_logs, tip):
    top = 0.0
    zs = []
    for i in range(n_logs):
        z = R * 0.95 + i * STEP
        log(f"Log{i}", z, P["length"] * (1.0 - 0.015 * (i % 2)), R * (1.0 - 0.025 * i), 100 + i)
        zs.append(z)
        top = z + R
    # a dark core between the faces: nothing behind the logs to see through, ever
    K.block("Core", (0, 0, (0.15 + top - 0.3) / 2), (P["length"] * 0.9, R * 0.9, top - 0.45), K.WOOD_DARK, key="wood_dark", tile=2.0)
    for s in (-1, 1):
        x = s * P["post_x"]
        for side in (-1, 1):
            post(f"Post{s}{side}", x + side * 0.08, side * POST_Y, P["post_h"], P["post_r"], tip)
        if stage == "l1":
            lashing(f"Lash{s}Low", x, zs[0] + STEP * 0.35)
            lashing(f"Lash{s}High", x, top - R * 0.75)
    return top, zs


top, zs = wall(P["logs"], RED if stage == "thorn" else TIP)
if stage != "l1":
    for s in (-1, 1):
        for side in (-1, 1):
            for z in (0.85, P["post_h"] - 1.55):
                iron_band(f"Band{s}{side}{z:.1f}", s * P["post_x"] + side * 0.08, side * POST_Y, z, P["post_r"])
    shield_z = zs[2]
    shield("ShieldFront", shield_z, 1)
    shield("ShieldBack", shield_z, -1)

if stage == "thorn":
    # the rack: a rail across the road in front of the wall, a back row of long stakes crossing through it in pairs,
    # a front row of short ones low at the ground; fire-hardened red with charred points, dirt heaped at each foot
    tilt = rad(P["stake_tilt"])
    base_y = R + 0.35
    rail_y = R + 1.0
    rail_z = 0.02 + (rail_y - base_y) * math.tan(tilt)
    K.block("Rail", (0, rail_y, rail_z), (P["length"] * 0.84, 0.3, 0.34), RAIL, key="wood_dark", tile=2.0, bevel=0.06)
    front_y = 0.0
    n = P["stakes"]
    for k in range(n):
        x = ((k + 0.5) / n - 0.5) * P["length"] * 0.78
        lean = 0.3 if k % 2 == 0 else -0.3
        base = Vector((x - lean * (rail_y - base_y) / math.cos(tilt) * 0.9, base_y, 0.02))
        d = Vector((lean, math.cos(tilt), math.sin(tilt))).normalized()
        ln = P["stake_len"] * (0.92 + 0.08 * rnd.random())
        r0 = 0.24
        K.limb(f"Stake{k}", base, base + d * (ln * 0.56), r0, r0 * 0.94, POST, verts=10, end=False, key="wood", tile=2.4)
        K.limb(f"Stake{k}Red", base + d * (ln * 0.555), base + d * (ln * 0.86), r0 * 0.95, r0 * 0.45, RED, verts=10, end=False)
        cone_to(f"Stake{k}Point", base + d * (ln * 0.855), base + d * ln, r0 * 0.46, CHAR, verts=10)
        K.ball(f"Stake{k}Mound", (base.x, base.y, 0.0), 0.42, DIRT, (1.2, 1.0, 0.4), seg=10)
        cross = base + d * ((rail_y - base_y) / d.y)
        K.ball(f"Stake{k}Rivet", (cross.x, rail_y + 0.16, rail_z), 0.07, STUD, seg=6)
        front_y = max(front_y, (base + d * ln).y)
    ft = rad(28)
    for k in range(P["front"]):
        x = ((k + 0.5) / P["front"] - 0.5) * P["length"] * 0.7 + rnd.uniform(-0.12, 0.12)
        base = Vector((x, R + 1.45, 0.02))
        d = Vector((rnd.uniform(-0.08, 0.08), math.cos(ft), math.sin(ft))).normalized()
        ln = P["front_len"] * (0.9 + 0.1 * rnd.random())
        r0 = 0.2
        K.limb(f"Low{k}", base, base + d * (ln * 0.45), r0, r0 * 0.94, POST, verts=8, end=False, key="wood", tile=2.4)
        K.limb(f"Low{k}Red", base + d * (ln * 0.445), base + d * (ln * 0.84), r0 * 0.95, r0 * 0.45, RED, verts=8, end=False)
        cone_to(f"Low{k}Point", base + d * (ln * 0.835), base + d * ln, r0 * 0.46, CHAR, verts=8)
        K.ball(f"Low{k}Mound", (base.x, base.y, 0.0), 0.36, DIRT, (1.2, 1.0, 0.4), seg=10)
        front_y = max(front_y, (base + d * ln).y)
    # braces behind, so the wall leans into the hits (and the model's box stays centred on the wall line)
    for k, x in enumerate((-P["post_x"] * 0.6, 0.0, P["post_x"] * 0.6)):
        top_b = Vector((x, -R * 0.55, P["post_h"] * 0.6))
        foot = Vector((x, -(front_y - 0.5), 0.08))   # (its dirt heap then ends where the front stakes do)
        K.limb(f"Brace{k}", foot, top_b, 0.24, 0.21, POST, verts=10, end=False, key="wood", tile=2.4)
        K.block(f"BraceFoot{k}", (foot.x, foot.y, 0.12), (0.7, 0.55, 0.24), RAIL, key="wood_dark", tile=2.0, bevel=0.06)
        K.ball(f"BraceMound{k}", (foot.x, foot.y, 0.0), 0.45, DIRT, (1.3, 1.1, 0.4), seg=10)

if stage == "root":
    # thick living roots: they come over the top of the wall, twist down both faces and splay over the road
    reach = P["reach"]

    def root(name, x0, s, phase, r0=0.4):
        w = 0.45
        pts = [(x0, -s * 0.2, top + 0.05), (x0 + w * 0.3, s * R * 0.5, top + 0.14), (x0 + w * 0.55, s * (R + 0.2), top - 0.45)]
        radii = [r0 * 0.85, r0, r0 * 0.95]
        zz = top - 0.45
        k = 0
        while zz > 0.55:
            k += 1
            zz = top - 0.45 - k * 0.6
            zz = max(zz, 0.45)
            pts.append((x0 + w * math.sin(phase + k * 1.1), s * (R + 0.24 + 0.05 * math.sin(k * 1.7)), zz))
            radii.append(r0 * (0.93 - 0.04 * k))
        last = Vector(pts[-1])
        drift = w * math.sin(phase + (k + 1) * 1.1)
        for (dy, dz, rr) in ((0.6, 0.2, 0.62), (1.2, 0.1, 0.45), (1.8, 0.06, 0.3), (reach - R, 0.04, 0.14)):
            pts.append((x0 + drift + (dy - 0.5) * 0.25 * (1 if phase > 0 else -1), s * (R + dy), dz))
            radii.append(r0 * rr)
        tube(name, pts, radii, ROOT_T, "bark", 1.6, verts=10)
        # two side roots fork off on the road
        fork = Vector(pts[-4])
        for f, sx in enumerate((-1, 1)):
            tip = fork + Vector((sx * rnd.uniform(0.9, 1.4), s * rnd.uniform(0.6, 1.1), -0.12))
            mid = fork.lerp(tip, 0.5) + Vector((0, 0, 0.06))
            tube(f"{name}Fork{f}", [fork, mid, tip], [r0 * 0.4, r0 * 0.28, r0 * 0.08], ROOT_T, "bark", 1.6, verts=8)

    for k, x0 in enumerate((-4.0, -2.2, 2.0, 3.3)):
        root(f"RootF{k}", x0, 1, 0.7 + k * 1.3)
    for k, x0 in enumerate((-4.2, -2.4, 2.3, 4.0)):
        root(f"RootB{k}", x0, -1, -0.5 - k * 1.1, r0=0.36)
    # one root winds round the right front post on its way down
    px, py, pr = P["post_x"] + 0.08, POST_Y, P["post_r"]
    pts, radii = [(px - 1.4, -0.1, top + 0.1), (px - 0.95, py * 0.5, top + 0.05)], [0.3, 0.3]
    for k in range(22):
        t = k / 21
        a = rad(180) + t * rad(630)       # 1.75 turns, ending in front of the post (90 degrees)
        pts.append((px + math.cos(a) * (pr + 0.2), py + math.sin(a) * (pr + 0.2), top - 0.1 - t * (top - 0.6)))
        radii.append(0.3 - 0.06 * t)
    for dy, dz, rr in ((0.9, 0.12, 0.2), (1.7, 0.06, 0.14), (reach - py, 0.04, 0.05)):
        pts.append((px + 0.3, py + dy, dz))
        radii.append(rr)
    tube("RootPost", pts, radii, ROOT_T, "bark", 1.6, verts=10)
    # moss: a thick mat along the top that hangs a little over both faces, patches on the roots
    for k in range(9):
        x = (k / 8 - 0.5) * P["length"] * 0.88 + rnd.uniform(-0.2, 0.2)
        K.ball(f"Moss{k}", (x, rnd.uniform(-0.15, 0.15), top - 0.02), rnd.uniform(0.55, 0.7), MOSS_T, (1.5, 1.05, 0.42), seg=12,
               key="leaves", tile=1.2)
    for k in range(10):
        x = (k / 9 - 0.5) * P["length"] * 0.8 + rnd.uniform(-0.3, 0.3)
        s = 1 if k % 2 == 0 else -1
        K.ball(f"Drape{k}", (x, s * R * 0.82, top - 0.38), rnd.uniform(0.3, 0.42), MOSS_T, (1.3, 0.45, 1.0), seg=10, key="leaves",
               tile=1.2)
    # the sapling on top, right of the middle: a crooked little trunk, three twigs, a leafy crown
    sx = P["length"] * 0.16
    h = P["sapling"]
    trunk = [(sx, 0.0, top - 0.15), (sx + 0.1, 0.05, top + h * 0.4), (sx - 0.05, -0.02, top + h * 0.8), (sx + 0.08, 0.0, top + h)]
    tube("Sapling", trunk, [0.2, 0.15, 0.11, 0.08], ROOT_T, "bark", 1.2, verts=8)
    crown = Vector((sx + 0.08, 0.0, top + h + 0.2))
    for k, (dx, dy, dz) in enumerate(((-0.6, 0.1, -0.25), (0.6, -0.1, -0.2), (0.05, 0.45, -0.1), (0.0, -0.45, -0.05))):
        K.limb(f"Twig{k}", trunk[2], crown + Vector((dx, dy, dz)) * 0.9, 0.07, 0.04, ROOT_T, verts=6, end=False, key="bark", tile=1.2)
    for k, (dx, dy, dz, rr) in enumerate(((0.0, 0.0, 0.1, 0.55), (-0.6, 0.1, -0.15, 0.45), (0.6, -0.1, -0.1, 0.45),
                                         (0.05, 0.42, -0.05, 0.4), (0.0, -0.42, 0.0, 0.4))):
        K.ball(f"Crown{k}", crown + Vector((dx, dy, dz)), rr, CROWN_T, (1, 1, 0.85), seg=12, key="leaves", tile=1.0)
    for k in range(18):
        a = 2 * math.pi * k / 18 + rnd.uniform(-0.15, 0.15)
        up = rnd.uniform(-0.2, 0.75)
        n = Vector((math.cos(a), math.sin(a), up)).normalized()
        p = crown + Vector((n.x * 0.75, n.y * 0.55, n.z * 0.5 + 0.05))
        K.leaf(f"Leaf{k}", p, n, rnd.uniform(0.42, 0.55), LEAF, turn=rnd.uniform(-0.6, 0.6))

if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_barricade_{stage}", out, budget=9000)
