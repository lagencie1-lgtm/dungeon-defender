"""The Oak Barricade (Lemp 2026-11-24: "do the oak barricade"), the first defender that stands ON the path, built with
the tower kit. Four looks, one per stage, told apart by shape on a phone:
  l1     a low wall of three oak logs held by two pairs of posts with sharpened tops, rope lashing
  l2     taller: four logs, thicker posts with iron bands and rivets, a round wooden shield crest on both faces
  thorn  (level 3, Thornwall) the level 2 wall with long fire-hardened stakes pointing out at the enemies, braces behind
  root   (level 3, Rootwall) the level 2 wall overgrown by living roots that spread over the road on both sides,
         moss on top and a small sapling
Axes: Blender X runs ALONG the wall (across the path, the game's local X), +Y is the side enemies come from (the game
puts the wall with CFrame.lookAt(spot, spot + walk direction): enemies arrive from its local +Z, which the FBX export
makes of Blender +Y), Z is up. Keep the plan view centred on the wall line: the game stands the middle of the model's
box on the path, so anything sticking out in front needs a match behind (the thorn wall's braces, the roots both ways).
Heights must match LEVEL_LOOKS / BRANCH_LOOKS in src/server/TowerService.luau (the game scales each look to them).
Run: blender -b -P tower_barricade_detail.py -- out.fbx <l1|l2|thorn|root> [params.json]"""
import json
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import sculpt as S  # noqa: E402
import tower_kit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, stage = args[0], args[1]
assert stage in ("l1", "l2", "thorn", "root"), stage
rad = math.radians
rnd = random.Random(11)
BARK = (0.62, 0.44, 0.3)
BARK_DARK = (0.45, 0.31, 0.21)
CUT = (0.93, 0.76, 0.52)        # the pale rings where a log was sawn
ROPE = (0.93, 0.86, 0.68)
IRON = (0.45, 0.45, 0.5)
STAKE_TIP = (0.42, 0.2, 0.14)   # fire-hardened, red-brown (the Thornwall's colour)
ROOT = (0.5, 0.37, 0.24)
MOSS = (0.42, 0.66, 0.27)

