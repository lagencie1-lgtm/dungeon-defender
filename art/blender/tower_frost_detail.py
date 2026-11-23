"""The Frost Crystal at its three levels, built with the tower kit to match art/ref3d/tower_frost_l1..l3.png.
Part list from the pictures (one family):
  all      a stone ring footing; a tapering stone pedestal with dark wooden staves at the corners, a riveted brass
           band and brass corner brackets; a cream banner with a blue snowflake at the front; a stone slab on top
  level 1  snow capping the slab with drips; one big ice shard leaning back, two small ones at its foot
  level 2  a silver ring round the top set with three diamond gems; a cluster of ice shards; snow drips
  level 3  a silver crown: an arch over the top with a gem, curled side horns, a ring of tall shards round a glowing
           ice orb with a thin ring round it
Ice is painted (the repaint gives it the pictures' facets); the level 3 orb glows (Neon).
Run: blender -b -P tower_frost_detail.py -- out.fbx <1|2|3> [params.json]"""
import json
import math
import os
import random
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
ICE = (0.62, 0.84, 1.0)
ICE_DEEP = (0.36, 0.62, 0.95)
SNOW = (0.95, 0.97, 1.0)
SILVER = (0.78, 0.8, 0.84)
GEM = (0.45, 0.8, 1.0)
rnd = random.Random(level)

