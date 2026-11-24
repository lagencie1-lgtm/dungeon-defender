"""The Oak Barricade (Lemp 2026-11-24: "do the oak barricade"), the first defender that stands ON the path, built with
the tower kit. Four looks, one per stage, told apart by shape on a phone (target: art/ref3d/tower_barricade_sheet.png).
Every stage has the picture's near-square centre section (logs between two big post pairs, log ends sticking out past
them) and lower log wings out to the road edges, each held by a smaller post pair, so the road is closed but the
silhouette reads as the picture's gate and not as a long fence:
  l1     three logs in the centre, two in the wings, pale faceted pencil tips, thick rope coils round every post
  l2     four logs in the centre, three in the wings, thicker posts with iron bands and brass rivets, a big round
         shield (wooden planks, brass rim with studs, brass boss) filling the centre bay on both faces
  thorn  (level 3, Thornwall) the level 2 wall behind a rack of long fire-hardened stakes crossing in pairs through a
         dark rail and a low front row, plus a crest of red spikes along the top that shows from the player's side too;
         braces behind
  root   (level 3, Rootwall) the level 2 wall gripped by thick living roots that wind round the big posts, come over the
         wings and spread over the road on both faces, a moss mat on top and a leafy branching sapling
Axes: Blender X runs ALONG the wall (across the path, the game's local X), +Y is the side enemies come from (the game
puts the wall with CFrame.lookAt(spot, spot + walk direction): enemies arrive from its local +Z, which the FBX export
makes of Blender +Y), Z is up. Keep the plan view centred on the wall line: the game stands the middle of the model's
box on the path, so anything sticking out in front needs a match behind (the thorn wall's braces, the roots both ways).
Heights must match LEVEL_LOOKS / BRANCH_LOOKS in src/server/TowerService.luau (the game scales each look to them).
Turntables: 0 degrees is the player side (-Y), 180 the enemy side (+Y).

Lessons kept from rounds 1-3 (2026-11-24):
- build every part in place (moved() transforms the mesh); never obj.location afterwards (the hidden-face cull tested
  moved parts where they were made and deleted the shield disc, stake tips and iron bands)
- limb() aims with to_track_quat("Z", "Y") and cannot aim along +-Y: slabs facing the road are lathes turned with a
  quaternion (disc_y), or both shield discs lie flat inside the wall
- logs are 16-sided swept tubes 1.66 radii apart over a dark core; wood.png with the grain turned along each log and a
  strong light from above (bright tops, dark undersides), or they read as boards
- the bake only has light from above, so a cone's facets all bake alike: pencil tips get a side light (facet_light)
- stakes need dark shafts and red ends, or they vanish against the warm logs; the long wall with eight posts read as a
  picket fence (round 3), hence the centre section and wings
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
RED = (0.72, 0.25, 0.13)        # fire-hardened stake (the Thornwall's colour)
CHAR = (0.26, 0.1, 0.07)        # the charred point
DIRT = (0.5, 0.36, 0.23)
LEAF = (0.45, 0.74, 0.3)

BASE = dict(length=10.4, log_r=0.62, logs=4, wing_logs=3, big_r=0.7, big_x=2.05, wing_r=0.5, wing_x=4.35, shield=1.3)
DEFAULTS = {
    # length: logs end to end across the road (10 studs wide); logs/wing_logs: stacked in the centre and the wings;
    # big_*: the centre post pairs (radius, x; their points start 0.4 above the top log); wing_*: the small post
    # pairs; shield: its radius (0 = none)
    "l1": dict(BASE, log_r=0.6, logs=3, wing_logs=2, big_r=0.58, big_x=2.0, wing_r=0.44, wing_x=4.4, shield=0),
    "l2": dict(BASE),
    "thorn": dict(BASE, pairs=4, stake_len=4.6, stake_tilt=60, front=6, front_len=1.9, crest=0.62),
    "root": dict(BASE, reach=3.0, sapling=1.0),
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
FACE_Y = {1: Quaternion((1, 0, 0), rad(-90)), -1: Quaternion((1, 0, 0), rad(90))}   # turns a lathe's +Z to +Y / -Y
LIGHT = Vector((0.55, 0.0, 0.83)).normalized()   # facet_light: from above and the +X side, the same on both faces


def post_y(r):
    return R + r * 0.85


def moved(o, loc=(0, 0, 0), quat=None):
    """moves a part's mesh itself (never obj.location: see the notes above)"""
    m = Matrix.Translation(Vector(loc))
    if quat is not None:
        m = m @ quat.to_matrix().to_4x4()
    o.data.transform(m)
    o.data.update()
    return o


