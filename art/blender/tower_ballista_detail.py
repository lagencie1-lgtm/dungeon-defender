"""The Ballista at its three levels, built with the tower kit to match art/ref3d/tower_ballista_l1..l3.png.
Part list from the pictures:
  level 1  stone ring footing; a wooden trestle (two A-frame legs with cross timbers and brass bolts); a turntable hub;
           the weapon: a thick stock, a curved wooden bow with rope wrappings and its string, a big bolt with an iron
           head and red fletching
  level 2  as level 1, heavier: iron-shod leg feet, iron bow arms with brass caps, a brass crank wheel on the side
  level 3  a round stone bastion with crenellations and three red banners; two level-2 ballistae on top
The weapons are their own part ("Skin_barrel": the game kicks it back on every shot). Front = the bolt's aim.
Run: blender -b -P tower_ballista_detail.py -- out.fbx <1|2|3> [params.json]"""
import json
import math
import os
import sys

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
IRON = (0.45, 0.45, 0.5)
ROPE = (0.93, 0.86, 0.68)
RED = (0.78, 0.16, 0.16)
CRIMSON = (0.7, 0.14, 0.17)
# round 2 (2026-11-24): the paintings' wood is a warm mid-dark brown (about 130, 72, 38), not the kit's pale pine
K.WOOD = (0.55, 0.32, 0.17)
K.WOOD_DARK = (0.38, 0.21, 0.11)