DEFAULTS = {
    1: dict(foot_r=3.1, foot_h=0.8, foot_n=10, ped_r0=2.4, ped_r1=1.9, ped_h=2.9, shard_h=3.6, shard_r=0.75, lean=14),
    2: dict(foot_r=3.1, foot_h=0.8, foot_n=10, ped_r0=2.4, ped_r1=1.9, ped_h=2.9, shard_h=3.2, shard_r=0.6, ring_r=2.2),
    3: dict(foot_r=3.1, foot_h=0.8, foot_n=10, ped_r0=2.4, ped_r1=1.9, ped_h=2.9, shard_h=3.4, shard_r=0.5, crown_r=2.3, orb_r=0.8),
}
P = dict(DEFAULTS[level])
saved = os.path.join(HERE, "params", f"tower_frost_l{level}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()


def shard(name, base, h, r, tilt=(0, 0), color=ICE):
    """an ice shard: a six-sided prism with a pointed tip, leaning by tilt (degrees about X, Y)"""
    with K.atlas("roof"):   # the ice gets its own texture room
        o = K.lathe(name, [(r * 0.8, 0), (r, h * 0.12), (r * 0.95, h * 0.72), (0.02, h)], color, key=None, verts=6, cap=True)
        o.matrix_world = Matrix.Translation(base) @ Matrix.Rotation(rad(tilt[0]), 4, "X") @ Matrix.Rotation(rad(tilt[1]), 4, "Y") @ Matrix.Rotation(rad(rnd.uniform(0, 60)), 4, "Z")
    return o


def gem(name, pos, size, facing):
    a = rad(facing)
    K.block(name + "Set", pos, (size * 1.5, 0.18, size * 1.5), SILVER, (0, rad(45), a + rad(90)), key=None, tile=0.6, bevel=0.06)
    n = Vector((math.cos(a), math.sin(a), 0))
    K.block(name, tuple(Vector(pos) + n * 0.12), (size, 0.2, size), GEM, (0, rad(45), a + rad(90)), key=None, tile=0.6, bevel=0.08)


fz = P["foot_h"]
K.stone_ring("Foot", 0, P["foot_r"], fz, P["foot_n"], depth=1.1)
K.lathe("FootCore", [(P["foot_r"] - 0.9, 0), (P["foot_r"] - 0.9, fz - 0.02)], K.MORTAR)
K.grass(P["foot_r"] - 0.05, 22, h=0.75)
# the pedestal: stone frustum, dark staves at four corners, a riveted brass band, brass corner brackets
ped_top = fz + P["ped_h"]
K.lathe("Pedestal", [(P["ped_r0"], fz), (P["ped_r1"], ped_top)], K.STONE, key=None, verts=24)
for i in range(4):
    a = rad(FRONT + 45 + i * 90)
    r_mid = (P["ped_r0"] + P["ped_r1"]) / 2 + 0.12
    K.block(f"Stave{i}", K.at(a, r_mid, fz + P["ped_h"] / 2), (0.8, 0.35, P["ped_h"] * 1.02), K.WOOD_DARK,
            (math.atan2(P["ped_r0"] - P["ped_r1"], P["ped_h"]), 0, a + rad(90)), key="wood_dark", tile=1.0, bevel=0.1)
    for zz in (fz + 0.4, ped_top - 0.4):
        rr = P["ped_r0"] + (P["ped_r1"] - P["ped_r0"]) * (zz - fz) / P["ped_h"] + 0.22
        K.block(f"Bracket{i}{zz:.1f}", K.at(a, rr, zz), (0.95, 0.22, 0.55), K.BRASS, (0, 0, a + rad(90)), key="brass", tile=0.6, bevel=0.06)
K.brass_band("Band", fz + P["ped_h"] * 0.58, (P["ped_r0"] + P["ped_r1"]) / 2 - 0.05, 0.45, 16)
K.banner(FRONT, (P["ped_r0"] + P["ped_r1"]) / 2 + 0.05, fz + P["ped_h"] * 0.7, 1.3, 1.5, field=K.CREAM, trim=K.CREAM, mark=ICE_DEEP)
K.lathe("Slab", [(P["ped_r1"] + 0.15, ped_top - 0.05), (P["ped_r1"] + 0.3, ped_top + 0.25), (P["ped_r1"] + 0.15, ped_top + 0.4), (0.3, ped_top + 0.45)],
        K.STONE, key=None, verts=24)
top = ped_top + 0.45
if level in (1, 2):
    # snow on the slab with drips over the edge
    K.lathe("Snow", [(P["ped_r1"] + 0.35, top - 0.15), (P["ped_r1"] + 0.3, top + 0.05), (P["ped_r1"] - 0.2, top + 0.2), (0.2, top + 0.22)], SNOW, key=None, verts=24)
    for i in range(9):
        a = rad(i * 40 + rnd.uniform(-8, 8))
        K.ball(f"Drip{i}", K.at(a, P["ped_r1"] + 0.33, top - 0.35), 0.16, SNOW, (0.8, 0.8, 1.6), seg=8)
if level == 1:
    shard("Shard", (0, 0.25, top), P["shard_h"], P["shard_r"], (-P["lean"], 6))
    shard("ShardS1", (0.55, -0.45, top), P["shard_h"] * 0.3, P["shard_r"] * 0.45, (18, 12))
    shard("ShardS2", (-0.6, -0.3, top), P["shard_h"] * 0.25, P["shard_r"] * 0.4, (14, -16))
elif level == 2:
    K.lathe("Ring", [(P["ring_r"] - 0.2, top - 0.05), (P["ring_r"], top), (P["ring_r"], top + 0.5), (P["ring_r"] - 0.2, top + 0.55)], SILVER, key=None, verts=32)
    for k in range(3):
        a = FRONT + (k - 1) * 70
        gem(f"Gem{k}", K.at(rad(a), P["ring_r"] + 0.1, top + 0.3), 0.42, a)
    shard("Shard", (0, 0, top), P["shard_h"], P["shard_r"] * 1.2, (-4, 3))
    for k in range(7):
        a = rad(k * 51 + 10)
        rr = P["ring_r"] * 0.55
        shard(f"Shard{k}", (math.cos(a) * rr, math.sin(a) * rr, top), P["shard_h"] * rnd.uniform(0.45, 0.7), P["shard_r"] * 0.8,
              (math.degrees(math.sin(a)) * -0.35, math.degrees(math.cos(a)) * 0.35))
else:
    K.lathe("Ring", [(P["crown_r"] - 0.25, top - 0.05), (P["crown_r"], top), (P["crown_r"], top + 0.45), (P["crown_r"] - 0.25, top + 0.5)], SILVER, key=None, verts=32)
    gem("GemFront", K.at(rad(FRONT), P["crown_r"] + 0.1, top + 0.25), 0.5, FRONT)
    # the arch over the top and the curled horns
    side = Vector((-math.sin(rad(FRONT)), math.cos(rad(FRONT)), 0))
    pts = []
    for k in range(9):
        t = math.pi * k / 8
        p = side * (math.cos(t) * P["crown_r"] * 0.85) + Vector((0, 0, top + 0.4 + math.sin(t) * P["crown_r"] * 1.15))
        pts.append(tuple(p))
    K.chain("Arch", pts, [0.16] * 9, SILVER, seg=8)
    gem("GemTop", pts[4], 0.45, FRONT)
    for s in (-1, 1):
        base = side * (s * P["crown_r"] * 0.95) + Vector((0, 0, top + 0.3))
        horn = [tuple(base + side * (s * 0.35 * math.sin(t)) + Vector((0, 0, 0.9 * t))) for t in (0, 0.5, 1.0, 1.4)]
        K.chain(f"Horn{s}", horn, [0.18, 0.15, 0.12, 0.08], SILVER, seg=8)
    for k in range(8):
        a = rad(k * 45 + 22.5)
        rr = P["crown_r"] * 0.78
        shard(f"Shard{k}", (math.cos(a) * rr, math.sin(a) * rr, top), P["shard_h"] * rnd.uniform(0.6, 0.85), P["shard_r"],
              (math.degrees(math.sin(a)) * -0.25, math.degrees(math.cos(a)) * 0.25))
    # the glowing orb with a thin ring round it (Neon)
    S.glow_ball("Orb", (0, 0, top + P["crown_r"] * 0.75), P["orb_r"], (0.6, 0.92, 1.0), seg=16)
    S.glow(K.lathe("OrbRing", [(P["orb_r"] * 1.45, -0.03), (P["orb_r"] * 1.5, 0.0), (P["orb_r"] * 1.45, 0.03)], (0.85, 0.97, 1.0), key=None, verts=24, cap=False), (0.85, 0.97, 1.0))
    bpy.data.objects["OrbRing"].matrix_world = Matrix.Translation((0, 0, top + P["crown_r"] * 0.75)) @ Matrix.Rotation(rad(20), 4, "X")

print("MUZZLE Vector3.new(0.00, %.2f, 0.00)" % (top + (P["shard_h"] * 0.7 if level < 3 else P["crown_r"] * 0.75)))
if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_frost_l{level}", out, budget=9000)