def _variant(o, suffix, change):
    mat = o.data.materials[0]
    name = mat.name + suffix
    made = bpy.data.materials.get(name)
    if made is None:
        made = mat.copy()
        made.name = name
        change(made)
    o.data.materials[0] = made
    return o


def grain_x(o):
    """turns the texture so the wood's grain runs along X (along a log), not up the face, and makes the light from
    above stronger (bright tops, dark undersides), so a log reads round and not like a board"""
    def change(m):
        for n in m.node_tree.nodes:
            if n.type == "MAPPING":
                n.inputs["Rotation"].default_value = (0.0, math.pi / 2, 0.0)
            if n.type == "MAP_RANGE" and abs(n.inputs["To Min"].default_value - 0.72) < 1e-3:
                n.inputs["To Min"].default_value = 0.5
                n.inputs["To Max"].default_value = 1.22
    return _variant(o, "_alongx", change)


def facet_light(o):
    """lights the part from LIGHT instead of straight above, so the flat facets of a pencil point bake in different
    shades (with light from above only, every facet of a cone has the same slope and bakes the same)"""
    def change(m):
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type == "MAP_RANGE" and abs(n.inputs["To Min"].default_value - 0.72) < 1e-3:
                geo = nt.nodes.new("ShaderNodeNewGeometry")
                dot = nt.nodes.new("ShaderNodeVectorMath")
                dot.operation = "DOT_PRODUCT"
                dot.inputs[1].default_value = tuple(LIGHT)
                nt.links.new(geo.outputs["Normal"], dot.inputs[0])
                nt.links.new(dot.outputs["Value"], n.inputs["Value"])
                n.inputs["To Min"].default_value = 0.55
                n.inputs["To Max"].default_value = 1.2
    return _variant(o, "_facets", change)


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
    """a point from a to b (a limb that ends in a tip: no turning needed); facets = flat shaded and side lit, like a
    knife cut it"""
    K.limb(name, a, b, r0, 0.012, color, verts=verts, end=False, key=key, tile=tile)
    if facets:
        o = bpy.data.objects[name]
        o.data.shade_flat()
        facet_light(o)


def log(name, z, x0, x1, r, seed):
    """an oak log from x0 to x1: a slightly crooked swept trunk with the grain along it, sawn ends with a pale face and
    a darker heart (a size larger than the trunk, so no gap shows at its rim), a knot or two on the faces"""
    g = random.Random(seed)
    length = x1 - x0
    pts, radii = [], []
    for k in range(7):
        t = k / 6
        pts.append(Vector((x0 + t * length, g.uniform(-0.04, 0.04), z + g.uniform(-0.025, 0.025))))
        radii.append(r * (1.0 - 0.05 * abs(t - 0.5) * 2) * g.uniform(0.97, 1.03))
    grain_x(tube(name, pts, radii, LOG, "wood", 3.2, verts=16))
    for p, q, rr, s in ((pts[0], pts[1], radii[0], 0), (pts[-1], pts[-2], radii[-1], 1)):
        d = (p - q).normalized()
        K.limb(f"{name}Cut{s}", p - d * 0.08, p + d * 0.05, rr * 1.035, rr * 0.96, CUT, verts=16, end=False)
        K.limb(f"{name}Heart{s}", p + d * 0.04, p + d * 0.065, rr * 0.5, rr * 0.42, HEART, verts=10, end=False)
    for k in range(g.randint(1, 2)):
        x = x0 + g.uniform(0.12, 0.88) * length
        face = 1 if g.random() < 0.5 else -1
        ang = g.uniform(rad(-25), rad(25))
        K.ball(f"{name}Knot{k}", (x, face * math.cos(ang) * r * 0.95, z + math.sin(ang) * r * 0.95), r * 0.17, KNOT, (1.5, 0.6, 1.0),
               seg=8)


