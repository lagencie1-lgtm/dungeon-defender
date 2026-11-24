"""The pets, built by hand with the sculpt kit (the Baby Dragon workflow Lemp approved on 2026-11-19: "do it with
this workflow for the other pets and towers but put a lot of effort in it"). One pet per run; each matches its
painted picture in art/icons/pet_<kind>.png. Front faces -Y, about 2 to 2.5 units tall.
Run: blender -b -P pets_hand.py -- out.fbx <kind>
kinds: slimey leafling stonepup mosskitten glowbug emberfox crystalowl minigolem starunicorn phoenix voiddrake
(the Baby Dragon is art/blender/pet_dragon.py)"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sculpt as S  # noqa: E402
from sculpt import ball, cone, cyl, limb, chain, eyes, rad, glow_ball  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, kind = args[0], args[1]
S.start()


def smile(y, z, w=0.16, color=(0.45, 0.12, 0.2), tongue=(0.98, 0.5, 0.58), open_=True):
    """A wide happy mouth: a dark smile, open a little with a pink tongue (open_) or closed."""
    ball("Mouth", (0, y, z), w, color, (1.5, 0.5, 0.5 if open_ else 0.2), seg=14)
    if open_:
        ball("Tongue", (0, y - w * 0.2, z - w * 0.2), w * 0.6, tongue, (1.3, 0.5, 0.42), seg=10)


def blush(y, z, spread, r=0.11, color=(1.0, 0.6, 0.62)):
    for s in (-1, 1):
        ball(f"Blush{s}", (s * spread, y, z), r, color, (1, 0.35, 0.7), seg=10)


# ---------------------------------------------------------------------------------------------------------------
if kind == "slimey":
    G, GL, GD = (0.40, 0.80, 0.30), (0.62, 0.92, 0.44), (0.26, 0.62, 0.20)
    # a wobbly drop: wide base, rounded top with a little curl, drips around the bottom
    ball("Base", (0, 0, 0.42), 1.0, G, (1.12, 1.05, 0.5), seg=24)
    ball("Body", (0, 0, 0.8), 0.88, G, (1.0, 0.96, 0.92), seg=24)
    ball("Top", (0.06, 0, 1.42), 0.5, G, (1.0, 1.0, 0.9), seg=18)
    chain("Curl", [(0.1, 0, 1.72), (0.22, 0, 1.92), (0.38, 0, 2.02), (0.52, 0, 1.98), (0.6, 0, 1.86)], [0.26, 0.2, 0.15, 0.11, 0.08], G)
    for i, (a, r, d) in enumerate(((20, 0.3, 1.0), (75, 0.24, 1.08), (140, 0.3, 1.0), (200, 0.26, 1.06), (255, 0.3, 1.02), (315, 0.26, 1.06))):
        ball(f"Drip{i}", (math.cos(rad(a)) * d, math.sin(rad(a)) * d * 0.95, 0.16), r, G, (1.1, 1.1, 0.6), seg=12)
    # lighter belly and glossy highlights make it read as jelly
    ball("Belly", (0, -0.62, 0.62), 0.5, GL, (1.2, 0.5, 0.8), seg=14)
    ball("Gloss", (-0.42, -0.52, 1.36), 0.2, (0.9, 1.0, 0.8), (1.2, 0.4, 0.7), rot=(0, 0, rad(-30)), seg=10)
    ball("Gloss2", (-0.6, -0.5, 1.08), 0.08, (0.9, 1.0, 0.8), (1, 0.4, 1), seg=8)
    ball("Shade", (0, 0.5, 0.5), 0.7, GD, (1.2, 0.6, 0.6), seg=12)
    eyes(1.06, -0.72, 0.34, 0.27, (0.42, 0.22, 0.10), tilt=10)
    smile(-0.9, 0.7, 0.13)
    blush(-0.78, 0.82, 0.62)
    S.finish("pet_slimey", out, triangles=5000)

elif kind == "leafling":
    G, GL, LEAF, LEAF_D, CREAM = (0.55, 0.80, 0.30), (0.72, 0.90, 0.45), (0.30, 0.68, 0.22), (0.20, 0.52, 0.16), (0.95, 0.95, 0.72)
    # a seed-shaped sprout creature: round head and body in one, stubby arms and feet, a big two-leaf sprout
    ball("Body", (0, 0, 0.62), 0.6, G, (1.05, 1.0, 0.95), seg=22)
    ball("Head", (0, -0.03, 1.34), 0.72, G, (1.08, 1.0, 0.98), seg=24)
    ball("Belly", (0, -0.4, 0.58), 0.42, CREAM, (1.1, 0.5, 0.95), seg=14)
    for s in (-1, 1):
        ball(f"Arm{s}", (s * 0.62, -0.12, 0.74), 0.17, G, (0.9, 1.0, 1.35), rot=(rad(15), rad(s * -28), 0), seg=12)
        ball(f"Foot{s}", (s * 0.3, -0.34, 0.12), 0.22, GL, (1.0, 1.4, 0.6), seg=12)
        ball(f"Cheek{s}", (s * 0.5, -0.36, 1.2), 0.2, GL, (1, 0.7, 0.8), seg=10)
    eyes(1.42, -0.6, 0.3, 0.2, (0.36, 0.22, 0.10))
    smile(-0.7, 1.1, 0.13)
    blush(-0.62, 1.2, 0.5, 0.09)
    # the sprout: a curved stem and two veined leaves, one bigger
    chain("Stem", [(0, 0, 2.0), (0.02, 0, 2.22), (0.08, 0, 2.42), (0.16, 0, 2.56)], [0.09, 0.075, 0.06, 0.05], LEAF_D, seg=8)
    for s, ln, tilt in ((1, 0.78, 28), (-1, 0.56, 40)):
        base = (0.16, 0, 2.56)
        tip = (base[0] + s * ln, 0, base[2] + ln * math.tan(rad(tilt)) * 0.55)
        mid = tuple((base[i] + tip[i]) / 2 for i in range(3))
        leaf = ball(f"Leaf{s}", (mid[0], 0, mid[2] + 0.06), ln / 2, LEAF, (1.0, 0.62, 0.2), rot=(0, rad(-s * tilt * 0.55), 0), seg=16)
        limb(f"Vein{s}", (base[0], -0.01, base[2] + 0.03), (tip[0] * 0.92, -0.01, tip[2] + 0.07), 0.03, 0.012, LEAF_D, verts=6, end=False)
    # a tiny bud on the back and two leaf "wings"
    for s in (-1, 1):
        ball(f"BackLeaf{s}", (s * 0.42, 0.5, 0.8), 0.3, LEAF, (0.9, 0.3, 1.1), rot=(rad(-30), 0, rad(s * 30)), seg=12)
    S.finish("pet_leafling", out, triangles=5500)

elif kind == "stonepup":
    ST, ST_D, ST_L, MOSS, MOSS_L = (0.62, 0.61, 0.60), (0.44, 0.43, 0.44), (0.80, 0.79, 0.76), (0.36, 0.60, 0.26), (0.52, 0.76, 0.34)
    # a sitting puppy carved from boulders: blocky rounded shapes, floppy slab ears, moss patches, a wagging stub tail
    ball("Body", (0, 0.18, 0.7), 0.68, (0.9, 0.9, 0.92), (1.0, 1.05, 1.0), seg=14, key="stone", tile=2.6)
    ball("Chest", (0, -0.3, 0.72), 0.46, ST_L, (1.0, 0.7, 1.05), seg=12)
    for s in (-1, 1):
        ball(f"Haunch{s}", (s * 0.55, 0.3, 0.38), 0.42, (0.7, 0.7, 0.74), (0.9, 1.1, 0.95), seg=12, key="stone", tile=2.6)
        ball(f"BackPaw{s}", (s * 0.62, -0.18, 0.13), 0.22, ST_L, (1.0, 1.4, 0.6), seg=10)
        limb(f"FrontLeg{s}", (s * 0.3, -0.42, 0.75), (s * 0.3, -0.5, 0.2), 0.2, 0.17, ST_L, verts=10)
        ball(f"FrontPaw{s}", (s * 0.3, -0.6, 0.13), 0.21, ST_L, (1.0, 1.35, 0.62), seg=10)
        for k in (-1, 0, 1):
            ball(f"Toe{s}{k}", (s * 0.3 + k * 0.1, -0.84, 0.12), 0.055, ST_D, seg=6)
    ball("Head", (0, -0.22, 1.56), 0.66, (0.95, 0.95, 0.97), (1.1, 1.0, 0.95), seg=16, key="stone", tile=2.6)
    ball("Muzzle", (0, -0.74, 1.4), 0.3, ST_L, (1.15, 0.9, 0.78), seg=12)
    ball("Nose", (0, -1.0, 1.5), 0.1, (0.14, 0.12, 0.14), (1.2, 0.8, 0.8), seg=10)
    smile(-0.92, 1.28, 0.13)
    eyes(1.68, -0.72, 0.3, 0.2, (0.45, 0.28, 0.12))
    for s in (-1, 1):
        # floppy ears: slabs hanging down the side of the head
        ball(f"Ear{s}", (s * 0.72, -0.12, 1.55), 0.3, (0.62, 0.62, 0.68), (0.42, 0.9, 1.25), rot=(0, rad(s * 16), 0), seg=10, key="stone", tile=2.6)
        ball(f"Brow{s}", (s * 0.3, -0.62, 2.0), 0.12, ST_D, (1.5, 0.8, 0.5), rot=(0, rad(s * -12), 0), seg=8)
    # cracks: darker strips; moss on the head, back and one ear; a little flower
    for i, (a, b) in enumerate((((-0.3, -0.6, 2.05), (-0.05, -0.3, 2.18)), ((0.5, 0.5, 1.1), (0.25, 0.75, 0.8)), ((-0.6, 0.2, 0.9), (-0.45, 0.5, 0.6)))):
        limb(f"Crack{i}", a, b, 0.035, 0.02, ST_D, verts=5, end=False)
    for i, (p, r, sc) in enumerate((((0.12, -0.05, 2.14), 0.3, (1.3, 1.1, 0.4)), ((-0.2, 0.55, 1.28), 0.36, (1.2, 1.0, 0.45)),
                                    ((0.74, -0.1, 1.86), 0.16, (0.6, 1.0, 0.5)), ((0.3, 0.6, 1.2), 0.2, (1, 1, 0.5)))):
        ball(f"Moss{i}", p, r, MOSS if i % 2 == 0 else MOSS_L, sc, seg=10)
    for i in range(5):
        a = rad(i * 72)
        ball(f"Petal{i}", (0.3 + math.cos(a) * 0.08, 0.02 + math.sin(a) * 0.08, 2.28), 0.06, (1, 1, 1), (1, 1, 0.5), seg=6)
    ball("FlowerMid", (0.3, 0.02, 2.3), 0.05, (1.0, 0.8, 0.2), seg=6)
    limb("Tail", (0, 0.78, 0.6), (0.18, 1.1, 0.95), 0.16, 0.1, ST_D, verts=8)
    # a leather collar with a brass tag
    cyl("Collar", (0, -0.2, 1.08), 0.5, 0.12, (0.45, 0.26, 0.14), rot=(rad(12), 0, 0), verts=14)
    cyl("Tag", (0, -0.7, 0.98), 0.1, 0.03, (1.0, 0.76, 0.2), rot=(rad(90), 0, 0), verts=10)
    S.finish("pet_stonepup", out, triangles=6500)

elif kind == "mosskitten":
    FUR, FUR_L, STRIPE, MOSS, MOSS_L, PINK = (0.72, 0.58, 0.42), (0.96, 0.90, 0.78), (0.45, 0.33, 0.22), (0.38, 0.60, 0.28), (0.54, 0.76, 0.36), (0.98, 0.62, 0.68)
    # a fluffy sitting kitten with a moss cape over its back, a fluffy tail, tufted cheeks and a flower crown
    ball("Body", (0, 0.15, 0.62), 0.6, FUR, (1.0, 1.05, 1.05), seg=18)
    ball("Chest", (0, -0.34, 0.66), 0.4, FUR_L, (1.0, 0.7, 1.1), seg=14)
    for s in (-1, 1):
        ball(f"Haunch{s}", (s * 0.48, 0.25, 0.36), 0.38, FUR, (0.9, 1.1, 0.95), seg=12)
        limb(f"FrontLeg{s}", (s * 0.24, -0.4, 0.7), (s * 0.24, -0.46, 0.2), 0.16, 0.14, FUR_L, verts=8)
        ball(f"FrontPaw{s}", (s * 0.24, -0.54, 0.11), 0.17, FUR_L, (1.0, 1.3, 0.62), seg=10)
        ball(f"BackPaw{s}", (s * 0.55, -0.2, 0.11), 0.18, FUR_L, (1.0, 1.4, 0.6), seg=10)
    ball("Head", (0, -0.16, 1.46), 0.64, FUR, (1.12, 1.0, 0.95), seg=22)
    ball("Muzzle", (0, -0.66, 1.3), 0.26, FUR_L, (1.25, 0.8, 0.75), seg=12)
    ball("Nose", (0, -0.9, 1.36), 0.06, PINK, (1.3, 0.8, 0.8), seg=8)
    smile(-0.84, 1.2, 0.09)
    eyes(1.54, -0.66, 0.3, 0.2, (0.85, 0.55, 0.12))
    blush(-0.68, 1.3, 0.5, 0.08)
    for s in (-1, 1):
        # ears with pink insides and a tuft; cheek fluff; whiskers; forehead stripes
        cone(f"Ear{s}", (s * 0.42, -0.08, 2.08), 0.25, 0.5, FUR, (0, rad(s * 18), 0), verts=8, scale=(1, 0.6, 1))
        cone(f"EarIn{s}", (s * 0.42, -0.14, 2.04), 0.16, 0.36, PINK, (0, rad(s * 18), 0), verts=8, scale=(1, 0.5, 1))
        for k in range(3):
            cone(f"Fluff{s}{k}", (s * (0.66 + k * 0.02), -0.2, 1.3 - k * 0.14), 0.1, 0.3, FUR_L, (0, rad(s * (95 + k * 18)), 0), verts=6, scale=(1, 0.5, 1))
        for k in (-1, 1):
            limb(f"Whisker{s}{k}", (s * 0.2, -0.82, 1.3), (s * 0.62, -0.78, 1.3 + k * 0.1), 0.012, 0.006, (1, 1, 1), verts=4, end=False)
    for k in (-1, 0, 1):
        ball(f"Stripe{k}", (k * 0.16, -0.5, 2.0 - abs(k) * 0.05), 0.07, STRIPE, (0.5, 1, 1.6), rot=(rad(-30), 0, rad(k * -12)), seg=8)
    # moss cape: overlapping clumps over the shoulders and back
    for i, (p, r) in enumerate((((0, 0.5, 1.05), 0.42), ((-0.35, 0.4, 0.9), 0.3), ((0.35, 0.4, 0.9), 0.3), ((0, 0.72, 0.7), 0.36), ((-0.3, 0.1, 1.08), 0.2), ((0.3, 0.1, 1.08), 0.2))):
        ball(f"Moss{i}", p, r, MOSS if i % 2 == 0 else MOSS_L, (1.1, 1.0, 0.7), seg=10)
    # fluffy tail curling round to the front, mossy tip
    pts = S.arc((0.2, 0.5, 0.3), 0.62, 110, -40, 7, plane="xy")
    chain("Tail", [(p[0], p[1], 0.3 + i * 0.03) for i, p in enumerate(pts)], [0.2, 0.22, 0.23, 0.23, 0.22, 0.2, 0.16], FUR, seg=10)
    ball("TailTip", (pts[-1][0], pts[-1][1], 0.5), 0.19, MOSS_L, seg=10)
    # flower crown: three flowers between the ears
    for i, (x, col) in enumerate(((-0.16, (1, 1, 1)), (0.0, (1.0, 0.72, 0.8)), (0.16, (1, 1, 1)))):
        for k in range(5):
            a = rad(k * 72)
            ball(f"Petal{i}{k}", (x + math.cos(a) * 0.07, -0.34 + math.sin(a) * 0.02, 2.06 + math.sin(a) * 0.07), 0.05, col, (1, 0.5, 1), seg=6)
        ball(f"FlowerMid{i}", (x, -0.37, 2.06), 0.04, (1.0, 0.8, 0.2), seg=6)
    S.finish("pet_mosskitten", out, triangles=7000)

elif kind == "glowbug":
    BODY, BODY_L, STRIPE, WING, GLOW = (0.36, 0.24, 0.14), (0.62, 0.44, 0.24), (0.98, 0.78, 0.2), (0.86, 0.94, 1.0), (1.0, 0.86, 0.25)
    # a chubby firefly: fuzzy round head and body, a big glowing lantern tail, two pairs of glassy wings, curly feelers
    ball("Head", (0, -0.2, 1.3), 0.6, BODY, (1.08, 1.0, 0.98), seg=22)
    ball("Face", (0, -0.56, 1.2), 0.42, BODY_L, (1.1, 0.5, 0.9), seg=14)
    ball("Body", (0, 0.3, 0.85), 0.5, BODY, (1.0, 1.1, 0.95), seg=18)
    ball("Collar", (0, 0.05, 1.0), 0.46, STRIPE, (1.05, 0.5, 0.9), rot=(rad(20), 0, 0), seg=14)
    glow_ball("Lamp", (0, 0.95, 0.72), 0.52, GLOW, (1.0, 1.15, 1.0), seg=16)
    ball("LampCap", (0, 0.6, 0.8), 0.44, STRIPE, (1.05, 0.5, 1.0), rot=(rad(8), 0, 0), seg=14)
    eyes(1.36, -0.72, 0.28, 0.2, (0.85, 0.5, 0.1))
    smile(-0.8, 1.06, 0.1)
    blush(-0.72, 1.14, 0.46, 0.08)
    for s in (-1, 1):
        # wings: a big front pair and a small back pair, tilted up
        ball(f"WingA{s}", (s * 0.78, 0.25, 1.55), 0.55, WING, (1.0, 0.12, 0.5), rot=(rad(-10), rad(s * -32), rad(s * 22)), seg=14)
        ball(f"WingB{s}", (s * 0.62, 0.6, 1.25), 0.4, WING, (1.0, 0.12, 0.45), rot=(rad(-10), rad(s * -14), rad(s * 40)), seg=12)
        # feelers that curl outwards with a glowing bead
        pts = [(s * 0.18, -0.25, 1.82), (s * 0.3, -0.3, 2.1), (s * 0.48, -0.32, 2.24), (s * 0.64, -0.3, 2.2)]
        chain(f"Feeler{s}", pts, [0.045, 0.04, 0.035, 0.03], BODY, seg=6)
        glow_ball(f"FeelerTip{s}", pts[-1], 0.08, GLOW, seg=8)
        for k in range(3):  # six little legs tucked under
            limb(f"Leg{s}{k}", (s * 0.3, -0.1 + k * 0.3, 0.6), (s * 0.5, -0.2 + k * 0.32, 0.12), 0.05, 0.035, BODY, verts=6)
    S.finish("pet_glowbug", out, triangles=6000)

elif kind == "emberfox":
    FUR, FUR_D, WHITE_F, DARK, FLAME, FLAME_L = (1.0, 0.52, 0.14), (0.86, 0.36, 0.08), (1.0, 0.96, 0.88), (0.24, 0.13, 0.1), (1.0, 0.45, 0.08), (1.0, 0.82, 0.25)
    # a sitting fox cub: big pointed ears, white muzzle and chest, dark socks, and a big tail that ends in flames
    ball("Body", (0, 0.15, 0.62), 0.56, FUR, (1.0, 1.05, 1.08), seg=18)
    ball("Chest", (0, -0.3, 0.72), 0.4, WHITE_F, (0.95, 0.7, 1.15), seg=14)
    for k in range(3):
        cone(f"ChestTuft{k}", ((k - 1) * 0.16, -0.5, 0.5), 0.12, 0.3, WHITE_F, (rad(170), 0, rad((k - 1) * 14)), verts=6)
    for s in (-1, 1):
        ball(f"Haunch{s}", (s * 0.46, 0.25, 0.36), 0.36, FUR, (0.9, 1.1, 0.95), seg=12)
        limb(f"FrontLeg{s}", (s * 0.22, -0.4, 0.7), (s * 0.22, -0.46, 0.22), 0.15, 0.12, FUR, verts=10)
        ball(f"FrontPaw{s}", (s * 0.22, -0.54, 0.11), 0.16, DARK, (1.0, 1.3, 0.62), seg=10)
        ball(f"BackPaw{s}", (s * 0.52, -0.2, 0.11), 0.17, DARK, (1.0, 1.4, 0.6), seg=10)
    ball("Head", (0, -0.14, 1.44), 0.6, FUR, (1.12, 1.0, 0.93), seg=22)
    for s in (-1, 1):
        ball(f"CheekFur{s}", (s * 0.46, -0.3, 1.26), 0.3, WHITE_F, (1.0, 0.8, 0.8), seg=12)
        for k in range(2):
            cone(f"CheekTuft{s}{k}", (s * (0.72 + k * 0.03), -0.24, 1.2 - k * 0.16), 0.1, 0.3, WHITE_F, (0, rad(s * (100 + k * 20)), 0), verts=6, scale=(1, 0.5, 1))
        cone(f"Ear{s}", (s * 0.4, -0.02, 2.12), 0.27, 0.7, FUR, (0, rad(s * 14), 0), verts=8, scale=(1, 0.55, 1))
        cone(f"EarIn{s}", (s * 0.4, -0.09, 2.06), 0.17, 0.5, DARK, (0, rad(s * 14), 0), verts=8, scale=(1, 0.45, 1))
    cone("Snout", (0, -0.72, 1.28), 0.26, 0.42, WHITE_F, (rad(92), 0, 0), top=0.1, verts=12)
    ball("Nose", (0, -0.95, 1.31), 0.075, (0.1, 0.07, 0.08), (1.2, 0.9, 0.9), seg=8)
    smile(-0.78, 1.16, 0.09)
    eyes(1.54, -0.62, 0.28, 0.19, (0.95, 0.6, 0.1))
    blush(-0.62, 1.34, 0.5, 0.07)
    # the tail: a thick brush curling up behind, flames at the tip in three colours
    pts = [(0.25, 0.6, 0.35), (0.55, 0.85, 0.55), (0.78, 0.95, 0.95), (0.82, 0.9, 1.4), (0.7, 0.8, 1.8)]
    chain("Tail", pts, [0.22, 0.3, 0.34, 0.3, 0.2], FUR, seg=12)
    glow_ball("Flame1", (0.68, 0.78, 2.02), 0.26, FLAME, (1, 1, 1.5), seg=10)
    glow_ball("Flame2", (0.62, 0.74, 2.3), 0.16, FLAME_L, (1, 1, 1.7), seg=8)
    glow_ball("Flame3", (0.86, 0.84, 1.95), 0.13, FLAME_L, (1, 1, 1.6), seg=8)
    S.finish("pet_emberfox", out, triangles=7000)

elif kind == "crystalowl":
    FEA, FEA_L, CRY, CRY_L, BEAK = (0.56, 0.40, 0.30), (0.96, 0.92, 0.84), (0.45, 0.78, 1.0), (0.80, 0.94, 1.0), (1.0, 0.76, 0.24)
    # a round owl: heart-shaped face disc, huge eyes, crystal ear tufts and wing tips, a feathered chest
    ball("Body", (0, 0.05, 0.9), 0.8, FEA, (1.0, 0.95, 1.12), seg=22)
    ball("FaceDisc", (0, -0.5, 1.32), 0.62, FEA_L, (1.15, 0.45, 0.9), seg=18)
    ball("Chest", (0, -0.52, 0.66), 0.5, FEA_L, (1.0, 0.5, 1.0), seg=14)
    for r_i in range(3):  # rows of chest feathers
        for k in range(-1, 2):
            ball(f"Feather{r_i}{k}", (k * 0.22 + (0.11 if r_i % 2 else 0), -0.78 + r_i * 0.03, 0.9 - r_i * 0.22), 0.1, FEA, (1, 0.4, 1.2), seg=8)
    eyes(1.4, -0.76, 0.3, 0.25, (0.95, 0.66, 0.15))
    cone("Beak", (0, -0.98, 1.18), 0.1, 0.24, BEAK, (rad(125), 0, 0), verts=8)
    for s in (-1, 1):
        # folded wings with three crystal feathers at the tip
        ball(f"Wing{s}", (s * 0.78, 0.1, 0.9), 0.5, FEA, (0.4, 0.9, 1.25), rot=(0, rad(s * 10), 0), seg=14)
        for k in range(3):
            cone(f"WingCrystal{s}{k}", (s * (0.86 - k * 0.04), 0.0 + k * 0.16, 0.38 - k * 0.03), 0.09, 0.4, CRY if k % 2 else CRY_L, (rad(180), 0, rad(s * 8)), verts=6)
        # crystal ear tufts and little talons
        cone(f"Tuft{s}", (s * 0.46, -0.1, 2.0), 0.14, 0.55, CRY, (rad(-8), rad(s * 22), 0), verts=6)
        cone(f"Tuft2{s}", (s * 0.62, -0.08, 1.86), 0.1, 0.36, CRY_L, (rad(-8), rad(s * 38), 0), verts=6)
        for k in (-1, 0, 1):
            cone(f"Talon{s}{k}", (s * 0.3 + k * 0.1, -0.5, 0.08), 0.06, 0.24, BEAK, (rad(100), 0, 0), verts=6)
    glow_ball("Gem", (0, -0.9, 0.98), 0.1, (0.55, 0.9, 1.0), (1, 0.6, 1.2), seg=8)
    for i, a in enumerate((-30, 0, 30)):  # crystal tail
        cone(f"TailCrystal{i}", (math.sin(rad(a)) * 0.3, 0.75, 0.42), 0.1, 0.5, CRY if i % 2 else CRY_L, (rad(-115), 0, rad(-a)), verts=6)
    S.finish("pet_crystalowl", out, triangles=7000)

elif kind == "minigolem":
    R, R_D, R_L, CORE = (0.62, 0.46, 0.34), (0.44, 0.31, 0.24), (0.78, 0.62, 0.46), (1.0, 0.56, 0.12)
    # a little rock golem: boulder head and chest, big fists, short legs, a glowing core and lava cracks
    ball("Chest", (0, 0, 0.9), 0.62, (1, 1, 1), (1.1, 0.9, 1.0), seg=10, key="t_cliff", tile=2.2)
    ball("Hips", (0, 0, 0.42), 0.4, R_D, (1.1, 0.9, 0.8), seg=8)
    ball("Head", (0, -0.1, 1.66), 0.5, (1.15, 1.1, 1.05), (1.15, 1.0, 0.9), seg=10, key="t_cliff", tile=2.2)
    ball("Jaw", (0, -0.3, 1.38), 0.36, R, (1.1, 0.8, 0.5), seg=8)
    glow_ball("Core", (0, -0.5, 0.92), 0.2, CORE, (1.1, 0.5, 1.1), seg=10)
    for i, (a, b) in enumerate((((-0.14, -0.55, 1.08), (-0.4, -0.42, 1.3)), ((0.14, -0.55, 0.78), (0.42, -0.4, 0.6)), ((0.16, -0.55, 1.05), (0.36, -0.44, 1.26)))):
        o = limb(f"Crack{i}", a, b, 0.035, 0.015, CORE, verts=5, end=False)
        S.glow(o, CORE)
    eyes(1.72, -0.5, 0.2, 0.13, (1.0, 0.7, 0.2), pupil=False)
    smile(-0.56, 1.44, 0.09, open_=False)
    for s in (-1, 1):
        ball(f"Shoulder{s}", (s * 0.74, 0, 1.2), 0.3, R_D, (1.0, 1.0, 0.9), seg=8)
        limb(f"Arm{s}", (s * 0.8, -0.05, 1.1), (s * 0.92, -0.2, 0.6), 0.2, 0.22, R, verts=8, end=False)
        ball(f"Fist{s}", (s * 0.95, -0.25, 0.46), 0.33, (1.1, 1.05, 1.0), (1.0, 1.05, 0.95), seg=8, key="t_cliff", tile=1.6)
        ball(f"Leg{s}", (s * 0.32, 0, 0.2), 0.26, R, (1.0, 1.15, 0.85), seg=8)
        ball(f"Brow{s}", (s * 0.22, -0.46, 1.9), 0.13, R_D, (1.5, 0.8, 0.45), rot=(0, rad(s * 14), 0), seg=6)
    for i, (p, r) in enumerate((((0.25, 0.1, 2.08), 0.2), ((-0.2, 0.2, 2.1), 0.15), ((0.0, 0.5, 1.45), 0.26), ((-0.5, 0.35, 1.0), 0.2))):
        ball(f"Rock{i}", p, r, R_D if i % 2 else R_L, (1, 1, 0.8), seg=6)
    ball("Moss", (0.1, 0.2, 2.16), 0.2, (0.38, 0.6, 0.28), (1.3, 1.1, 0.4), seg=8)
    S.finish("pet_minigolem", out, triangles=5500)

elif kind == "starunicorn":
    COAT, SHADE, HOOF, HORN = (1.0, 0.98, 1.0), (0.90, 0.86, 0.96), (1.0, 0.82, 0.3), (1.0, 0.84, 0.3)
    MANE = [(1.0, 0.55, 0.72), (1.0, 0.8, 0.45), (0.6, 0.9, 0.62), (0.5, 0.75, 1.0), (0.76, 0.58, 1.0)]
    # a chubby standing baby unicorn: big head, golden spiral horn, rainbow mane and tail, golden hooves, a star mark
    ball("Body", (0, 0.2, 0.86), 0.62, COAT, (0.95, 1.25, 0.95), seg=20)
    for s in (-1, 1):
        for k, y in enumerate((-0.25, 0.62)):
            limb(f"Leg{s}{k}", (s * 0.3, y, 0.7), (s * 0.3, y - 0.02, 0.2), 0.19, 0.16, COAT, verts=10)
            cyl(f"Hoof{s}{k}", (s * 0.3, y - 0.02, 0.1), 0.19, 0.2, HOOF, verts=10)
    ball("Neck", (0, -0.36, 1.3), 0.4, COAT, (0.9, 0.9, 1.2), rot=(rad(-25), 0, 0), seg=14)
    ball("Head", (0, -0.6, 1.78), 0.58, COAT, (1.05, 1.05, 0.96), seg=22)
    ball("Muzzle", (0, -1.08, 1.6), 0.3, SHADE, (1.1, 1.0, 0.82), seg=14)
    for s in (-1, 1):
        ball(f"Nostril{s}", (s * 0.11, -1.34, 1.64), 0.035, (0.85, 0.6, 0.7), seg=6)
        cone(f"Ear{s}", (s * 0.36, -0.42, 2.32), 0.15, 0.4, COAT, (rad(-10), rad(s * 22), 0), verts=8, scale=(1, 0.6, 1))
        cone(f"EarIn{s}", (s * 0.36, -0.47, 2.3), 0.09, 0.28, MANE[0], (rad(-10), rad(s * 22), 0), verts=8, scale=(1, 0.5, 1))
    smile(-1.22, 1.46, 0.08, open_=False)
    eyes(1.86, -1.02, 0.3, 0.19, (0.6, 0.35, 0.95))
    blush(-1.02, 1.62, 0.44, 0.08)
    # the horn: a spiral of stacked rings, glowing at the tip
    for i in range(7):
        t = i / 6
        ball(f"Horn{i}", (0, -0.86 - t * 0.1, 2.3 + t * 0.62), 0.14 - t * 0.1, HORN, (1, 1, 0.75), rot=(rad(-12), rad(20), 0), seg=8)
    glow_ball("HornTip", (0, -0.97, 2.98), 0.06, (1.0, 0.95, 0.6), seg=8)
    # mane: rainbow locks from the forehead down the neck; tail: five rainbow strands
    for i in range(7):
        t = i / 6
        ball(f"Mane{i}", (0.06 * math.sin(i), -0.52 + t * 0.62, 2.3 - t * 1.0), 0.26 - t * 0.06, MANE[i % 5], (0.75, 1.0, 1.0), seg=10)
    ball("Fringe", (0.14, -0.86, 2.2), 0.2, MANE[0], (1, 0.8, 0.8), seg=10)
    for i in range(5):
        a = rad(-40 + i * 20)
        chain(f"Tail{i}", [(math.sin(a) * 0.1, 0.92, 0.95), (math.sin(a) * 0.3, 1.25, 0.8), (math.sin(a) * 0.42, 1.38, 0.42)], [0.13, 0.12, 0.06], MANE[i], seg=8)
    # a golden star on each flank
    for s in (-1, 1):
        for k in range(5):
            a = rad(k * 72 + 90)
            ball(f"Star{s}{k}", (s * 0.6, 0.45 + math.cos(a) * 0.1, 0.95 + math.sin(a) * 0.1), 0.06, HORN, (0.5, 1, 1), seg=6)
        ball(f"StarMid{s}", (s * 0.6, 0.45, 0.95), 0.09, HORN, (0.5, 1, 1), seg=8)
    S.finish("pet_starunicorn", out, triangles=7500)

elif kind == "phoenix":
    RED, ORANGE, GOLD, YELLOW, BEAK = (0.92, 0.18, 0.08), (1.0, 0.48, 0.08), (1.0, 0.74, 0.14), (1.0, 0.92, 0.4), (1.0, 0.8, 0.2)
    # a fiery chick: round red body, golden belly, a flame crest, flame wings held open and a long flame tail
    ball("Body", (0, 0.05, 0.9), 0.66, RED, (1.0, 1.0, 1.08), seg=20)
    ball("Belly", (0, -0.42, 0.78), 0.46, GOLD, (1.0, 0.5, 1.05), seg=14)
    ball("Head", (0, -0.12, 1.66), 0.52, RED, (1.06, 1.0, 0.98), seg=20)
    ball("Face", (0, -0.42, 1.58), 0.36, ORANGE, (1.1, 0.5, 0.9), seg=12)
    eyes(1.72, -0.58, 0.24, 0.17, (0.95, 0.55, 0.1))
    cone("Beak", (0, -0.74, 1.52), 0.11, 0.26, BEAK, (rad(100), 0, 0), verts=8)
    blush(-0.56, 1.52, 0.4, 0.07, (1.0, 0.8, 0.3))
    for i, (x, h, col) in enumerate(((0, 0.7, YELLOW), (-0.2, 0.5, GOLD), (0.2, 0.5, GOLD), (-0.36, 0.34, ORANGE), (0.36, 0.34, ORANGE))):
        o = S.cone(f"Crest{i}", (x, 0.0, 2.16 + h / 2 - abs(x) * 0.3), 0.13, h, col, (rad(-14), rad(x * -60), 0), verts=6, scale=(1, 0.5, 1))
        S.glow(o, col)
    for s in (-1, 1):
        # wings: three flame feathers each, fanning up and out
        for k, (ln, ang, col) in enumerate(((1.0, 35, YELLOW), (0.9, 8, GOLD), (0.72, -20, ORANGE))):
            a = rad(ang)
            mid = (s * (0.6 + math.cos(a) * ln / 2), 0.2, 1.0 + math.sin(a) * ln / 2)
            o = S._sphere(f"WingFlame{s}{k}", mid, ln / 2, (1.0, 0.14, 0.34), (0, -a * s, 0), 12)
            S.glow(o, col)
        ball(f"WingBase{s}", (s * 0.62, 0.12, 1.0), 0.26, RED, (0.8, 0.8, 1.1), seg=10)
        for k in (-1, 0, 1):
            cone(f"Talon{s}{k}", (s * 0.26 + k * 0.09, -0.34, 0.1), 0.055, 0.26, BEAK, (rad(105), 0, 0), verts=6)
        limb(f"Leg{s}", (s * 0.26, -0.1, 0.4), (s * 0.26, -0.14, 0.14), 0.07, 0.06, BEAK, verts=6)
    for i, (x, ln, col) in enumerate(((0, 1.5, YELLOW), (-0.26, 1.15, GOLD), (0.26, 1.15, GOLD), (-0.46, 0.8, ORANGE), (0.46, 0.8, ORANGE))):
        pts = [(x * 0.5, 0.6, 0.7), (x * 0.9, 0.6 + ln * 0.5, 0.8 + ln * 0.2), (x * 1.3, 0.6 + ln * 0.8, 1.0 + ln * 0.55)]
        for j in range(2):
            o = S.limb(f"TailFlame{i}{j}", pts[j], pts[j + 1], 0.16 - j * 0.07, 0.09 - j * 0.07, col, verts=6, end=False)
            S.glow(o, col)
    S.finish("pet_phoenix", out, triangles=6500)

elif kind == "voiddrake":
    V, V_D, V_L, STAR, HORN = (0.16, 0.10, 0.32), (0.09, 0.05, 0.2), (0.32, 0.2, 0.56), (0.8, 0.6, 1.0), (0.62, 0.42, 0.95)
    # the dark twin of the Baby Dragon: slimmer, standing on four legs, big star-speckled wings, glowing eyes and horns
    ball("Body", (0, 0.2, 0.86), 0.56, V, (0.95, 1.3, 0.92), seg=20)
    ball("Belly", (0, 0.12, 0.66), 0.46, V_L, (0.8, 1.2, 0.6), seg=14)
    for s in (-1, 1):
        for k, y in enumerate((-0.28, 0.66)):
            limb(f"Leg{s}{k}", (s * 0.34, y, 0.72), (s * 0.36, y - 0.04, 0.18), 0.18, 0.14, V, verts=10)
            ball(f"Foot{s}{k}", (s * 0.36, y - 0.14, 0.1), 0.17, V_L, (1.0, 1.35, 0.6), seg=10)
            for t in (-1, 0, 1):
                cone(f"Claw{s}{k}{t}", (s * 0.36 + t * 0.09, y - 0.38, 0.08), 0.045, 0.16, STAR, (rad(100), 0, 0), verts=6)
    chain("Neck", [(0, -0.3, 1.05), (0, -0.52, 1.4), (0, -0.6, 1.72)], [0.36, 0.3, 0.28], V, seg=12)
    HZ = 1.9
    ball("Head", (0, -0.66, HZ), 0.52, V, (1.05, 1.1, 0.92), seg=22)
    ball("Snout", (0, -1.16, HZ - 0.12), 0.28, V_L, (1.05, 1.1, 0.72), seg=14)
    for s in (-1, 1):
        ball(f"Nostril{s}", (s * 0.1, -1.42, HZ - 0.06), 0.03, V_D, seg=6)
        cone(f"Fang{s}", (s * 0.14, -1.3, HZ - 0.3), 0.035, 0.1, (1, 1, 1), (rad(180), 0, 0), verts=6)
        # glowing eyes with a slit pupil
        glow_ball(f"Eye{s}", (s * 0.28, -1.02, HZ + 0.1), 0.16, STAR, (1.0, 0.4, 1.2), rot=(0, 0, rad(s * 14)), seg=12)
        ball(f"Slit{s}", (s * 0.29, -1.09, HZ + 0.1), 0.1, (0.04, 0.02, 0.08), (0.3, 0.3, 1.3), seg=8)
        ball(f"EyeShine{s}", (s * 0.24, -1.1, HZ + 0.18), 0.04, (1, 1, 1), seg=6)
        # horns: swept back
        pts = [(s * 0.3, -0.4, HZ + 0.36), (s * 0.4, -0.18, HZ + 0.62), (s * 0.5, 0.08, HZ + 0.8), (s * 0.56, 0.36, HZ + 0.86)]
        chain(f"Horn{s}", pts, [0.13, 0.1, 0.07, 0.03], HORN, seg=8)
        for k in range(3):
            cone(f"Fin{s}{k}", (s * (0.52 + k * 0.02), -0.5, HZ - 0.05 - k * 0.16), 0.09, 0.28 - k * 0.04, V_D, (0, rad(s * (80 + k * 14)), 0), verts=6, scale=(1, 0.5, 1))
        # big wings with stars on the skin
        root, elbow = (s * 0.36, 0.3, 1.3), (s * 0.95, 0.42, 2.05)
        tips = [(s * 1.55, 0.5, 2.5), (s * 2.05, 0.6, 1.8), (s * 1.8, 0.56, 1.05)]
        S.bat_wing(s, root, elbow, tips, V_D, V_L, bone_r=0.07)
        for i, (x, z, r) in enumerate(((1.2, 2.0, 0.05), (1.5, 1.7, 0.035), (1.3, 1.45, 0.045), (1.65, 2.05, 0.03), (1.0, 1.6, 0.03))):
            glow_ball(f"WingStar{s}{i}", (s * x, 0.46, z), r, STAR, seg=6)
    for i, (y, z, h, ang) in enumerate(((-0.5, HZ + 0.5, 0.3, 10), (-0.2, HZ + 0.4, 0.3, 40), (0.0, 1.6, 0.28, 60), (0.3, 1.42, 0.26, 20), (0.6, 1.38, 0.24, 20), (0.9, 1.2, 0.2, 40))):
        cone(f"Spike{i}", (0, y, z), 0.1, h, V_D, (rad(-ang), 0, 0), verts=6, scale=(0.5, 1, 1))
    pts = [(0, 0.9, 0.9), (0.1, 1.3, 0.7), (0.3, 1.6, 0.45), (0.62, 1.75, 0.3), (0.95, 1.7, 0.3)]
    chain("Tail", pts, [0.3, 0.22, 0.16, 0.1, 0.06], V, seg=10)
    glow_ball("TailTip", (1.1, 1.66, 0.32), 0.12, STAR, (1.4, 0.8, 0.8), seg=8)
    for i, (x, y, z) in enumerate(((0.3, 0.3, 1.36), (-0.25, 0.6, 1.3), (0.4, -0.1, 1.2), (-0.42, 0.1, 1.15), (0.15, -0.6, 2.36))):
        glow_ball(f"BodyStar{i}", (x, y, z), 0.035, STAR, seg=6)
    S.finish("pet_voiddrake", out, triangles=8000)

else:
    raise SystemExit("unknown pet kind: " + kind)