DEFAULTS = {
    1: dict(foot_r=2.9, foot_h=0.8, foot_n=10, leg_h=2.2, leg_spread=1.2, bow_w=4.4, stock=4.6, aim=40, pitch=14, bend=1.0, thick=1.3, roll=65),
    2: dict(foot_r=3.0, foot_h=0.8, foot_n=10, leg_h=2.4, leg_spread=1.3, bow_w=4.8, stock=5.0, aim=40, pitch=14, bend=1.0, thick=1.3, roll=65),
    # level 3: a wide squat crenellated bastion, two big ballistae side by side on it (coordinator 2026-11-24)
    3: dict(foot_r=4.4, foot_h=0.8, foot_n=12, wall_r=3.6, wall_h=2.5, bow_w=4.0, stock=4.2, aim=40, pitch=10, gap=1.9, bend=1.0, thick=1.2, roll=65),
}
P = dict(DEFAULTS[level])
saved = os.path.join(HERE, "params", f"tower_ballista_l{level}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()
K.SIZES["barrel"] = 512
A = rad(FRONT + P["aim"])
FWD = Vector((math.cos(A), math.sin(A), 0))
SIDE = Vector((-math.sin(A), math.cos(A), 0))


def place_all(objs, m):
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def weapon(name, base, iron=False, scale=1.0):
    """stock, bow, string and bolt, built at the origin pointing along +Y, then turned to the aim and tilted up.
    Round 2 (coordinator 2026-11-24, "a real bow with two arms, a string and a bolt on every level"): the bow is a big
    C at the FRONT of the stock (its middle ahead of the stock's nose, both arms sweeping back to the stock's middle),
    as thick as the paintings draw it; the string runs from both tips back to the notch at the stock's rear; the bolt
    lies on top, iron head out front, red fletching at the back"""
    before = set(bpy.context.scene.objects)
    st, bw = P["stock"] * scale, P["bow_w"] * scale
    th = P["thick"]
    with K.atlas("barrel"):
        K.block(name + "Stock", (0, 0, 0), (0.55 * scale * th, st, 0.5 * scale * th), K.WOOD, key="wood", tile=1.2, bevel=0.1)
        K.block(name + "Rail", (0, st * 0.02, 0.29 * scale * th), (0.2 * scale, st * 0.9, 0.1 * scale), K.WOOD_DARK, key="wood_dark", tile=1.0, bevel=0.03)
        for k in (-0.3, 0.05, 0.38):   # brass bands round the stock
            K.block(name + f"Band{k}", (0, st * k, 0), (0.62 * scale * th, 0.16 * scale, 0.56 * scale * th), K.BRASS, key="brass", tile=0.6, bevel=0.03)
        # the bow: a C arc, its middle ahead of the stock's nose, the arms sweeping back
        R = bw / 2
        yc = st * 0.5 - R * P["bend"] * 0.25
        pts = []
        for k in range(13):
            th_ = math.radians(-125 + 250 * k / 12)   # (a deep C: the tips come back past the arc's middle)
            # (the arc's plane leans up toward the front, as the paintings draw it: a C standing over the nose, not a
            # flat ring seen edge-on from the run camera)
            fwd = R * 0.62 * math.cos(th_)
            pts.append((R * math.sin(th_), yc + fwd * math.cos(rad(12)), 0.08 * scale + (fwd + R * 0.62 * 0.37) * math.sin(rad(12))))
        # (round 3: the paintings stand the bow nearly upright: rolled about the stock by `roll` degrees, its arms
        # reach up and down, so from the run camera's height it reads as a big C, not a flat ring seen edge-on)
        roll = rad(P.get("roll", 65))
        pts = [(x * math.cos(roll) - (z - 0.08 * scale) * math.sin(roll), y, 0.08 * scale + x * math.sin(roll) + (z - 0.08 * scale) * math.cos(roll)) for x, y, z in pts]
        rr = [0.13, 0.16, 0.19, 0.21, 0.22, 0.23, 0.24, 0.23, 0.22, 0.21, 0.19, 0.16, 0.13]
        K.chain(name + "Bow", pts, [v * scale * 1.25 for v in rr], IRON if iron else K.WOOD_DARK, seg=10)
        notch = (0, -st * 0.36, 0.34 * scale)
        for tip in (pts[0], pts[-1]):
            if iron:
                K.block(name + f"Cap{tip[0]:.1f}", tip, (0.5 * scale, 0.5 * scale, 0.5 * scale), K.BRASS, key="brass", tile=0.6, bevel=0.07)
            else:
                K.ball(name + f"Knot{tip[0]:.1f}", tip, 0.24 * scale, ROPE, seg=8)
            K.limb(name + f"String{tip[0]:.1f}", tip, notch, 0.06 * scale, 0.06 * scale, ROPE, verts=6, end=False)
        for s in (-1, 1):   # the rope wraps where the arms meet the stock
            K.ball(name + f"Wrap{s}", (s * 0.4 * scale * th, yc + R * 0.55, 0.08 * scale), 0.24 * scale, ROPE, (1.0, 1.3, 1.0), seg=8)
        # the bolt
        K.limb(name + "Bolt", (0, -st * 0.36, 0.42 * scale), (0, st * 0.62, 0.42 * scale), 0.09 * scale, 0.09 * scale, K.WOOD_DARK, verts=6, end=False)
        K.cone(name + "Head", (0, st * 0.7, 0.42 * scale), 0.22 * scale, 0.55 * scale, IRON, rot=(rad(-90), 0, 0), verts=4)
        for s in (-1, 1):
            K.block(name + f"Fletch{s}", (s * 0.16 * scale, -st * 0.22, 0.56 * scale), (0.06, 0.75 * scale, 0.36 * scale), RED, (0, s * rad(32), 0), key=None, bevel=0.0)
    made = [o for o in set(bpy.context.scene.objects) - before]
    m = Matrix.Translation(base) @ Matrix.Rotation(A - rad(90), 4, "Z") @ Matrix.Rotation(rad(P["pitch"]), 4, "X")
    place_all(made, m)
    return m @ Vector((0, P["stock"] * scale * 0.75, 0.42 * scale))


def trestle(base_z, h, spread, iron=False, scale=1.0):
    """two A-frame legs either side, cross timbers, brass bolts, a turntable hub on top"""
    for s in (-1, 1):
        c = SIDE * (s * spread)
        for f in (-1, 1):
            foot = c + FWD * (f * spread * 0.9)
            top = c * 0.55
            mid = (foot + top) / 2
            d = Vector((top.x - foot.x, top.y - foot.y, h))
            ln = d.length
            K.limb(f"Leg{s}{f}{base_z:.1f}", (foot.x, foot.y, base_z), (top.x, top.y, base_z + h), 0.42 * scale, 0.38 * scale, K.WOOD, verts=4, end=False)   # (square beams, as painted)
            for t in (0.3, 0.75):   # brass bolts down each beam
                q = Vector((foot.x, foot.y, base_z)).lerp(Vector((top.x, top.y, base_z + h)), t)
                K.ball(f"Rivet{s}{f}{t}{base_z:.1f}", tuple(q + Vector((FWD.x, FWD.y, 0)) * (-0.32 * scale * f)), 0.12 * scale, K.BRASS, seg=6)
            if iron:
                K.block(f"Shoe{s}{f}{base_z:.1f}", (foot.x, foot.y, base_z + 0.25), (0.6 * scale, 0.6 * scale, 0.5 * scale), IRON, key=None, tile=0.8, bevel=0.06)
        K.block(f"Cross{s}{base_z:.1f}", (c.x * 0.8, c.y * 0.8, base_z + h * 0.45), (0.35 * scale, spread * 1.6, 0.3 * scale), K.WOOD_DARK,
                (0, 0, A), key="wood_dark", tile=1.0, bevel=0.06)
        K.ball(f"Bolt{s}{base_z:.1f}", (c.x * 0.8 + SIDE.x * s * 0.2, c.y * 0.8 + SIDE.y * s * 0.2, base_z + h * 0.45), 0.16 * scale, K.BRASS, seg=8)
    K.lathe(f"Hub{base_z:.1f}", [(0.9 * scale, base_z + h - 0.1), (0.95 * scale, base_z + h + 0.2), (0.6 * scale, base_z + h + 0.35)], K.WOOD_DARK, key="wood_dark", verts=16)
    for s in (-1, 1):
        K.block(f"Cheek{s}{base_z:.1f}", tuple(SIDE * (s * 0.45 * scale) + Vector((0, 0, base_z + h + 0.55 * scale))), (0.25 * scale, 0.7 * scale, 0.75 * scale),
                IRON if iron else K.WOOD_DARK, (0, 0, A + rad(90)), key=None, tile=0.8, bevel=0.08)
    return base_z + h + 0.75 * scale


K.stone_ring("Foot", 0, P["foot_r"], P["foot_h"], P["foot_n"], depth=1.1)
K.lathe("FootCore", [(P["foot_r"] - 0.9, 0), (P["foot_r"] - 0.9, P["foot_h"] - 0.02)], K.MORTAR)
K.grass(P["foot_r"] - 0.05, 22, h=0.75)
fz = P["foot_h"]
muzzles = []
if level in (1, 2):
    if level == 2:   # (coordinator 2026-11-24: level 2 stands on a raised timber platform, so it reads apart from level 1)
        K.block("Platform", (0, 0, fz + 0.3), (3.6, 3.6, 0.6), K.WOOD_DARK, (0, 0, A), key="wood_dark", tile=1.2, bevel=0.1)
        for k in range(4):
            q = FWD * (1.55 * (1 if k % 2 else -1)) + SIDE * (1.55 * (1 if k < 2 else -1))
            K.block(f"PlatformCap{k}", (q.x, q.y, fz + 0.62), (0.5, 0.5, 0.14), K.BRASS, (0, 0, A), key=None, bevel=0.03)
        fz += 0.6
    top = trestle(fz, P["leg_h"], P["leg_spread"], iron=(level == 2))
    muzzles.append(weapon("W", Vector((0, 0, top)), iron=(level == 2)))
    if level == 2:   # the crank wheel on the side
        c = SIDE * 1.25 + Vector((0, 0, top - 0.5))   # (the winch wheel stands well out to one side)
        w = K.lathe("Crank", [(0.0, -0.14), (0.85, -0.14), (0.92, 0.0), (0.85, 0.14), (0.0, 0.14)], K.BRASS, key="brass", verts=16)
        w.matrix_world = Matrix.Translation(c) @ Matrix.Rotation(rad(90), 4, Vector((FWD.x, FWD.y, 0)))
        for k in range(4):
            ang = k * math.pi / 2
            K.block(f"Spoke{k}", tuple(c + SIDE * 0.16 + Vector((0, 0, 0)) + FWD * (math.cos(ang) * 0.95) + Vector((0, 0, math.sin(ang) * 0.95))),
                    (0.2, 0.2, 0.2), K.BRASS, key="brass", tile=0.6)
        K.limb("Handle", tuple(c + SIDE * 0.2 + FWD * 1.0), tuple(c + SIDE * 0.75 + FWD * 1.0), 0.09, 0.09, K.WOOD_DARK, verts=6)
        K.limb("Axle", tuple(c - SIDE * 0.9), tuple(c + SIDE * 0.1), 0.14, 0.14, IRON, verts=8)
else:
    # the bastion: cut stone wall, crenellations, a wooden deck, three red banners
    K.stone_wall("Wall", fz, fz + P["wall_h"], P["wall_r"] * 1.18, P["wall_r"], 4, 13, depth=0.5)   # (wide at the foot, as painted)
    top = fz + P["wall_h"]
    K.lathe("Deck", [(P["wall_r"] - 0.3, top - 0.05), (P["wall_r"] - 0.3, top + 0.15)], K.WOOD_DARK, key="wood_dark", verts=24)
    for i in range(8):
        a = rad(FRONT + 22.5 + i * 45)
        K.block(f"Merlon{i}", K.at(a, P["wall_r"] - 0.1, top + 0.45), (1.2, 0.7, 0.95), K.STONE, (0, 0, a + rad(90)), key=None, tile=1.2, bevel=0.14)
    for k, da in enumerate((-40, 0, 40)):
        K.banner(FRONT + da, P["wall_r"] + 0.05, top - 0.05, 1.1 if da else 1.4, 1.8 if da else 2.4, field=CRIMSON, trim=K.BRASS, mark=K.BRASS)
    for s in (-1, 1):
        base = SIDE * (s * P["gap"]) + Vector((0, 0, top + 0.15))
        before = set(bpy.context.scene.objects)
        t2 = trestle(top + 0.15, 0.8, 0.55, iron=True, scale=0.7)
        place_all([o for o in set(bpy.context.scene.objects) - before], Matrix.Translation((base.x, base.y, 0)))
        for e in (-1, 1):   # the gold arched cradle each weapon sits in
            q = Vector((base.x, base.y, t2 - 0.35)) + SIDE * (e * 0.42)
            K.block(f"Cradle{s}{e}", tuple(q), (0.22, 0.9, 1.1), K.BRASS, (0, 0, A), key="brass", tile=0.6, bevel=0.1)
        muzzles.append(weapon(f"W{s}", Vector((base.x, base.y, t2)), iron=True, scale=1.1))

for m in muzzles:
    print("MUZZLE Vector3.new(%.2f, %.2f, %.2f)" % (-m.x, m.z, m.y))
if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_ballista_l{level}", out, budget=9000)