def post(name, x, y, h, r):
    """an upright post with the grain running up it and a chunky faceted pale pencil point"""
    K.limb(name, (x, y, 0.0), (x, y, h - r * 1.9), r, r * 0.97, POST, verts=12, end=False, key="wood", tile=2.4)
    cone_to(name + "Tip", (x, y, h - r * 1.92), (x, y, h), r * 1.0, TIP, verts=8, facets=True)


def coil(name, x, y, z, r, thick=0.12, turns=2.5):
    """thick rope wound round a post (its inner side sinks into the log behind: it binds the two)"""
    n = int(turns * 8) + 1
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / 8 + rad(30)
        pts.append((x + math.cos(a) * (r + thick * 0.75), y + math.sin(a) * (r + thick * 0.75), z + k / 8 * thick * 2.1))
    tube(name, pts, [thick] * n, ROPE, verts=6)


def iron_band(name, x, y, z, r):
    band = K.lathe(name, [(r + 0.05, z - 0.16), (r + 0.1, z - 0.11), (r + 0.1, z + 0.11), (r + 0.05, z + 0.16)], IRON_T, key="iron",
                   verts=12, cap=False)
    moved(band, (x, y, 0))
    for k in range(3):    # rivets on the outer half only (the inner half sits against the logs)
        a = rad((k - 1) * 60 + 90 * (1 if y > 0 else -1))
        K.ball(f"{name}Rivet{k}", (x + math.cos(a) * (r + 0.11), y + math.sin(a) * (r + 0.11), z), 0.07, STUD, seg=6)


def shield(name, z, facing, rr):
    """the centrepiece: a big solid round shield filling the centre bay, a thick disc of planks, a raised brass rim with
    studs and a brass boss on a brass plate"""
    y0, y1 = R * 0.78, R * 0.78 + 0.26
    disc_y(name, y0, y1, z, rr, rr, facing, SHIELD, key="wood", tile=2.8, verts=32)
    rim = K.lathe(name + "Rim", [(rr - 0.12, y0 + 0.02), (rr + 0.08, y0 + 0.02), (rr + 0.1, y1 + 0.07), (rr - 0.02, y1 + 0.12),
                                 (rr - 0.15, y1 + 0.03)], BRASS_T, key="brass", verts=32, cap=False)
    moved(rim, (0, 0, z), FACE_Y[facing])
    for k in range(14):
        a = 2 * math.pi * (k + 0.5) / 14
        K.ball(f"{name}Stud{k}", (math.cos(a) * (rr - 0.03), facing * (y1 + 0.12), z + math.sin(a) * (rr - 0.03)), 0.085, STUD, seg=6)
    disc_y(name + "Plate", y1 - 0.02, y1 + 0.06, z, 0.55, 0.5, facing, BRASS_T, key="brass", tile=1.0, verts=20)
    K.ball(name + "Boss", (0, facing * (y1 + 0.07), z), 0.38, BRASS_T, (1, 0.75, 1), seg=16, key="brass", tile=1.0)


# --- the wall: centre section and wings ----------------------------------------------------------------------------
HALF = P["length"] / 2
BX, BR, WX, WR = P["big_x"], P["big_r"], P["wing_x"], P["wing_r"]
zs = [R * 0.95 + i * STEP for i in range(P["logs"])]
top_c = zs[-1] + R                       # the centre section's top
top_w = zs[P["wing_logs"] - 1] + R       # the wings' top
wing_h = top_w + 0.35 + WR * 1.92
big_h = top_c + 0.4 + BR * 1.92
for i, z in enumerate(zs):
    r = R * (1.0 - 0.02 * i)
    if i < P["wing_logs"]:
        log(f"Log{i}", z, -HALF * (1 - 0.012 * (i % 2)), HALF * (1 - 0.012 * (i % 2)), r, 100 + i)
    else:   # the centre logs: their sawn ends stick out past the big posts, like the picture
        reach_out = BX + BR + R * 0.75
        log(f"Log{i}", z, -reach_out, reach_out, r, 100 + i)
