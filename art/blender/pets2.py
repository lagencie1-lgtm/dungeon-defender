"""The pets, second generation: built with petkit (one smooth skin, painted faces and markings, gradients).
Each pet is matched to its target picture in art/ref3d/batch2/pet_<kind>.png. Front faces -Y, about 2.2 tall.
Run: blender -b -P pets2.py -- out.fbx <kind>      (scripts/pet_cycle.sh builds, renders and scores it)
"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import petkit as K  # noqa: E402
from petkit import ball, cone, limb, chain, patch, rad, rope  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, kind = args[0], args[1]
K.start()

AMBER, AMBER_D = (0.98, 0.62, 0.12), (0.34, 0.15, 0.05)

if kind == "emberfox":
    FUR, FUR_D, CREAM, CREAM_D, SOCK = (0.98, 0.50, 0.13), (0.82, 0.31, 0.07), (1.0, 0.93, 0.80), (0.93, 0.78, 0.60), (0.33, 0.17, 0.10)
    FL_R, FL_O, FL_Y = (0.96, 0.26, 0.06), (1.0, 0.55, 0.08), (1.0, 0.90, 0.32)
    # sitting cub: pear body, big head, huge ears, fluffy chest and cheeks, brush tail with a flame tip
    body = ball("Body", (0, 0.2, 0.60), 0.56, FUR_D, (0.98, 1.06, 1.08), color2=FUR)
    for s in (-1, 1):
        ball(f"Haunch{s}", (s * 0.44, 0.22, 0.36), 0.38, FUR_D, (0.92, 1.12, 0.95), color2=FUR)
        ball(f"BackPaw{s}", (s * 0.56, -0.22, 0.13), 0.19, SOCK, (1.0, 1.45, 0.68))
        limb(f"FrontLeg{s}", (s * 0.21, -0.36, 0.78), (s * 0.22, -0.46, 0.2), 0.17, 0.15, FUR, color2=SOCK, cap=False)
        ball(f"FrontPaw{s}", (s * 0.22, -0.56, 0.13), 0.19, SOCK, (1.0, 1.35, 0.7))
    # chest fluff: a cream bib of three fat rounded locks
    ball("Chest", (0, -0.27, 0.86), 0.36, CREAM_D, (1.05, 0.72, 0.95), color2=CREAM)
    for i, (x, z, a, h) in enumerate(((-0.2, 0.7, -20, 0.36), (0, 0.6, 0, 0.44), (0.2, 0.7, 20, 0.36))):
        cone(f"ChestLock{i}", (x, -0.5, z), 0.17, h, CREAM_D, (rad(168), rad(a), 0), top=0.03, scale=(1, 0.75, 1), color2=CREAM)
    head = ball("Head", (0, -0.12, 1.52), 0.66, FUR_D, (1.16, 1.0, 0.93), color2=FUR)
    # cream lower cheeks and fluffy cheek locks pointing out and down
    for s in (-1, 1):
        patch(head, (s * 0.7, -1, -0.62), 0.34, CREAM, (1.1, 0.8), roll=s * 20, lift=0.012, name="CheekPaint")
        for k, (dz, ang, ln, r) in enumerate(((0.0, 100, 0.5, 0.2), (-0.2, 128, 0.44, 0.18))):
            cone(f"Cheek{s}{k}", (s * 0.74, -0.24, 1.3 + dz), r, ln, CREAM, (0, rad(s * ang), 0), top=0.05, scale=(1, 0.8, 1))
    muzzle = ball("Muzzle", (0, -0.66, 1.33), 0.27, CREAM, (1.25, 0.95, 0.8))
    ball("Nose", (0, -0.925, 1.43), 0.075, K.INK, (1.3, 0.8, 0.8), role="hard", seg=12, lit=False)
    K.smile(muzzle, -0.42, 0.16, skin=CREAM)
    K.eyes(head, 0.46, 0.16, 0.215, iris=AMBER, iris_dark=AMBER_D)
    K.blush(head, 0.86, -0.2, 0.09)
    for s in (-1, 1):
        cone(f"Ear{s}", (s * 0.5, 0.02, 2.24), 0.36, 0.98, FUR, (rad(-4), rad(s * 20), 0), top=0.02, scale=(1, 0.5, 1), color2=SOCK)
        cone(f"EarIn{s}", (s * 0.49, -0.06, 2.16), 0.24, 0.68, CREAM, (rad(-4), rad(s * 20), 0), scale=(1, 0.75, 1), role="mark", color2=CREAM_D)
    for i, (x, a, h) in enumerate(((-0.16, -22, 0.3), (0.02, 0, 0.4), (0.19, 24, 0.3))):
        cone(f"Tuft{i}", (x, -0.34, 2.12), 0.15, h, FUR, (rad(30), rad(a), 0), top=0.02, scale=(1, 0.7, 1))
    # tail: a fat teardrop brush curling up beside the body, cream band, then the flame as its tip
    pts = [(0.28, 0.6, 0.3), (0.7, 0.78, 0.4), (1.04, 0.8, 0.82), (1.08, 0.72, 1.36), (0.98, 0.66, 1.72)]
    K.rope("Tail", pts, [0.16, 0.34, 0.47, 0.42, 0.28], FUR_D, FUR)
    ball("TailBand", (0.97, 0.65, 1.8), 0.27, CREAM, (1.05, 1.0, 0.8))
    ball("FlameBase", (0.95, 0.64, 1.96), 0.22, FL_O, (1.0, 0.9, 0.9), color2=FL_Y)
    for i, (x, z, r, h, ay) in enumerate(((0.93, 2.3, 0.2, 0.74, -10), (1.14, 2.1, 0.13, 0.46, 28), (0.74, 2.12, 0.12, 0.42, -32))):
        cone(f"Flame{i}", (x, 0.64, z), r, h, FL_O, (0, rad(ay), 0), top=0.015, scale=(1, 0.75, 1), color2=FL_Y)
    ball("FlameGlow", (0.94, 0.52, 2.12), 0.09, FL_Y, (1, 0.5, 1.6), role="glow", seg=10)
    K.finish("pet_emberfox", out, triangles=7500)

elif kind == "slimey":
    G, G_D, G_L, G_HI = (0.47, 0.80, 0.20), (0.22, 0.56, 0.10), (0.70, 0.93, 0.36), (0.93, 1.0, 0.75)
    BROWN, BROWN_D = (0.74, 0.44, 0.12), (0.30, 0.14, 0.05)
    # a fat jelly drop: wide flat base, the top pulled into a soft curl leaning to one side
    body = ball("Body", (0, 0, 0.86), 1.0, G_D, (1.18, 1.04, 0.86), color2=G, seg=48)
    ball("Foot", (0, 0, 0.3), 1.0, G_D, (1.14, 1.0, 0.3), seg=48)
    rope("Curl", [(0.0, 0, 1.3), (0.1, 0, 1.7), (0.34, 0, 2.0), (0.66, 0, 2.08), (0.88, 0, 1.94)], [0.7, 0.46, 0.3, 0.2, 0.14], G, n=30)
    # jelly lights: a soft shine top-left, a small one, lighter spots low on the cheeks
    patch(body, (-0.7, -1, 0.72), 0.24, G_HI, (1.5, 0.55), roll=-34, lift=0.02, name="Shine", lit=False)
    patch(body, (-1.02, -1, 0.42), 0.08, G_HI, (1.0, 1.0), lift=0.02, name="Shine2", lit=False)
    for s in (-1, 1):
        patch(body, (s * 0.8, -1, -0.3), 0.17, G_L, (1.35, 0.7), roll=s * 12, lift=0.014, name="CheekSpot")
    K.eyes(body, 0.4, 0.22, 0.25, iris=BROWN, iris_dark=BROWN_D, tall=1.22)
    K.smile(body, -0.2, 0.22, skin=G, tongue=(0.98, 0.52, 0.46), inside=(0.48, 0.14, 0.10))
    K.finish("pet_slimey", out, triangles=5000, melt=10)

elif kind == "leafling":
    G, G_D, G_L, CREAM, CREAM_D = (0.60, 0.80, 0.26), (0.36, 0.60, 0.14), (0.78, 0.90, 0.42), (0.98, 0.95, 0.74), (0.90, 0.82, 0.52)
    LEAF, LEAF_D, LEAF_L = (0.38, 0.72, 0.20), (0.20, 0.50, 0.12), (0.62, 0.88, 0.30)
    # a round seedling: one egg for head and body, cream tummy, stub arms and feet, a big leaf on a bent stalk
    body = ball("Body", (0, 0, 0.98), 0.9, G_D, (1.06, 0.98, 1.0), color2=G, seg=48)
    patch(body, (0, -1, -0.62), 0.5, CREAM, (1.15, 0.8), lift=0.012, name="Tummy", color2=CREAM_D, axis="Y")
    for s in (-1, 1):
        ball(f"Arm{s}", (s * 0.9, -0.2, 0.78), 0.22, G_D, (0.95, 1.0, 1.25), rot=(rad(10), rad(s * -30), 0), color2=G)
        ball(f"Foot{s}", (s * 0.4, -0.3, 0.14), 0.27, G_D, (1.05, 1.4, 0.62), color2=G)
        patch(body, (s * 0.92, -1, -0.02), 0.13, (1.0, 0.72, 0.36), (1.25, 0.8), lift=0.014, name="Blush")
    # leafy fringe: a few fat rounded leaf tips over the forehead and the back of the head
    for i, (x, y, z, a) in enumerate(((-0.42, -0.5, 1.66, -30), (0.0, -0.62, 1.74, 0), (0.42, -0.5, 1.66, 30), (-0.6, 0.2, 1.6, -50), (0.6, 0.2, 1.6, 50), (0, 0.6, 1.62, 0))):
        cone(f"Fringe{i}", (x, y, z), 0.26, 0.4, LEAF, (rad(150 if y < 0 else -150), rad(a), 0), top=0.05, scale=(1, 0.5, 1), color2=LEAF_L)
    ball("Cap", (0, 0, 1.72), 0.52, LEAF, (1.2, 1.1, 0.5), color2=LEAF_L)
    K.eyes(body, 0.42, 0.22, 0.21, iris=(0.76, 0.52, 0.12), iris_dark=(0.30, 0.16, 0.05), tall=1.2)
    K.smile(body, -0.12, 0.15, skin=G, tongue=(0.98, 0.52, 0.46))
    rope("Stalk", [(0, 0, 1.9), (-0.04, 0, 2.2), (0.06, 0, 2.46), (0.26, 0, 2.6)], [0.13, 0.1, 0.085, 0.07], LEAF_D, LEAF, n=12)
    K.leaf("Leaf", (0.2, 0, 2.56), (1.5, -0.1, 2.9), 0.52, LEAF, LEAF_L, thick=0.1, bend=-0.14, up=(0, 1, 0))
    K.finish("pet_leafling", out, triangles=5500)

else:
    raise SystemExit("unknown pet kind: " + kind)
