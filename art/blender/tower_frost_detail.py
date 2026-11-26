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
    # (round 2: the drum tapers clearly, wide at the foot, as painted)
    1: dict(foot_r=3.2, foot_h=0.8, foot_n=10, ped_r0=2.7, ped_r1=1.75, ped_h=3.0, shard_h=3.6, shard_r=0.75, lean=14),
    2: dict(foot_r=3.2, foot_h=0.8, foot_n=10, ped_r0=2.7, ped_r1=1.75, ped_h=3.0, shard_h=3.2, shard_r=0.6, ring_r=2.1),
    3: dict(foot_r=3.3, foot_h=0.8, foot_n=10, ped_r0=2.8, ped_r1=1.8, ped_h=3.0, shard_h=3.0, shard_r=0.5, crown_r=2.2, orb_r=0.85),
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
for i in range(8):   # (round 2: eight dark planks round the drum, as painted)
    a = rad(FRONT + 22.5 + i * 45)
    r_mid = (P["ped_r0"] + P["ped_r1"]) / 2 + 0.12
    K.block(f"Stave{i}", K.at(a, r_mid, fz + P["ped_h"] / 2), (0.8, 0.35, P["ped_h"] * 1.02), K.WOOD_DARK,
            (math.atan2(P["ped_r0"] - P["ped_r1"], P["ped_h"]), 0, a + rad(90)), key="wood_dark", tile=1.0, bevel=0.1)
    for zz in (fz + 0.4, ped_top - 0.4):
        rr = P["ped_r0"] + (P["ped_r1"] - P["ped_r0"]) * (zz - fz) / P["ped_h"] + 0.22
        K.block(f"Bracket{i}{zz:.1f}", K.at(a, rr, zz), (0.95, 0.22, 0.55), K.BRASS, (0, 0, a + rad(90)), key="brass", tile=0.6, bevel=0.06)
K.brass_band("Band", fz + P["ped_h"] * 0.58, (P["ped_r0"] + P["ped_r1"]) / 2 - 0.05, 0.45, 16)
K.banner(FRONT, (P["ped_r0"] + P["ped_r1"]) / 2 + 0.05, fz + P["ped_h"] * 0.7, 1.3, 1.5, emblem=False, field=K.CREAM, trim=K.CREAM, mark=ICE_DEEP)
# the banner's snowflake (round 2, 2026-11-24: on every level, as painted; the kit's leaf emblem read as a figure):
# six arms with side twigs, flat on the cloth
_a = rad(FRONT)
_n = Vector((math.cos(_a), math.sin(_a), 0))
_t = Vector((-math.sin(_a), math.cos(_a), 0))
_rb = (P["ped_r0"] + P["ped_r1"]) / 2 + 0.05
_c = Vector(K.at(_a, _rb + 0.25, fz + P["ped_h"] * 0.7)) - Vector((0, 0, 1.5 * 0.55)) + _n * 0.13
for _k in range(6):
    _d = _t * math.cos(rad(_k * 60 + 90)) + Vector((0, 0, math.sin(rad(_k * 60 + 90))))
    K.limb(f"Flake{_k}", tuple(_c), tuple(_c + _d * 0.42), 0.045, 0.035, ICE_DEEP, verts=4, end=False)
    for _sgn in (-1, 1):
        _side = _t * math.cos(rad(_k * 60 + 90 + _sgn * 45)) + Vector((0, 0, math.sin(rad(_k * 60 + 90 + _sgn * 45))))
        K.limb(f"Twig{_k}{_sgn}", tuple(_c + _d * 0.24), tuple(_c + _d * 0.24 + _side * 0.16), 0.03, 0.025, ICE_DEEP, verts=4, end=False)
K.lathe("Slab", [(P["ped_r1"] + 0.15, ped_top - 0.05), (P["ped_r1"] + 0.3, ped_top + 0.25), (P["ped_r1"] + 0.15, ped_top + 0.4), (0.3, ped_top + 0.45)],
        K.STONE, key=None, verts=24)
top = ped_top + 0.45
# a heavy snow cap over the slab's edge, lumpy, with icicles hanging from it (round 2: heavier, on every level)
K.lathe("Snow", [(P["ped_r1"] + 0.5, top - 0.3), (P["ped_r1"] + 0.45, top + 0.05), (P["ped_r1"] - 0.1, top + 0.3), (0.2, top + 0.34)], SNOW, key=None, verts=24)
for i in range(12):
    a = rad(i * 30 + rnd.uniform(-8, 8))
    K.ball(f"SnowLump{i}", K.at(a, P["ped_r1"] + 0.35, top - 0.1), 0.32, SNOW, (1.2, 1.0, 0.7), seg=8)
for i in range(14):
    a = rad(i * 360 / 14 + rnd.uniform(-6, 6))
    ln = rnd.uniform(0.35, 0.8)
    K.cone(f"Icicle{i}", K.at(a, P["ped_r1"] + 0.45, top - 0.3 - ln / 2), 0.11, ln, (0.8, 0.93, 1.0), rot=(rad(180), 0, 0), verts=6)
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
        p = side * (math.cos(t) * P["crown_r"] * 0.85) + Vector((0, 0, top + 0.4 + math.sin(t) * P["crown_r"] * 1.6))   # (a tall arch)
        pts.append(tuple(p))
    K.chain("Arch", pts, [0.26] * 9, SILVER, seg=8)
    gem("GemTop", pts[4], 0.45, FRONT)
    for s in (-1, 1):
        base = side * (s * P["crown_r"] * 0.95) + Vector((0, 0, top + 0.3))
        horn = [tuple(base + side * (s * 0.35 * math.sin(t)) + Vector((0, 0, 0.9 * t))) for t in (0, 0.5, 1.0, 1.4)]
        K.chain(f"Horn{s}", horn, [0.18, 0.15, 0.12, 0.08], SILVER, seg=8)
    for k in range(8):
        a = rad(k * 45 + 22.5)
        rr = P["crown_r"] * 0.92   # (round the arch, not in front of it: the orb shows through)
        if abs(((math.degrees(a) - FRONT) + 180) % 360 - 180) < 30:
            continue   # (no crystal right in front of the orb)
        shard(f"Shard{k}", (math.cos(a) * rr, math.sin(a) * rr, top), P["shard_h"] * rnd.uniform(0.85, 1.15), P["shard_r"] * 1.1,
              (math.degrees(math.sin(a)) * -0.3, math.degrees(math.cos(a)) * 0.3))   # (big crystals rising high)
    # the glowing orb, round, floating inside the arch, with a thin ring round it (Neon)
    oz = top + P["crown_r"] * 0.95
    S.glow_ball("Orb", (0, 0, oz), P["orb_r"], (0.6, 0.92, 1.0), seg=20)
    ring = [(math.cos(2 * math.pi * k / 24) * P["orb_r"] * 1.5, math.sin(2 * math.pi * k / 24) * P["orb_r"] * 1.5 * 0.35, oz + math.sin(2 * math.pi * k / 24) * P["orb_r"] * 0.3) for k in range(25)]
    K.chain("OrbRing", ring, [0.05] * 25, (0.85, 0.97, 1.0), seg=6)
    for o in [o for o in bpy.context.scene.objects if o.name.startswith("OrbRing")]:
        S.glow(o, (0.85, 0.97, 1.0))

print("MUZZLE Vector3.new(0.00, %.2f, 0.00)" % (top + (P["shard_h"] * 0.7 if level < 3 else P["crown_r"] * 0.95)))
if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_frost_l{level}", out, budget=9000)