# a dark core between the faces: nothing behind the logs to see through, ever
K.block("Core", (0, 0, (0.15 + top_w - 0.3) / 2), (P["length"] * 0.92, R * 0.9, top_w - 0.45), K.WOOD_DARK, key="wood_dark", tile=2.0)
K.block("CoreTop", (0, 0, (top_w - 0.4 + top_c - 0.3) / 2), (2 * (BX + BR), R * 0.9, top_c - top_w + 0.1), K.WOOD_DARK,
        key="wood_dark", tile=2.0)

POSTS = []   # (x, y, radius, height, kind)
for s in (-1, 1):
    for side in (-1, 1):
        POSTS.append((s * BX + side * 0.06, side * post_y(BR), BR, big_h, "big"))
        POSTS.append((s * WX + side * 0.06, side * post_y(WR), WR, wing_h, "wing"))
for k, (x, y, r, h, kind) in enumerate(POSTS):
    post(f"Post{k}", x, y, h, r)
    if stage == "l1":
        coil(f"Rope{k}Low", x, y, zs[0] - 0.05, r)
        coil(f"Rope{k}High", x, y, (top_c if kind == "big" else top_w) - R * 1.15, r)
    else:
        for z in (0.9, (h - r * 1.92) - 0.55):
            iron_band(f"Band{k}_{z:.1f}", x, y, z, r)
if P["shield"] > 0:
    shield_z = zs[1] + STEP * 0.95
    shield("ShieldFront", shield_z, 1, P["shield"])
    shield("ShieldBack", shield_z, -1, P["shield"])

if stage == "thorn":
    # the rack: a dark rail across the road in front of the wall, long fire-hardened stakes crossing through it in
    # pairs (an X at the rail, like the picture; their points rise above the wings, so the player side sees them too), a
    # low front row at the ground; dark shafts, red hardened ends, charred points; dirt heaped at each foot
    tilt = rad(P["stake_tilt"])
    base_y = R + 0.6
    rail_y = R + 1.25
    rail_z = 0.02 + (rail_y - base_y) * math.tan(tilt)
    K.block("Rail", (0, rail_y, rail_z), (P["length"] * 0.84, 0.34, 0.38), RAIL, key="wood_dark", tile=2.0, bevel=0.06)
    front_y = 0.0

    def stake(name, base, d, ln, r0, verts=10):
        K.limb(name, base, base + d * (ln * 0.42), r0, r0 * 0.96, STAKE, verts=verts, end=False, key="wood", tile=2.4)
        K.limb(name + "Red", base + d * (ln * 0.415), base + d * (ln * 0.84), r0 * 0.97, r0 * 0.5, RED, verts=verts, end=False)
        cone_to(name + "Point", base + d * (ln * 0.835), base + d * ln, r0 * 0.51, CHAR, verts=verts)
        return base + d * ln

    for k in range(P["pairs"]):
        xp = ((k + 0.5) / P["pairs"] - 0.5) * P["length"] * 0.8
        for j, lean in enumerate((0.3, -0.3)):
            d = Vector((lean, math.cos(tilt), math.sin(tilt))).normalized()
            reach_t = (rail_y - base_y) / d.y
            base = Vector((xp - d.x * reach_t, base_y, 0.02))
            ln = P["stake_len"] * (0.94 + 0.06 * rnd.random())
            tip = stake(f"Stake{k}{j}", base, d, ln, 0.27)
            K.ball(f"Stake{k}{j}Mound", (base.x, base.y, 0.0), 0.45, DIRT, (1.2, 1.0, 0.4), seg=10)
            front_y = max(front_y, tip.y)
        K.ball(f"Rivet{k}", (xp, rail_y + 0.19, rail_z), 0.1, STUD, seg=8)
    ft = rad(34)
    for k in range(P["front"]):
        x = ((k + 0.5) / P["front"] - 0.5) * P["length"] * 0.74 + rnd.uniform(-0.12, 0.12)
        base = Vector((x, R + 1.75, 0.02))
        d = Vector((rnd.uniform(-0.08, 0.08), math.cos(ft), math.sin(ft))).normalized()
        tip = stake(f"Low{k}", base, d, P["front_len"] * (0.92 + 0.08 * rnd.random()), 0.23, verts=8)
        K.ball(f"Low{k}Mound", (base.x, base.y, 0.0), 0.38, DIRT, (1.2, 1.0, 0.4), seg=10)
        front_y = max(front_y, tip.y)
    # the crest: red spikes driven into the top logs, leaning toward the enemies, seen from both sides
    for top, x_from, x_to, tag in ((top_c, -(BX - BR - 0.1), BX - BR - 0.1, "C"),
                                    (top_w, BX + BR + 0.25, WX - WR - 0.15, "R"), (top_w, -(WX - WR - 0.15), -(BX + BR + 0.25), "L")):
        n = max(1, int(round((x_to - x_from) / P["crest"])) + 1)
        for k in range(n):
            x = x_from + (x_to - x_from) * (k / (n - 1) if n > 1 else 0.5)
            lean = rad(28 + rnd.uniform(-6, 6))
            d = Vector((rnd.uniform(-0.1, 0.1), math.sin(lean), math.cos(lean))).normalized()
            stake(f"Crest{tag}{k}", Vector((x, -0.05, top - 0.35)), d, 1.45 * (0.9 + 0.1 * rnd.random()), 0.15, verts=8)
    # braces behind, so the wall leans into the hits (and the model's box stays centred on the wall line)
    for k, x in enumerate((-(BX + WX) / 2, (BX + WX) / 2)):
        top_b = Vector((x, -R * 0.55, top_w * 0.72))
        foot = Vector((x, -(front_y - 0.5), 0.08))   # (its dirt heap then ends where the front stakes do)
        K.limb(f"Brace{k}", foot, top_b, 0.26, 0.23, STAKE, verts=10, end=False, key="wood", tile=2.4)
        K.block(f"BraceFoot{k}", (foot.x, foot.y, 0.12), (0.72, 0.56, 0.24), RAIL, key="wood_dark", tile=2.0, bevel=0.06)
        K.ball(f"BraceMound{k}", (foot.x, foot.y, 0.0), 0.47, DIRT, (1.3, 1.1, 0.4), seg=10)

