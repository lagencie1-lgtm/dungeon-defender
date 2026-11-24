"""The Oak Barricade (Lemp 2026-11-24: "do the oak barricade"), the first defender that stands ON the path, built with
the tower kit. Four looks, one per stage, told apart by shape on a phone (target: art/ref3d/tower_barricade_sheet.png):
  l1     a wall of three oak logs held by front and back posts (two pairs a side), pale pencil tips, rope coils
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
Round 3 (2026-11-24, after the round 2 ratings): thicker 16-sided logs with stronger round shading (they read as
boards before); a second pair of posts at +-inner_x, so the long wall reads as near-square bays like the picture;
faceted pale pencil tips; rope coils wound round each post (l1); the shield disc and plate are lathes turned with a
quaternion (limb() aims along to_track_quat("Z", "Y"), which cannot aim along Y: both discs lay flat in the wall and
showed as a dark slot); dark fire-hardened stakes in crossed pairs through a dark rail, so they stand out from the
logs; roots wound round posts and thicker; a branching sapling.
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
STAKE = (0.38, 0.32, 0.5)       # wood.png -> dark red-brown fire-hardened shafts (about 0.46, 0.23, 0.09)
POST = (0.95, 1.08, 1.9)        # a touch lighter than the logs
SHIELD = (0.42, 0.52, 1.3)      # darker planks, so the brass reads
RAIL = (1.0, 1.0, 1.0)          # wood_dark.png as it is: darker than the logs, so the rack reads in front of them
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
    # (inner_x: the second pair of posts; the picture's square bays)
    "l1": dict(length=11.0, log_r=0.62, logs=3, post_r=0.5, post_h=4.2, post_x=4.4, inner_x=1.5),
    "l2": dict(length=11.2, log_r=0.64, logs=4, post_r=0.62, post_h=5.5, post_x=4.3, inner_x=1.6),
    "thorn": dict(length=11.2, log_r=0.64, logs=4, post_r=0.62, post_h=5.5, post_x=4.3, inner_x=1.6, pairs=4, stake_len=3.8,
                  stake_tilt=58, front=6, front_len=1.8),
    "root": dict(length=11.2, log_r=0.64, logs=4, post_r=0.62, post_h=5.5, post_x=4.3, inner_x=1.6, reach=3.0, sapling=0.8),
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
STEP = R * 1.66           # logs pressed into each other: the 16-sided tube is 0.981 R thick at a face centre
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
    """turns the texture so the wood's grain runs along X (along a log), not up the face, and makes the light from
    above stronger (bright tops, dark undersides), so a log reads round and not like a board"""
    mat = o.data.materials[0]
    name = mat.name + "_alongx"
    turned = bpy.data.materials.get(name)
    if turned is None:
        turned = mat.copy()
        turned.name = name
        for n in turned.node_tree.nodes:
            if n.type == "MAPPING":
                n.inputs["Rotation"].default_value = (0.0, math.pi / 2, 0.0)
            if n.type == "MAP_RANGE" and abs(n.inputs["To Min"].default_value - 0.72) < 1e-3:
                n.inputs["To Min"].default_value = 0.5
                n.inputs["To Max"].default_value = 1.22
    o.data.materials[0] = turned
    return o


def disc_y(name, y0, y1, z, r0, r1, facing, color, key=None, tile=1.0, verts=24, x=0.0):
    """a short round slab standing on the wall face (a lathe turned to face +Y or -Y; limb() cannot aim along Y)"""
    o = K.lathe(name, [(r0, y0), (r1, y1)], color, key=key, tile=tile, verts=verts)
    return moved(o, (x, 0, z), FACE_Y[facing])


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


def cone_to(name, a, b, r0, color, key=None, tile=1.0, verts=8, facets=False):
    """a point from a to b (a limb that ends in a tip: no turning needed); facets = flat shaded, like a knife cut it"""
    K.limb(name, a, b, r0, 0.012, color, verts=verts, end=False, key=key, tile=tile)
    if facets:
        bpy.data.objects[name].data.shade_flat()


def log(name, z, length, r, seed):
    """an oak log along X: a slightly crooked swept trunk with the grain along it, sawn ends with a pale face and a
    darker heart, a knot or two on the faces"""
    g = random.Random(seed)
    pts, radii = [], []
    for k in range(7):
        t = k / 6
        pts.append(Vector(((t - 0.5) * length, g.uniform(-0.04, 0.04), z + g.uniform(-0.025, 0.025))))
        radii.append(r * (1.0 - 0.05 * abs(t - 0.5) * 2) * g.uniform(0.97, 1.03))
    grain_x(tube(name, pts, radii, LOG, "wood", 3.2, verts=16))
    for p, q, rr, s in ((pts[0], pts[1], radii[0], 0), (pts[-1], pts[-2], radii[-1], 1)):
        d = (p - q).normalized()
        K.limb(f"{name}Cut{s}", p - d * 0.02, p + d * 0.05, rr * 1.0, rr * 0.93, CUT, verts=16, end=False)
        K.limb(f"{name}Heart{s}", p + d * 0.04, p + d * 0.065, rr * 0.5, rr * 0.42, HEART, verts=10, end=False)
    for k in range(g.randint(1, 2)):
        x = g.uniform(-0.38, 0.38) * length
        face = 1 if g.random() < 0.5 else -1
        ang = g.uniform(rad(-25), rad(25))
        K.ball(f"{name}Knot{k}", (x, face * math.cos(ang) * r * 0.95, z + math.sin(ang) * r * 0.95), r * 0.17, KNOT, (1.5, 0.6, 1.0),
               seg=8)


def post(name, x, y, h, r, tip):
    """an upright post with the grain running up it and a chunky faceted pencil point"""
    K.limb(name, (x, y, 0.0), (x, y, h - r * 1.9), r, r * 0.97, POST, verts=12, end=False, key="wood", tile=2.4)
    cone_to(name + "Tip", (x, y, h - r * 1.92), (x, y, h), r * 1.0, tip, verts=8, facets=True)


def coil(name, x, y, z, r, thick=0.12, turns=2.5):
    """thick rope wound round a post (its inner side sinks into the log behind: it binds the two)"""
    n = int(turns * 8) + 1
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / 8 + rad(30)
        pts.append((x + math.cos(a) * (r + thick * 0.75), y + math.sin(a) * (r + thick * 0.75), z + k / 8 * thick * 2.1))
    tube(name, pts, [thick] * n, ROPE, verts=6)


def iron_band(name, x, y, z, r):
    band = K.lathe(name, [(r + 0.05, z - 0.15), (r + 0.09, z - 0.1), (r + 0.09, z + 0.1), (r + 0.05, z + 0.15)], IRON_T, key="iron",
                   verts=12, cap=False)
    moved(band, (x, y, 0))
    for k in range(3):    # rivets on the outer half only (the inner half sits against the logs)
        a = rad((k - 1) * 60 + 90 * (1 if y > 0 else -1))
        K.ball(f"{name}Rivet{k}", (x + math.cos(a) * (r + 0.1), y + math.sin(a) * (r + 0.1), z), 0.065, STUD, seg=6)


def shield(name, z, facing):
    """a solid round shield hung on the middle of the wall: a thick disc of planks, a raised brass rim with studs and a
    brass boss on a brass plate (round 1 lost the disc, so it read as a ship's wheel)"""
    rr = 0.95
    y0, y1 = R * 0.78, R * 0.78 + 0.24
    disc_y(name, y0, y1, z, rr, rr, facing, SHIELD, key="wood", tile=2.4, verts=28)
    rim = K.lathe(name + "Rim", [(rr - 0.1, y0 + 0.02), (rr + 0.07, y0 + 0.02), (rr + 0.09, y1 + 0.06), (rr - 0.02, y1 + 0.1),
                                 (rr - 0.12, y1 + 0.03)], BRASS_T, key="brass", verts=28, cap=False)
    moved(rim, (0, 0, z), FACE_Y[facing])
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        K.ball(f"{name}Stud{k}", (math.cos(a) * (rr - 0.02), facing * (y1 + 0.1), z + math.sin(a) * (rr - 0.02)), 0.075, STUD, seg=6)
    disc_y(name + "Plate", y1 - 0.02, y1 + 0.05, z, 0.42, 0.38, facing, BRASS_T, key="brass", tile=1.0, verts=16)
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
        for which, px in (("O", P["post_x"]), ("I", P["inner_x"])):
            x = s * px
            for side in (-1, 1):
                post(f"Post{which}{s}{side}", x + side * 0.06, side * POST_Y, P["post_h"], P["post_r"], tip)
                if stage == "l1":
                    coil(f"Rope{which}{s}{side}Low", x + side * 0.06, side * POST_Y, zs[0] - 0.05, P["post_r"])
                    coil(f"Rope{which}{s}{side}High", x + side * 0.06, side * POST_Y, top - R * 1.1, P["post_r"])
    return top, zs


POSTS = [(s * px + side * 0.06, side * POST_Y) for s in (-1, 1) for px in (P["post_x"], P["inner_x"]) for side in (-1, 1)]
top, zs = wall(P["logs"], TIP)
if stage != "l1":
    for k, (x, y) in enumerate(POSTS):
        for z in (0.85, P["post_h"] - 1.75):
            iron_band(f"Band{k}_{z:.1f}", x, y, z, P["post_r"])
    shield_z = zs[2]
    shield("ShieldFront", shield_z, 1)
    shield("ShieldBack", shield_z, -1)

if stage == "thorn":
    # the rack: a dark rail across the road in front of the wall, long fire-hardened stakes crossing through it in
    # pairs (an X at the rail, like the picture), a low front row at the ground; dark shafts, red hardened ends, charred
    # points, so they stand out from the warm logs behind; dirt heaped at each foot
    tilt = rad(P["stake_tilt"])
    base_y = R + 0.35
    rail_y = R + 1.0
    rail_z = 0.02 + (rail_y - base_y) * math.tan(tilt)
    K.block("Rail", (0, rail_y, rail_z), (P["length"] * 0.86, 0.32, 0.36), RAIL, key="wood_dark", tile=2.0, bevel=0.06)
    front_y = 0.0

    def stake(name, base, d, ln, r0, verts=10):
        K.limb(name, base, base + d * (ln * 0.4), r0, r0 * 0.96, STAKE, verts=verts, end=False, key="wood", tile=2.4)
        K.limb(name + "Red", base + d * (ln * 0.395), base + d * (ln * 0.84), r0 * 0.97, r0 * 0.5, RED, verts=verts, end=False)
        cone_to(name + "Point", base + d * (ln * 0.835), base + d * ln, r0 * 0.51, CHAR, verts=verts)
        return base + d * ln

    for k in range(P["pairs"]):
        xp = ((k + 0.5) / P["pairs"] - 0.5) * P["length"] * 0.8
        for j, lean in enumerate((0.35, -0.35)):
            d = Vector((lean, math.cos(tilt), math.sin(tilt))).normalized()
            reach_t = (rail_y - base_y) / d.y
            base = Vector((xp - d.x * reach_t, base_y, 0.02))
            ln = P["stake_len"] * (0.93 + 0.07 * rnd.random())
            tip = stake(f"Stake{k}{j}", base, d, ln, 0.25)
            K.ball(f"Stake{k}{j}Mound", (base.x, base.y, 0.0), 0.42, DIRT, (1.2, 1.0, 0.4), seg=10)
            front_y = max(front_y, tip.y)
        K.ball(f"Rivet{k}", (xp, rail_y + 0.17, rail_z), 0.09, STUD, seg=8)
    ft = rad(28)
    for k in range(P["front"]):
        x = ((k + 0.5) / P["front"] - 0.5) * P["length"] * 0.74 + rnd.uniform(-0.12, 0.12)
        base = Vector((x, R + 1.45, 0.02))
        d = Vector((rnd.uniform(-0.08, 0.08), math.cos(ft), math.sin(ft))).normalized()
        tip = stake(f"Low{k}", base, d, P["front_len"] * (0.9 + 0.1 * rnd.random()), 0.21, verts=8)
        K.ball(f"Low{k}Mound", (base.x, base.y, 0.0), 0.36, DIRT, (1.2, 1.0, 0.4), seg=10)
        front_y = max(front_y, tip.y)
    # braces behind, so the wall leans into the hits (and the model's box stays centred on the wall line)
    for k, x in enumerate((-(P["post_x"] + P["inner_x"]) / 2, (P["post_x"] + P["inner_x"]) / 2)):   # (none behind the shield)
        top_b = Vector((x, -R * 0.55, P["post_h"] * 0.55))
        foot = Vector((x, -(front_y - 0.5), 0.08))   # (its dirt heap then ends where the front stakes do)
        K.limb(f"Brace{k}", foot, top_b, 0.25, 0.22, STAKE, verts=10, end=False, key="wood", tile=2.4)
        K.block(f"BraceFoot{k}", (foot.x, foot.y, 0.12), (0.7, 0.55, 0.24), RAIL, key="wood_dark", tile=2.0, bevel=0.06)
        K.ball(f"BraceMound{k}", (foot.x, foot.y, 0.0), 0.45, DIRT, (1.3, 1.1, 0.4), seg=10)

if stage == "root":
    # thick living roots: some come over the top and twist down the bays, some wind round a post on the way down; all
    # splay over the road with forks. Both faces, the same reach, so the model's box stays centred.
    reach = P["reach"]

    def splay(name, pts, radii, x, s, r0, lean, dys=((0.6, 0.2, 0.62), (1.2, 0.1, 0.45), (1.8, 0.06, 0.3))):
        dys = tuple(dys) + ((reach - R, 0.04, 0.14),)
        for (dy, dz, rr) in dys:
            pts.append((x + (dy - 0.5) * 0.3 * lean, s * (R + dy), dz))
            radii.append(r0 * rr)
        tube(name, pts, radii, ROOT_T, "bark", 1.6, verts=10)
        fork = Vector(pts[-len(dys)])
        for f, sx in enumerate((-1, 1)):
            tip = fork + Vector((sx * rnd.uniform(0.9, 1.3), s * rnd.uniform(0.6, 1.0), -0.12))
            mid = fork.lerp(tip, 0.5) + Vector((0, 0, 0.07))
            tube(f"{name}Fork{f}", [fork, mid, tip], [r0 * 0.42, r0 * 0.3, r0 * 0.08], ROOT_T, "bark", 1.6, verts=8)

    def root(name, x0, s, phase, r0=0.48, w=0.22):
        pts = [(x0, -s * 0.2, top + 0.06), (x0 + w * 0.3, s * R * 0.5, top + 0.16), (x0 + w * 0.5, s * (R + 0.22), top - 0.45)]
        radii = [r0 * 0.85, r0, r0 * 0.96]
        k = 0
        zz = top - 0.45
        while zz > 0.5:
            k += 1
            zz = max(top - 0.45 - k * 0.6, 0.45)
            pts.append((x0 + w * math.sin(phase + k * 1.1), s * (R + 0.26 + 0.05 * math.sin(k * 1.7)), zz))
            radii.append(r0 * (0.95 - 0.035 * k))
        splay(name, pts, radii, pts[-1][0], s, r0, 1 if phase > 0 else -1)

    def wind(name, px, s, turns=1.6, r0=0.36):
        py, ra = s * POST_Y, P["post_r"] + 0.2
        a_end = rad(90) if s > 0 else rad(270)
        a0 = a_end - turns * 2 * math.pi
        pts = [(px + math.cos(a0) * ra * 1.4, -s * 0.15, top + 0.1)]
        radii = [r0]
        n = int(turns * 14)
        for k in range(n + 1):
            t = k / n
            a = a0 + t * (a_end - a0)
            pts.append((px + math.cos(a) * ra, py + math.sin(a) * ra, top - 0.1 - t * (top - 0.6)))
            radii.append(r0 * (1 - 0.2 * t))
        out_dy = POST_Y + ra - R      # the ground part starts in front of the post, not back at the wall
        splay(name, pts, radii, px + 0.2, s, r0 * 0.85, 1 if px > 0 else -1,
              dys=((out_dy + 0.3, 0.2, 0.55), (out_dy + 0.65, 0.08, 0.35)))

    mid = (P["post_x"] + P["inner_x"]) / 2
    root("RootF0", -mid, 1, 0.7)
    root("RootF1", mid, 1, 2.3)
    root("RootB0", -mid, -1, -0.6, r0=0.44)
    root("RootB1", mid, -1, -1.9, r0=0.44)
    wind("WindF0", P["post_x"] + 0.06, 1)
    wind("WindF1", -P["inner_x"] + 0.06, 1, turns=1.3)
    wind("WindB0", -P["post_x"] - 0.06, -1)
    wind("WindB1", P["inner_x"] - 0.06, -1, turns=1.3)
    # moss: a thick mat along the top that hangs over both faces
    for k in range(11):
        x = (k / 10 - 0.5) * P["length"] * 0.9 + rnd.uniform(-0.2, 0.2)
        K.ball(f"Moss{k}", (x, rnd.uniform(-0.15, 0.15), top - 0.02), rnd.uniform(0.55, 0.72), MOSS_T, (1.4, 1.1, 0.45), seg=10,
               key="leaves", tile=1.2)
    for k in range(14):
        x = (k / 13 - 0.5) * P["length"] * 0.86 + rnd.uniform(-0.25, 0.25)
        s = 1 if k % 2 == 0 else -1
        K.ball(f"Drape{k}", (x, s * R * 0.84, top - 0.42), rnd.uniform(0.34, 0.46), MOSS_T, (1.3, 0.45, 1.1), seg=8, key="leaves",
               tile=1.2)
    # the sapling on top, right of the middle: a crooked trunk that splits into four branches, each with a leafy tuft
    sx = mid           # in the middle of the right bay, growing out of the root that comes over the top there
    h = P["sapling"]
    fork = Vector((sx + 0.05, 0.0, top + h))
    tube("Sapling", [(sx, 0.0, top - 0.15), (sx + 0.1, 0.04, top + h * 0.5), fork], [0.22, 0.17, 0.13], ROOT_T, "bark", 1.2,
         verts=8)
    for k, (dx, dy, dz) in enumerate(((-0.85, 0.15, 0.35), (0.8, -0.1, 0.45), (0.1, 0.6, 0.55), (-0.1, -0.55, 0.6))):
        end = fork + Vector((dx, dy, dz))
        bend = fork.lerp(end, 0.5) + Vector((0, 0, 0.12))
        tube(f"Branch{k}", [fork, bend, end], [0.1, 0.08, 0.05], ROOT_T, "bark", 1.2, verts=6)
        K.ball(f"Tuft{k}", end + Vector((0, 0, 0.12)), 0.42, CROWN_T, (1.1, 1.1, 0.8), seg=10, key="leaves", tile=1.0)
        K.ball(f"Tuft{k}b", end + Vector((dx * 0.25, dy * 0.25, 0.32)), 0.3, CROWN_T, (1, 1, 0.85), seg=10, key="leaves", tile=1.0)
        for j in range(5):
            a = 2 * math.pi * j / 5 + k
            n = Vector((math.cos(a), math.sin(a), rnd.uniform(0.1, 0.8))).normalized()
            K.leaf(f"Leaf{k}_{j}", end + Vector((n.x * 0.4, n.y * 0.4, 0.15 + n.z * 0.3)), n, rnd.uniform(0.4, 0.5), LEAF,
                   turn=rnd.uniform(-0.6, 0.6))

if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_barricade_{stage}", out, budget=10000)