DEFAULTS = {
    # length along the path (the road is 10 studs wide), log radius, logs stacked, post radius, post height
    "l1": dict(length=11.0, log_r=0.55, logs=3, post_r=0.42, post_h=3.4, post_x=4.4),
    "l2": dict(length=11.2, log_r=0.56, logs=4, post_r=0.5, post_h=4.6, post_x=4.3),
    "thorn": dict(length=11.2, log_r=0.56, logs=4, post_r=0.5, post_h=5.2, post_x=4.3, stakes=6, stake_len=3.1,
                  stake_tilt=38),
    "root": dict(length=11.2, log_r=0.56, logs=4, post_r=0.5, post_h=4.6, post_x=4.3, roots=6, reach=3.2,
                 sapling=4.8),
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
STEP = R * 1.9            # logs sit a little into each other, like a real stack
POST_Y = R + P["post_r"] * 0.85


def log(name, z, length, r, seed):
    """an oak log along X: a slightly crooked trunk in bark (5 pieces), sawn ends with pale rings, a knot or two"""
    g = random.Random(seed)
    pts = []
    for k in range(5):
        t = k / 4
        x = (t - 0.5) * length
        pts.append(Vector((x, g.uniform(-0.06, 0.06), z + g.uniform(-0.05, 0.05))))
    radii = [r * (1.0 - 0.06 * abs(t - 0.5) * 2) * g.uniform(0.96, 1.04) for t in (0, 0.25, 0.5, 0.75, 1)]
    for i in range(4):
        K.limb(f"{name}{i}", pts[i], pts[i + 1], radii[i], radii[i + 1], BARK, verts=10, end=False, key="bark", tile=1.4)
    for p, rr, s in ((pts[0], radii[0], -1), (pts[-1], radii[-1], 1)):
        K.limb(f"{name}Cut{s}", p, p + Vector((s * 0.05, 0, 0)), rr * 1.01, rr * 0.92, CUT, verts=10, end=False, key="wood", tile=0.6)
    for k in range(g.randint(1, 2)):
        x = g.uniform(-0.35, 0.35) * length
        ang = g.uniform(rad(40), rad(140)) * (1 if g.random() < 0.5 else -1)
        K.ball(f"{name}Knot{k}", (x, math.cos(ang) * r * 0.92, z + math.sin(ang) * r * 0.92), r * 0.22, BARK_DARK, (1, 1, 0.7), seg=8,
               key="bark", tile=0.8)


def post(name, x, y, h, r, tip):
    """an upright post with a sharpened top; tip = the colour of the point"""
    K.limb(name, (x, y, 0.0), (x, y, h - r * 1.6), r, r * 0.95, BARK, verts=10, end=False, key="bark", tile=1.2)
    K.cone(name + "Tip", (x, y, h - r * 0.8), r * 0.97, r * 1.6, tip, verts=10, key="wood", tile=0.8)


def lashing(name, x, z, thick=0.075):
    """rope wound round a front and a back post and the logs between them (two turns, slightly apart)"""
    for turn in (0, 1):
        zz = z + turn * 0.18
        pts = []
        for k in range(13):
            a = 2 * math.pi * k / 12
            pts.append((x + math.cos(a) * (P["post_r"] + 0.08), math.sin(a) * (POST_Y + P["post_r"] + 0.06), zz))
        for i in range(12):
            K.limb(f"{name}{turn}_{i}", pts[i], pts[i + 1], thick, thick, ROPE, verts=5, end=False)


def iron_band(name, x, y, z, r):
    K.lathe(name, [(r + 0.06, z - 0.12), (r + 0.09, z), (r + 0.06, z + 0.12)], IRON, key="iron", verts=14)
    for k in range(4):
        a = rad(45 + k * 90)
        K.ball(f"{name}Rivet{k}", (x + math.cos(a) * (r + 0.1), y + math.sin(a) * (r + 0.1), z), 0.06, K.BRASS, seg=6)


def shield(name, y, z, facing):
    """a round wooden shield on the middle of the wall: planks, a brass rim and a brass boss (the crest)"""
    rr = 0.95
    disc = K.lathe(name, [(0.0, -0.08), (rr, -0.08), (rr, 0.08), (0.0, 0.1)], K.WOOD, key="wood", verts=20)
    rim = K.lathe(name + "Rim", [(rr - 0.06, -0.1), (rr + 0.07, -0.1), (rr + 0.07, 0.12), (rr - 0.06, 0.12)], K.BRASS, key="brass", verts=20)
    boss = K.ball(name + "Boss", (0, 0, 0.12), 0.26, K.BRASS, (1, 1, 0.7), seg=10)
    for o in (disc, rim, boss):
        o.rotation_euler = (rad(-90) * facing, 0, 0)
        o.location = (0, y, z)
    for k, a in enumerate((-30, 30)):
        K.limb(f"{name}Plank{k}", (math.sin(rad(a)) * rr * 0.5, y + facing * 0.1, z - rr * 0.85),
               (math.sin(rad(a)) * rr * 0.5, y + facing * 0.1, z + rr * 0.85), 0.03, 0.03, K.WOOD_DARK, verts=4, end=False)


def wall(n_logs, post_tip):
    top = 0.0
    for i in range(n_logs):
        z = R * 0.95 + i * STEP
        log(f"Log{i}", z, P["length"] * (1.0 - 0.015 * (i % 2)), R * (1.0 - 0.03 * i), 100 + i)
        top = z + R
    for s in (-1, 1):
        x = s * P["post_x"]
        for side in (-1, 1):
            post(f"Post{s}{side}", x + side * 0.08, side * POST_Y, P["post_h"], P["post_r"], post_tip)
        lashing(f"Lash{s}Low", x, R * 0.95 + STEP * 0.5)
        lashing(f"Lash{s}High", x, top - R * 0.6)
    return top


if stage == "l1":
    wall(P["logs"], K.WOOD)
else:
    top = wall(P["logs"], STAKE_TIP if stage == "thorn" else K.WOOD)
    for s in (-1, 1):
        for side in (-1, 1):
            for z in (0.9, P["post_h"] - 1.4):
                iron_band(f"Band{s}{side}{z:.1f}", s * P["post_x"] + side * 0.08, side * POST_Y, z, P["post_r"])
    shield("ShieldFront", R + 0.12, top - R * 1.4, 1)
    shield("ShieldBack", -(R + 0.12), top - R * 1.4, -1)

if stage == "thorn":
    # two rows of stakes dug in at the foot of the wall, pointing out and up at the enemies (+Y)
    tilt = rad(P["stake_tilt"])
    for row, (z0, lean) in enumerate(((0.15, 0.0), (0.9, 0.12))):
        n = P["stakes"] - row
        for k in range(n):
            x = ((k + 0.5) / n - 0.5) * P["length"] * 0.86 + rnd.uniform(-0.15, 0.15)
            base = Vector((x, R + 0.35 + row * 0.1, z0))
            d = Vector((rnd.uniform(-0.08, 0.08), math.cos(tilt - lean), math.sin(tilt - lean))).normalized()
            ln = P["stake_len"] * (0.85 + 0.15 * rnd.random()) * (0.8 if row else 1.0)
            mid = base + d * (ln * 0.72)
            K.limb(f"Stake{row}{k}", base, mid, 0.24, 0.19, BARK, verts=8, end=False, key="bark", tile=1.0)
            tip = K.cone(f"Stake{row}{k}Tip", (0, 0, 0), 0.19, ln * 0.28, STAKE_TIP, verts=8, key="wood", tile=0.6)
            tip.rotation_mode = "QUATERNION"
            tip.rotation_quaternion = d.to_track_quat("Z", "Y")
            tip.location = mid + d * (ln * 0.14)
            K.lathe(f"Stake{row}{k}Mound", [(0.42, 0.0), (0.3, 0.12), (0.0, 0.16)], BARK_DARK, key="bark", verts=8).location = (base.x, base.y, 0)
    # braces behind, so the wall leans into the hits (and the model's box stays centred on the wall line)
    for k, x in enumerate((-P["post_x"] * 0.55, 0.0, P["post_x"] * 0.55)):
        top_b = Vector((x, -R * 0.6, P["post_h"] * 0.62))
        foot = Vector((x, -(R + P["stake_len"] * math.cos(tilt) + 0.35), 0.05))
        K.limb(f"Brace{k}", foot, top_b, 0.24, 0.2, BARK, verts=8, end=False, key="bark", tile=1.0)
        K.block(f"BraceFoot{k}", (foot.x, foot.y, 0.12), (0.7, 0.5, 0.24), BARK_DARK, key="wood_dark", tile=0.8, bevel=0.06)

if stage == "root":
    # living roots climbing over the wall from the top and spreading over the road on both faces
    for k in range(P["roots"]):
        x = ((k + 0.5) / P["roots"] - 0.5) * P["length"] * 0.8 + rnd.uniform(-0.3, 0.3)
        side = 1 if k % 2 == 0 else -1
        bend = rnd.uniform(-0.6, 0.6)
        pts = [
            (x, 0.0, top + 0.18),
            (x + bend * 0.3, side * (R + 0.25), top - 0.3),
            (x + bend * 0.6, side * (R + 0.45), top * 0.5),
            (x + bend * 0.9, side * (R + 0.6), 0.25),
            (x + bend * 1.3, side * (R + 1.5), 0.1),
            (x + bend * 1.6, side * P["reach"], 0.05),
        ]
        radii = [0.3, 0.27, 0.24, 0.2, 0.14, 0.06]
        for i in range(len(pts) - 1):
            K.limb(f"Root{k}_{i}", pts[i], pts[i + 1], radii[i], radii[i + 1], ROOT, verts=8, end=False, key="bark", tile=1.0)
            K.ball(f"Root{k}_{i}J", pts[i + 1], radii[i + 1], ROOT, seg=8, key="bark", tile=0.8)
        # a side root forking off on the ground
        fork = Vector(pts[4])
        K.limb(f"Root{k}Fork", fork, fork + Vector((rnd.choice((-1, 1)) * 1.2, side * 0.6, 0.0)), 0.12, 0.04, ROOT, verts=6, end=False,
               key="bark", tile=0.8)
    for k in range(7):
        x = (k / 6 - 0.5) * P["length"] * 0.85
        K.ball(f"Moss{k}", (x, rnd.uniform(-0.2, 0.2), top + 0.05), rnd.uniform(0.35, 0.5), MOSS, (1.4, 1.0, 0.55), seg=10, key="leaves", tile=0.8)
    # the sapling on top, a little off the middle
    sx = P["length"] * 0.12
    K.limb("Sapling", (sx, 0, top), (sx + 0.15, 0.05, P["sapling"] - 0.9), 0.12, 0.07, BARK, verts=6, end=False, key="bark")
    for k, (dx, dz, rr) in enumerate(((0.0, 0.0, 0.55), (-0.45, -0.3, 0.38), (0.45, -0.25, 0.4))):
        K.ball(f"Crown{k}", (sx + 0.15 + dx, 0.05, P["sapling"] - 0.55 + dz), rr, K.LEAF, (1, 1, 0.85), seg=10, key="leaves", tile=0.8)

if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_barricade_{stage}", out, budget=9000)