if stage == "root":
    # thick living roots: they wind round the big posts and come over the wings, then splay over the road with
    # forks. Both faces, the same reach, so the model's box stays centred.
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
            bend = fork.lerp(tip, 0.5) + Vector((0, 0, 0.07))
            tube(f"{name}Fork{f}", [fork, bend, tip], [r0 * 0.42, r0 * 0.3, r0 * 0.08], ROOT_T, "bark", 1.6, verts=8)

    def root(name, x0, s, phase, top, r0=0.5, w=0.14):
        pts = [(x0, -s * 0.2, top + 0.06), (x0 + w * 0.3, s * R * 0.5, top + 0.16), (x0 + w * 0.5, s * (R + 0.22), top - 0.45)]
        radii = [r0 * 0.85, r0, r0 * 0.96]
        k = 0
        zz = top - 0.45
        while zz > 0.5:
            k += 1
            zz = max(top - 0.45 - k * 0.6, 0.45)
            pts.append((x0 + w * math.sin(phase + k * 1.1), s * (R + 0.26 + 0.05 * math.sin(k * 1.7)), zz))
            radii.append(r0 * (0.95 - 0.035 * k))
        splay(name, pts, radii, pts[-1][0], s, r0, 1 if x0 > 0 else -1)

    def wind(name, px, s, r, turns=1.5, r0=0.42):
        py, ra = s * post_y(r), r + 0.22
        a_end = rad(90) if s > 0 else rad(270)
        a0 = a_end - turns * 2 * math.pi
        pts = [(px + math.cos(a0) * ra * 1.4, -s * 0.15, top_c + 0.1)]
        radii = [r0]
        n = int(turns * 14)
        for k in range(n + 1):
            t = k / n
            a = a0 + t * (a_end - a0)
            pts.append((px + math.cos(a) * ra, py + math.sin(a) * ra, top_c - 0.1 - t * (top_c - 0.6)))
            radii.append(r0 * (1 - 0.2 * t))
        out_dy = post_y(r) + ra - R      # the ground part starts in front of the post, not back at the wall
        splay(name, pts, radii, px + 0.2 * (1 if px > 0 else -1), s, r0 * 0.85, 1 if px > 0 else -1,
              dys=((out_dy + 0.3, 0.2, 0.55), (out_dy + 0.65, 0.08, 0.35)))

    wing_mid = (BX + BR + WX - WR) / 2
    for s, tag in ((1, "F"), (-1, "B")):
        wind(f"Wind{tag}0", BX + 0.06 * s, s, BR, turns=1.5 if s > 0 else 1.3)
        wind(f"Wind{tag}1", -BX + 0.06 * s, s, BR, turns=1.3 if s > 0 else 1.5)
        root(f"Root{tag}0", -wing_mid, s, 0.7 if s > 0 else -0.6, top_w, r0=0.48 if s > 0 else 0.44)
        root(f"Root{tag}1", wing_mid, s, 2.3 if s > 0 else -1.9, top_w, r0=0.48 if s > 0 else 0.44)
    # moss: a flat mat along the tops that hangs over both faces
    for top, xa, xb, n, tag in ((top_c, -(BX + BR), BX + BR, 7, "C"), (top_w, BX + BR, HALF * 0.92, 3, "R"), (top_w, -HALF * 0.92, -(BX + BR), 3, "L")):
        for k in range(n):
            x = xa + (xb - xa) * (k + 0.5) / n + rnd.uniform(-0.15, 0.15)
            K.ball(f"Moss{tag}{k}", (x, rnd.uniform(-0.15, 0.15), top - 0.04), rnd.uniform(0.55, 0.72), MOSS_T, (1.5, 1.15, 0.36), seg=12,
                   key="leaves", tile=1.2)
        for k in range(n + 1):
            x = xa + (xb - xa) * k / n + rnd.uniform(-0.2, 0.2)
            s = 1 if k % 2 == 0 else -1
            K.ball(f"Drape{tag}{k}", (x, s * R * 0.84, top - 0.42), rnd.uniform(0.34, 0.46), MOSS_T, (1.3, 0.42, 1.15), seg=10,
                   key="leaves", tile=1.2)
    # the sapling on top of the centre, right of the middle (like the picture): a crooked trunk that splits into four
    # branches, each with a big leafy tuft, about half the wall's height
    sx = BX * 0.45
    h = P["sapling"]
    fork = Vector((sx + 0.06, 0.0, top_c + h))
    tube("Sapling", [(sx, 0.0, top_c - 0.15), (sx + 0.12, 0.04, top_c + h * 0.5), fork], [0.26, 0.2, 0.15], ROOT_T, "bark", 1.2, verts=8)
    for k, (dx, dy, dz) in enumerate(((-1.0, 0.15, 0.45), (0.95, -0.1, 0.55), (0.1, 0.75, 0.65), (-0.1, -0.7, 0.75))):
        end = fork + Vector((dx, dy, dz))
        bend = fork.lerp(end, 0.5) + Vector((0, 0, 0.14))
        tube(f"Branch{k}", [fork, bend, end], [0.12, 0.09, 0.06], ROOT_T, "bark", 1.2, verts=6)
        K.ball(f"Tuft{k}", end + Vector((0, 0, 0.14)), 0.55, CROWN_T, (1.15, 1.15, 0.8), seg=14, key="leaves", tile=1.0)
        K.ball(f"Tuft{k}b", end + Vector((dx * 0.3, dy * 0.3, 0.4)), 0.38, CROWN_T, (1, 1, 0.85), seg=12, key="leaves", tile=1.0)
        for j in range(8):
            a = 2 * math.pi * j / 8 + k
            n = Vector((math.cos(a), math.sin(a), rnd.uniform(0.0, 0.8))).normalized()
            K.leaf(f"Leaf{k}_{j}", end + Vector((n.x * 0.55, n.y * 0.55, 0.15 + n.z * 0.35)), n, rnd.uniform(0.5, 0.62), LEAF,
                   turn=rnd.uniform(-0.6, 0.6))

if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_barricade_{stage}", out, budget=11000)
