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


def sparkle(name, pos, R, color=(1.0, 0.93, 0.62)):
    """A small four-point star that floats beside the pet and glows. ONLY the three rarest pets carry them (their
    target pictures show them): it is the sign of a rare pet, so never add it to a common one (the outside judge:
    "a basic slime and a legendary dragon share the same look"). Two crossed blades: a star from every side."""
    x, y, z = pos
    for tag, ax in (("", (1, 0)), ("b", (0, 1))):
        pts = [pos]
        for a in range(8):
            r = R if a % 2 == 0 else R * 0.34
            d, dz = math.cos(rad(a * 45 + 90)) * r * 0.78, math.sin(rad(a * 45 + 90)) * r
            pts.append((x + d * ax[0], y + d * ax[1], z + dz))
        K.sheet(name + tag, pts, [(0, i, i % 8 + 1) for i in range(1, 9)], color, R * 0.3, role="glow")

if kind == "emberfox":
    FUR, FUR_D, CREAM, CREAM_D, SOCK = (0.98, 0.50, 0.13), (0.84, 0.33, 0.07), (1.0, 0.93, 0.80), (0.93, 0.78, 0.60), (0.33, 0.17, 0.10)
    FL_R, FL_O, FL_Y = (0.96, 0.26, 0.06), (1.0, 0.55, 0.08), (1.0, 0.90, 0.32)
    # Sculpted against the blueprint art/ref3d/turn/emberfox.png (front, side, back). A sitting cub: the head is as
    # tall as the body, skull wider than deep, a short pointed muzzle set low, a cream cheek ruff sweeping out and
    # back, fat ears set on the back half of the skull with pressed-in hollows, a bib of chest fluff, a brush tail
    # behind its left side ending in the flame.
    body = ball("Body", (0, 0.22, 0.60), 0.5, FUR_D, (1.0, 1.15, 1.1), color2=FUR, k=0.14)
    for s in (-1, 1):
        ball(f"Haunch{s}", (s * 0.44, 0.28, 0.36), 0.36, FUR_D, (0.95, 1.12, 0.98), color2=FUR, k=0.12)
        ball(f"BackPaw{s}", (s * 0.54, -0.2, 0.13), 0.2, SOCK, (1.0, 1.4, 0.68), k=0.05)
        limb(f"FrontLeg{s}", (s * 0.21, -0.28, 0.82), (s * 0.21, -0.4, 0.24), 0.2, 0.18, FUR, color2=SOCK, k=0.08)
        ball(f"FrontPaw{s}", (s * 0.21, -0.5, 0.13), 0.2, SOCK, (1.0, 1.3, 0.7), k=0.05)
    # chest fluff: a cream bib of three locks
    ball("Bib", (0, -0.3, 0.98), 0.34, CREAM_D, (1.2, 0.72, 0.9), color2=CREAM, k=0.1)
    for i, (x, tipz, r) in enumerate(((0, 0.46, 0.2), (-0.24, 0.62, 0.16), (0.24, 0.62, 0.16))):
        limb(f"BibLock{i}", (x * 0.6, -0.4, 0.92), (x, -0.5, tipz), r, 0.035, CREAM, color2=CREAM_D, k=0.06)
    # head
    HZ = 1.63
    head = K.head("Head", (0, 0.0, HZ), 0.52, FUR_D, FUR, wide=1.2, cheeks=0.56, cheek_drop=0.42, jaw=0.0, brow=0.0, back=0.2)
    ball("Chin", (0, -0.24, HZ - 0.36), 0.26, CREAM, (1.3, 1.0, 0.66), k=0.14)
    for s in (-1, 1):
        # cheek ruff: a broad cream fluff hugging the cheek, pointing out and down, ending in two soft tips
        ball(f"Ruff{s}", (s * 0.5, -0.04, HZ - 0.3), 0.3, CREAM, (1.25, 0.95, 0.8), rot=(0, rad(s * 24), 0), color2=CREAM_D, axis="X" if s > 0 else "Z", k=0.14)
        limb(f"RuffTipA{s}", (s * 0.66, 0.0, HZ - 0.3), (s * 0.94, 0.06, HZ - 0.36), 0.15, 0.03, CREAM, k=0.07)
        limb(f"RuffTipB{s}", (s * 0.56, 0.0, HZ - 0.44), (s * 0.76, 0.04, HZ - 0.62), 0.14, 0.03, CREAM, k=0.07)
        # ears: broad, fat and round-tipped, on the back half of the skull; dark tips; a cream hollow pressed in
        cone(f"Ear{s}", (s * 0.5, 0.1, HZ + 0.64), 0.36, 0.8, FUR, (rad(8), rad(s * 20), 0), top=0.13, scale=(1.1, 0.6, 1), color2=SOCK, k=0.08)
        cone(f"EarHollow{s}", (s * 0.54, -0.13, HZ + 0.76), 0.25, 0.5, CREAM, (rad(8), rad(s * 20), 0), top=0.08, scale=(1, 0.5, 1), role="cut", k=0.05)
    # the muzzle: short, pointed, low on the face
    muzzle = ball("Muzzle", (0, -0.45, HZ - 0.24), 0.23, CREAM, (1.25, 1.1, 0.82), k=0.14)
    ball("MuzzleTip", (0, -0.62, HZ - 0.2), 0.11, CREAM, (1.1, 1.0, 0.9), k=0.1)
    ball("Nose", (0, -0.725, HZ - 0.15), 0.055, K.INK, (1.3, 0.85, 0.85), role="hard", seg=14, lit=False)
    K.smile(muzzle, -0.72, 0.11, skin=CREAM)
    K.eyes(head, 0.64, -0.06, 0.155, iris=AMBER, iris_dark=AMBER_D, tall=1.28, socket=0.045)
    K.blush(head, 1.0, -0.5, 0.07)
    # forehead tuft: one fat lock curling over to its left, two small ones beside it
    rope("Tuft", [(0, -0.2, HZ + 0.4), (0.04, -0.3, HZ + 0.62), (0.2, -0.34, HZ + 0.72), (0.36, -0.3, HZ + 0.62)], [0.18, 0.16, 0.11, 0.04], FUR, FUR_D, n=12, k=0.06)
    limb("TuftB", (-0.12, -0.24, HZ + 0.4), (-0.22, -0.34, HZ + 0.62), 0.12, 0.03, FUR, k=0.06)
    limb("TuftC", (0.2, -0.22, HZ + 0.38), (0.4, -0.3, HZ + 0.48), 0.1, 0.03, FUR, k=0.06)
    # tail: a brush behind its left side, cream band, then the flame curling as its tip
    pts = [(0.15, 0.62, 0.3), (0.5, 0.95, 0.36), (0.86, 1.05, 0.72), (0.94, 1.0, 1.1), (0.86, 0.95, 1.38)]
    rope("Tail", pts, [0.15, 0.28, 0.37, 0.34, 0.25], FUR_D, FUR)
    ball("TailBand", (0.84, 0.94, 1.5), 0.24, CREAM, (1.05, 1.0, 0.8), k=0.08)
    rope("Flame", [(0.82, 0.94, 1.62), (0.94, 0.94, 1.92), (0.8, 0.94, 2.16), (0.64, 0.94, 2.32)], [0.24, 0.21, 0.13, 0.03], FL_O, FL_Y, n=12, k=0.06)
    limb("FlameB", (0.94, 0.94, 1.66), (1.12, 0.94, 1.96), 0.13, 0.025, FL_O, color2=FL_Y, k=0.06)
    limb("FlameC", (0.7, 0.94, 1.66), (0.56, 0.94, 1.9), 0.11, 0.025, FL_O, color2=FL_Y, k=0.06)
    ball("FlameGlow", (0.82, 0.8, 1.8), 0.07, FL_Y, (1, 0.5, 1.6), role="glow", seg=10)
    K.finish("pet_emberfox", out, triangles=8000)

elif kind == "slimey":
    G, G_D, G_L, G_HI = (0.47, 0.80, 0.20), (0.22, 0.56, 0.10), (0.70, 0.93, 0.36), (0.93, 1.0, 0.75)
    BROWN, BROWN_D = (0.74, 0.44, 0.12), (0.30, 0.14, 0.05)
    # Sculpted against art/ref3d/turn/slimey.png. One fat drop of jelly: wide and low, the top pulled up into a
    # soft curl that tips over to its left. Everything melts into a single volume (large k).
    body = ball("Body", (0, 0, 0.8), 1.0, G_D, (1.26, 1.06, 0.8), color2=G, k=0.3)
    ball("Foot", (0, 0, 0.26), 1.0, G_D, (1.3, 1.1, 0.26), k=0.2)
    rope("Curl", [(0.0, 0, 1.2), (0.08, 0, 1.56), (0.28, 0, 1.84), (0.56, 0, 1.92), (0.74, 0, 1.8)], [0.62, 0.42, 0.27, 0.18, 0.12], G, G_L, n=24, k=0.25)
    # jelly lights: a soft shine top-left, a small one, lighter spots low on the cheeks
    patch(body, (-0.7, -1, 0.72), 0.24, G_HI, (1.5, 0.55), roll=-34, lift=0.02, name="Shine", lit=False)
    patch(body, (-1.02, -1, 0.42), 0.08, G_HI, (1.0, 1.0), lift=0.02, name="Shine2", lit=False)
    for s in (-1, 1):
        patch(body, (s * 0.8, -1, -0.3), 0.17, G_L, (1.35, 0.7), roll=s * 12, lift=0.014, name="CheekSpot")
    K.eyes(body, 0.4, 0.2, 0.22, iris=BROWN, iris_dark=BROWN_D, tall=1.22)
    K.smile(body, -0.22, 0.2, skin=G, tongue=(0.98, 0.52, 0.46), inside=(0.48, 0.14, 0.10))
    K.finish("pet_slimey", out, triangles=6000)

elif kind == "leafling":
    G, G_D, G_L, CREAM, CREAM_D = (0.60, 0.80, 0.26), (0.36, 0.60, 0.14), (0.78, 0.90, 0.42), (0.98, 0.95, 0.74), (0.90, 0.82, 0.52)
    LEAF, LEAF_D, LEAF_L = (0.38, 0.72, 0.20), (0.20, 0.50, 0.12), (0.62, 0.88, 0.30)
    # Sculpted against art/ref3d/turn/leafling.png. A round seedling: one smooth egg for head and body, a cap of
    # overlapping leaves over the top third, a cream tummy, stub arms and feet, and one big leaf on a bent stalk,
    # tilted so that it shows from the front and from the side.
    body = ball("Body", (0, 0, 0.95), 0.88, G_D, (1.04, 0.98, 1.0), color2=G, k=0.14)
    patch(body, (0, -1, -0.62), 0.5, CREAM, (1.15, 0.8), lift=0.012, name="Tummy", color2=CREAM_D, axis="Y")
    for s in (-1, 1):
        ball(f"Arm{s}", (s * 0.86, -0.22, 0.8), 0.2, G_D, (0.95, 1.0, 1.2), rot=(rad(10), rad(s * -30), 0), color2=G, k=0.08)
        ball(f"Foot{s}", (s * 0.4, -0.28, 0.14), 0.26, G_D, (1.05, 1.4, 0.62), color2=G, k=0.06)
        patch(body, (s * 0.92, -1, -0.04), 0.12, (1.0, 0.72, 0.36), (1.25, 0.8), lift=0.014, name="Blush")
    # Cap: a cushion of leaves on top and eight leaf tips lying down over the forehead, sides and back
    ball("Cap", (0, 0, 1.66), 0.52, LEAF, (1.25, 1.15, 0.5), color2=LEAF_L, k=0.08)
    for i in range(8):
        a = rad(i * 45 + 22)
        ex, ey = math.sin(a), -math.cos(a)
        limb(f"CapLeaf{i}", (ex * 0.3, ey * 0.3, 1.74), (ex * 0.74, ey * 0.7, 1.36), 0.2, 0.04, LEAF, color2=LEAF_L, k=0.05)
    K.eyes(body, 0.4, 0.16, 0.21, iris=(0.76, 0.52, 0.12), iris_dark=(0.30, 0.16, 0.05), tall=1.2, socket=0.03)
    K.smile(body, -0.16, 0.13, skin=G, tongue=(0.98, 0.52, 0.46))
    rope("Stalk", [(0, 0, 1.84), (-0.06, 0, 2.14), (0.04, -0.02, 2.4), (0.24, -0.06, 2.54)], [0.13, 0.1, 0.085, 0.07], LEAF_D, LEAF, n=12)
    K.leaf("Leaf", (0.18, -0.06, 2.5), (1.4, -0.16, 2.92), 0.5, LEAF, LEAF_L, thick=0.08, bend=-0.12, up=(0.25, 1, 0))
    K.finish("pet_leafling", out, triangles=6500)

elif kind == "stonepup":
    ST, ST_D, ST_L, MOSS, MOSS_L = (0.62, 0.60, 0.58), (0.42, 0.41, 0.43), (0.80, 0.78, 0.74), (0.36, 0.56, 0.18), (0.56, 0.74, 0.28)
    LEATHER, GOLD, GOLD_L, PINK = (0.42, 0.24, 0.12), (0.92, 0.68, 0.20), (1.0, 0.9, 0.5), (0.96, 0.52, 0.56)
    BROWN, BROWN_D = (0.62, 0.36, 0.14), (0.26, 0.12, 0.05)
    # Sculpted against art/ref3d/turn/stonepup.png. A sitting puppy of smooth river stone: the head is nearly half
    # of it, with a real snout sticking out low on the face, heavy slab ears hanging from the top corners and
    # flaring out, chunky front legs with big paws, haunches at the sides, a stub tail up behind its right hip.
    body = ball("Body", (0, 0.22, 0.62), 0.52, ST_D, (1.0, 1.05, 1.05), color2=ST, k=0.14)
    ball("Chest", (0, -0.18, 0.82), 0.42, ST, (1.05, 0.8, 1.05), color2=ST_L, k=0.12)
    for s in (-1, 1):
        ball(f"Haunch{s}", (s * 0.48, 0.26, 0.4), 0.38, ST_D, (0.9, 1.12, 1.0), color2=ST, k=0.12)
        ball(f"BackPaw{s}", (s * 0.6, -0.08, 0.14), 0.22, ST, (1.0, 1.4, 0.66), color2=ST_L, k=0.05)
        limb(f"FrontLeg{s}", (s * 0.25, -0.28, 0.92), (s * 0.27, -0.42, 0.26), 0.23, 0.21, ST, color2=ST_L, k=0.08)
        ball(f"FrontPaw{s}", (s * 0.27, -0.54, 0.15), 0.25, ST_L, (1.0, 1.3, 0.62), k=0.05)
        for j in (-1, 0, 1):   # toes: three rounded bumps on each front paw
            ball(f"Toe{s}{j}", (s * 0.27 + j * 0.13, -0.8, 0.12), 0.085, ST_L, (1, 1.2, 0.9), k=0.035)
    HZ = 1.74
    head = K.head("Head", (0, -0.1, HZ), 0.52, ST_D, ST, wide=1.0, cheeks=0.52, cheek_drop=0.36, jaw=0.42, brow=0.26, back=0.22)
    muzzle = ball("Muzzle", (0, -0.56, HZ - 0.2), 0.27, ST_L, (1.05, 1.1, 0.8), k=0.13)
    ball("MuzzleTip", (0, -0.74, HZ - 0.14), 0.15, ST_L, (1.1, 1.0, 0.85), k=0.1)
    ball("Nose", (0, -0.87, HZ - 0.06), 0.085, (0.36, 0.20, 0.14), (1.35, 0.85, 0.85), role="hard", seg=14)
    K.smile(muzzle, -0.62, 0.17, skin=ST_L)
    ball("Tongue", (0.02, -0.8, HZ - 0.44), 0.085, PINK, (1.0, 0.55, 1.5), k=0.03)
    K.eyes(head, 0.5, 0.02, 0.15, iris=BROWN, iris_dark=BROWN_D, tall=1.2, socket=0.04)
    for s in (-1, 1):
        # slab ears: thick flat stones from the top corners of the head, hanging down and flaring out
        ball(f"EarTop{s}", (s * 0.46, -0.06, HZ + 0.36), 0.2, ST, (1.1, 1.0, 0.8), k=0.12)
        ball(f"Ear{s}", (s * 0.7, -0.04, HZ + 0.02), 0.3, ST_D, (0.5, 1.05, 1.4), rot=(0, rad(s * -22), 0), color2=ST, k=0.07)
    # moss: a cushion on top of the head, patches on one ear, the shoulders and the back
    ball("MossCap", (0.04, -0.08, HZ + 0.5), 0.3, MOSS, (1.3, 1.1, 0.4), color2=MOSS_L, k=0.05)
    ball("MossEar", (0.82, -0.06, HZ + 0.16), 0.17, MOSS, (0.7, 1.1, 1.1), color2=MOSS_L, k=0.04)
    ball("MossEar2", (-0.84, -0.06, HZ + 0.06), 0.15, MOSS, (0.7, 1.1, 1.1), color2=MOSS_L, k=0.04)
    patch(body, (0.5, 1, 0.6), 0.36, MOSS, (1.2, 0.9), lift=0.014, name="MossBack", color2=MOSS_L)
    patch(body, (-0.8, -0.2, 0.5), 0.24, MOSS, (1.0, 1.2), lift=0.014, name="MossSide", color2=MOSS_L)
    # collar with studs and a brass tag
    ball("Collar", (0, -0.06, 1.14), 0.46, LEATHER, (1.02, 1.0, 0.25), rot=(rad(10), 0, 0), k=0.035)
    for j in (-2, -1, 1, 2):
        a = rad(j * 28)
        ball(f"Stud{j}", (math.sin(a) * 0.47, -0.06 - math.cos(a) * 0.46, 1.14 - math.cos(a) * 0.08), 0.04, GOLD, role="hard", seg=10)
    ball("Tag", (0, -0.58, 0.86), 0.15, GOLD, (1.0, 0.3, 1.0), role="hard", seg=20, color2=GOLD_L)
    limb("Tail", (-0.3, 0.6, 0.5), (-0.74, 0.86, 1.12), 0.22, 0.11, ST_D, color2=ST, k=0.08)
    K.finish("pet_stonepup", out, triangles=8000)

elif kind == "minigolem":
    R, R_D, R_L, R_LL, CORE, CORE_L = (0.60, 0.40, 0.26), (0.42, 0.27, 0.17), (0.80, 0.60, 0.38), (0.90, 0.72, 0.48), (1.0, 0.50, 0.10), (1.0, 0.86, 0.36)
    # Sculpted against art/ref3d/turn/minigolem.png. A little golem of rounded boulders: the head is a wide heap of
    # rocks, half of its height, with a darker smooth face in the middle; a small body with the glowing core in the
    # chest; boulder shoulders, fists and feet. Rocks keep their own outline (small k), the face melts into one.
    HZ = 1.82
    head = K.head("Head", (0, -0.02, HZ), 0.5, R_D, R, wide=1.16, cheeks=0.5, cheek_drop=0.3, jaw=0.46, brow=0.0, back=0.25, k=0.16)
    for i, (x, y, z, r, sc) in enumerate(((0.0, 0.0, 0.5, 0.26, (1.3, 1.1, 0.8)), (0.42, 0.02, 0.36, 0.24, (1.1, 1.0, 0.85)), (-0.44, 0.02, 0.34, 0.25, (1.1, 1.0, 0.85)),
                                          (0.64, -0.02, 0.02, 0.25, (0.9, 1.0, 1.1)), (-0.64, -0.02, 0.0, 0.26, (0.9, 1.0, 1.1)),
                                          (0.56, -0.06, -0.34, 0.2, (1, 1, 1)), (-0.56, -0.06, -0.36, 0.2, (1, 1, 1)),
                                          (0.3, 0.42, 0.2, 0.26, (1.1, 0.9, 1.0)), (-0.3, 0.42, 0.18, 0.26, (1.1, 0.9, 1.0)), (0, 0.46, -0.16, 0.3, (1.3, 0.8, 1.0)))):
        ball(f"HeadRock{i}", (x, y, HZ + z), r, R_L, sc, color2=R_LL, k=0.045)
    K.eyes(head, 0.42, 0.0, 0.14, iris=AMBER, iris_dark=AMBER_D, tall=1.2, socket=0.035)
    K.smile(head, -0.5, 0.12, skin=R_D)
    K.blush(head, 0.78, -0.36, 0.06, color=(0.86, 0.46, 0.3))
    chest = ball("Chest", (0, 0, 1.02), 0.4, R_D, (1.08, 0.86, 1.0), color2=R, k=0.1)
    ball("Hips", (0, 0, 0.62), 0.32, R_D, (1.1, 0.9, 0.8), k=0.08)
    for s in (-1, 1):
        ball(f"Shoulder{s}", (s * 0.5, 0, 1.24), 0.22, R_L, (1.0, 1.0, 0.95), color2=R_LL, k=0.045)
        limb(f"Arm{s}", (s * 0.56, 0, 1.16), (s * 0.66, -0.04, 0.9), 0.15, 0.16, R, k=0.05)
        ball(f"Fist{s}", (s * 0.69, -0.06, 0.74), 0.24, R_L, (1.0, 1.05, 1.0), color2=R_LL, k=0.045)
        ball(f"Leg{s}", (s * 0.23, 0, 0.4), 0.22, R_D, (1.0, 1.05, 1.1), k=0.06)
        ball(f"Foot{s}", (s * 0.25, -0.08, 0.14), 0.24, R_L, (1.1, 1.35, 0.6), color2=R_LL, k=0.045)
        ball(f"ChestRock{s}", (s * 0.3, -0.16, 1.18), 0.17, R_L, (1.1, 0.8, 0.9), k=0.045)
    # the core: a shallow socket, the glowing stone, a bright middle
    patch(chest, (0, -1, 0.0), 0.25, None, (1.0, 1.0), role="cut", depth=0.06, k=0.05, name="CoreSocket")
    patch(chest, (0, -1, 0.0), 0.27, R_D, (1.0, 1.0), lift=0.012, name="Socket", lit=False)
    patch(chest, (0, -1, 0.0), 0.21, CORE, (1.0, 1.0), lift=0.02, name="Core", color2=CORE_L, axis="Y", lit=False, keep=True)
    ball("CoreGlow", (0, -0.36, 1.02), 0.085, CORE_L, (1.2, 0.5, 1.2), role="glow", seg=10)
    K.finish("pet_minigolem", out, triangles=8000)

elif kind == "phoenix":
    RED, RED_D, ORANGE, GOLD, YELLOW, CREAM, CREAM_D = (0.92, 0.26, 0.10), (0.72, 0.15, 0.06), (1.0, 0.50, 0.10), (1.0, 0.76, 0.18), (1.0, 0.93, 0.45), (1.0, 0.90, 0.68), (0.96, 0.74, 0.44)
    # Sculpted against art/ref3d/turn/phoenix.png. A fiery chick standing on two legs: round head with a small beak
    # and a flame crest sweeping up and back, an egg body with a fluffy cream chest, flame-feather wings held a
    # little away from the sides, and a big tail of flames that sweeps back, up and curls.
    body = ball("Body", (0, 0.06, 0.84), 0.5, RED_D, (1.0, 1.05, 1.1), color2=RED, k=0.12)
    ball("ChestFluff", (0, -0.3, 0.88), 0.36, CREAM_D, (1.05, 0.72, 1.0), color2=CREAM, k=0.1)
    for i, (x, tipz, r) in enumerate(((0, 0.4, 0.17), (-0.2, 0.5, 0.14), (0.2, 0.5, 0.14))):
        limb(f"FluffLock{i}", (x * 0.6, -0.4, 0.82), (x, -0.46, tipz), r, 0.03, CREAM, color2=CREAM_D, k=0.05)
    HZ = 1.6
    head = K.head("Head", (0, -0.06, HZ), 0.5, RED, ORANGE, wide=1.06, cheeks=0.54, cheek_drop=0.36, jaw=0.0, brow=0.0, back=0.2)
    ball("FaceFluff", (0, -0.3, HZ - 0.24), 0.3, CREAM, (1.4, 0.8, 0.72), k=0.12)
    for s in (-1, 1):
        limb(f"CheekTuft{s}", (s * 0.42, -0.12, HZ - 0.2), (s * 0.78, 0.0, HZ - 0.3), 0.17, 0.03, CREAM, color2=CREAM_D, k=0.06)
        limb(f"CheekTuftB{s}", (s * 0.4, -0.1, HZ - 0.02), (s * 0.74, 0.04, HZ + 0.06), 0.15, 0.03, ORANGE, color2=GOLD, k=0.06)
    cone("Beak", (0, -0.6, HZ - 0.14), 0.11, 0.24, GOLD, (rad(100), 0, 0), top=0.02, verts=12, role="hard", color2=YELLOW)
    K.eyes(head, 0.5, 0.04, 0.15, iris=AMBER, iris_dark=AMBER_D, tall=1.2, socket=0.03)
    K.blush(head, 0.9, -0.3, 0.055, color=(1.0, 0.62, 0.3))
    # crest: flames sweeping up and back, the middle one tallest, each ending in a small curl
    for i, (x, h, back, c2) in enumerate(((0.0, 1.0, 0.5, YELLOW), (-0.24, 0.76, 0.36, GOLD), (0.24, 0.76, 0.36, GOLD), (-0.44, 0.5, 0.24, GOLD), (0.44, 0.5, 0.24, GOLD))):
        rope(f"Crest{i}", [(x, -0.1, HZ + 0.3), (x * 1.1, 0.0 + back * 0.3, HZ + 0.3 + h * 0.5), (x * 1.2, back * 0.8, HZ + 0.3 + h), (x * 1.1, back * 1.1, HZ + 0.3 + h * 0.86)],
             [0.22, 0.2, 0.11, 0.03], ORANGE, c2, n=12, k=0.05)
    for s in (-1, 1):
        # wings: a shoulder and three flame feathers pointing out and down, red at the root, gold at the tip
        ball(f"WingRoot{s}", (s * 0.48, 0.08, 1.02), 0.26, RED, (0.9, 0.9, 1.1), k=0.1)
        for j, (tx, ty, tz, r, c2) in enumerate(((1.3, 0.26, 0.96, 0.24, YELLOW), (1.24, 0.28, 0.62, 0.24, GOLD), (1.04, 0.26, 0.34, 0.22, GOLD), (0.78, 0.2, 0.22, 0.2, ORANGE), (1.12, 0.32, 1.26, 0.2, GOLD))):
            limb(f"Wing{s}{j}", (s * 0.5, 0.1, 1.0), (s * tx, ty, tz), r, 0.035, RED, color2=c2, k=0.05)
        limb(f"Leg{s}", (s * 0.18, -0.02, 0.44), (s * 0.2, -0.06, 0.1), 0.08, 0.07, GOLD, role="hard", verts=10, cap=False)
        for j in (-1, 0, 1):
            cone(f"Toe{s}{j}", (s * 0.2 + j * 0.1, -0.22, 0.06), 0.05, 0.28, GOLD, (rad(96), 0, rad(j * -18)), verts=8, role="hard")
    # tail: three big flames from the rump, sweeping back and up on its left side, curling at the tips
    for i, (pts, radii, c2) in enumerate((
            ([(0.1, 0.4, 0.74), (0.7, 0.8, 0.8), (1.14, 1.0, 1.2), (1.2, 1.0, 1.8), (0.96, 0.9, 2.12), (0.8, 0.8, 1.96)], [0.24, 0.32, 0.3, 0.22, 0.12, 0.04], YELLOW),
            ([(0.0, 0.42, 0.64), (0.08, 1.0, 0.5), (0.2, 1.46, 0.82), (0.18, 1.56, 1.34), (0.04, 1.4, 1.58)], [0.22, 0.28, 0.25, 0.15, 0.04], GOLD),
            ([(-0.1, 0.4, 0.74), (-0.46, 0.86, 0.84), (-0.68, 1.12, 1.3), (-0.58, 1.1, 1.74), (-0.4, 0.96, 1.86)], [0.2, 0.26, 0.2, 0.1, 0.04], GOLD),
            ([(0.0, 0.4, 0.9), (0.0, 0.8, 1.3), (0.06, 1.0, 1.8), (0.0, 0.9, 2.2)], [0.2, 0.22, 0.14, 0.04], ORANGE))):
        rope(f"Tail{i}", pts, radii, RED, c2, n=24, k=0.06)
    for i, (pos, R) in enumerate((((-0.95, -0.3, 2.3), 0.21), ((1.0, -0.25, 2.62), 0.16), ((-1.1, 0.3, 0.72), 0.13))):
        sparkle(f"Sparkle{i}", pos, R, (1.0, 0.86, 0.45))
    K.finish("pet_phoenix", out, triangles=8000)

elif kind == "mosskitten":
    FUR, FUR_D, CREAM, CREAM_D, STRIPE, MOSS, MOSS_L, PINK = (0.62, 0.45, 0.30), (0.40, 0.27, 0.17), (0.98, 0.91, 0.78), (0.90, 0.78, 0.60), (0.34, 0.22, 0.13), (0.36, 0.56, 0.18), (0.58, 0.76, 0.30), (0.96, 0.62, 0.64)
    GOLD_I, GOLD_ID = (0.88, 0.66, 0.14), (0.34, 0.2, 0.06)
    # Sculpted against art/ref3d/turn/mosskitten.png. A fluffy kitten standing on four sturdy legs: round head
    # with cheek fluff, a tiny muzzle, upright ears with pink hollows, a flower by its left ear, a bib of chest
    # fluff, a cape of moss leaves over shoulders and back, and a thick tail that curls up and forward.
    body = ball("Body", (0, 0.3, 0.76), 0.5, FUR_D, (1.12, 1.5, 0.95), color2=FUR, k=0.14)
    ball("Bib", (0, -0.3, 0.94), 0.34, CREAM_D, (1.15, 0.8, 1.0), color2=CREAM, k=0.1)
    for i, (x, tipz, r) in enumerate(((0, 0.5, 0.18), (-0.22, 0.62, 0.15), (0.22, 0.62, 0.15))):
        limb(f"BibLock{i}", (x * 0.6, -0.4, 0.9), (x, -0.48, tipz), r, 0.035, CREAM, color2=CREAM_D, k=0.06)
    for s in (-1, 1):
        for j, y in enumerate((-0.22, 0.84)):
            limb(f"Leg{s}{j}", (s * 0.3, y, 0.72), (s * 0.31, y - 0.02, 0.24), 0.23, 0.21, FUR, color2=CREAM, k=0.08)
            ball(f"Paw{s}{j}", (s * 0.31, y - 0.1, 0.14), 0.24, CREAM, (1.0, 1.25, 0.66), k=0.05)
    HZ, HY = 1.6, -0.14
    # A ROUND face (Lemp 2026-11-23: "looks a little weird with the triangle face"; the fox-style ruff pointing out
    # and down made the head a triangle). Wide skull, cheeks high, and the cheek fluff is a round puff at eye-to-mouth
    # height with two short soft tufts, so the outline stays an oval.
    head = K.head("Head", (0, HY, HZ), 0.56, FUR_D, FUR, wide=1.1, cheeks=0.5, cheek_drop=0.26, jaw=0.34, brow=0.0, flat_top=0.0, back=0.2)
    ball("Chin", (0, HY - 0.28, HZ - 0.36), 0.24, CREAM, (1.2, 1.0, 0.66), k=0.14)
    for s in (-1, 1):
        ball(f"Fluff{s}", (s * 0.5, HY - 0.02, HZ - 0.14), 0.29, CREAM, (1.0, 0.9, 1.08), color2=CREAM_D, axis="X" if s > 0 else "Z", k=0.16)
        for j, (dz, tx) in enumerate(((0.06, 0.82), (-0.2, 0.78))):   # two short soft tufts: fluff, not spikes
            limb(f"FluffTip{s}{j}", (s * 0.6, HY + 0.02, HZ - 0.14 + dz), (s * tx, HY + 0.05, HZ - 0.14 + dz * 1.3), 0.15, 0.07, CREAM, color2=CREAM_D, k=0.09)
        # ears: upright, dark, with a pink hollow facing forward
        cone(f"Ear{s}", (s * 0.44, HY + 0.14, HZ + 0.56), 0.38, 0.62, FUR_D, (rad(6), rad(s * 20), 0), top=0.1, scale=(1.05, 0.56, 1), color2=STRIPE, k=0.07)
        cone(f"EarHollow{s}", (s * 0.47, HY - 0.07, HZ + 0.78), 0.2, 0.36, PINK, (rad(6), rad(s * 16), 0), top=0.04, scale=(1, 0.5, 1), role="cut", k=0.04)
        for j in range(3):   # tabby stripes on the forehead: paint only
            patch(head, (s * (0.12 + j * 0.2), -0.6, 1), 0.06, STRIPE, (0.5, 2.2), roll=s * (8 + j * 14), lift=0.014, name="Stripe")
    muzzle = ball("Muzzle", (0, HY - 0.5, HZ - 0.18), 0.19, CREAM, (1.3, 0.95, 0.82), k=0.12)
    ball("Nose", (0, HY - 0.675, HZ - 0.11), 0.04, PINK, (1.3, 0.8, 0.8), role="hard", seg=12)
    K.smile(muzzle, -0.62, 0.075, skin=CREAM)
    K.eyes(head, 0.5, -0.07, 0.15, iris=GOLD_I, iris_dark=GOLD_ID, tall=1.14, socket=0.04)
    K.blush(head, 0.95, -0.42, 0.065)
    # flower by its left ear: five petals, a gold middle, two leaves
    fx, fy, fz = 0.26, HY - 0.42, HZ + 0.48
    for j in range(5):
        a = rad(j * 72 + 18)
        ball(f"Petal{j}", (fx + math.cos(a) * 0.1, fy - 0.01, fz + math.sin(a) * 0.1), 0.085, (1.0, 0.98, 0.92), (1, 0.45, 1), role="hard", seg=12)
    ball("FlowerMid", (fx, fy - 0.05, fz), 0.055, (0.95, 0.72, 0.2), (1, 0.6, 1), role="hard", seg=10)
    K.leaf("CrownLeafA", (fx - 0.06, fy + 0.04, fz + 0.04), (fx - 0.42, fy + 0.1, fz + 0.14), 0.12, MOSS, MOSS_L, thick=0.05)
    K.leaf("CrownLeafB", (fx + 0.06, fy + 0.04, fz + 0.06), (fx + 0.2, fy + 0.12, fz + 0.3), 0.1, MOSS, MOSS_L, thick=0.05)
    # moss cape: leafy cushions over the shoulders and back with leaf tips hanging at the edge
    for i, (pos, r, sc) in enumerate((((0, 0.16, 1.2), 0.34, (1.35, 1.1, 0.42)), ((0, 0.66, 1.2), 0.32, (1.35, 1.2, 0.42)), ((0, 1.0, 1.1), 0.26, (1.2, 1.0, 0.5)),
                                      ((-0.44, 0.0, 1.04), 0.24, (0.7, 1.0, 0.9)), ((0.44, 0.0, 1.04), 0.24, (0.7, 1.0, 0.9)),
                                      ((-0.5, 0.5, 1.0), 0.24, (0.6, 1.3, 0.9)), ((0.5, 0.5, 1.0), 0.24, (0.6, 1.3, 0.9)))):
        ball(f"Moss{i}", pos, r, MOSS, sc, color2=MOSS_L, k=0.06)
    for s in (-1, 1):
        for j, y in enumerate((-0.1, 0.2, 0.5, 0.8)):
            limb(f"MossTip{s}{j}", (s * 0.5, y, 0.98), (s * 0.58, y + 0.03, 0.72), 0.11, 0.03, MOSS_L, color2=MOSS, k=0.05)
    # tail: thick, up from the rump on its right side, curling forward at the top
    rope("Tail", [(-0.1, 0.98, 0.96), (-0.5, 1.12, 1.1), (-0.86, 1.1, 1.5), (-0.84, 1.02, 1.92), (-0.58, 0.96, 2.04), (-0.44, 0.94, 1.84)],
         [0.17, 0.22, 0.26, 0.26, 0.2, 0.1], FUR_D, CREAM, n=30)
    K.finish("pet_mosskitten", out, triangles=8500)

elif kind == "glowbug":
    BR, BR_D, TAN, GOLD, GOLD_L, LAMP, LAMP_L, WING = (0.42, 0.27, 0.14), (0.28, 0.17, 0.09), (0.86, 0.68, 0.42), (0.90, 0.68, 0.20), (1.0, 0.88, 0.45), (1.0, 0.70, 0.10), (1.0, 0.95, 0.45), (0.96, 0.92, 0.76)
    # Sculpted against art/ref3d/turn/glowbug.png. A chubby firefly in flight: a big round fuzzy head with a tan
    # face, a small body with a gold leaf collar, a glowing lantern of three rings below and behind, two pairs of
    # glassy wings held up, feelers ending in fat glowing drops, six short legs dangling.
    head = K.head("Head", (0, -0.12, 1.5), 0.6, BR_D, BR, wide=1.1, cheeks=0.56, cheek_drop=0.38, jaw=0.0, brow=0.0)
    ball("FaceFluff", (0, -0.34, 1.36), 0.4, TAN, (1.25, 0.8, 0.85), k=0.16)
    patch(head, (0, -1, -0.3), 0.44, TAN, (1.2, 0.85), lift=0.012, name="Face")
    body = ball("Body", (0, 0.22, 0.92), 0.46, BR_D, (1.0, 1.0, 0.95), color2=BR, k=0.12)
    ball("Ruff", (0, -0.06, 1.0), 0.44, GOLD, (1.15, 0.6, 0.5), rot=(rad(20), 0, 0), color2=GOLD_L, k=0.05)
    for i, (y, z, r) in enumerate(((0.5, 0.62, 0.46), (0.72, 0.46, 0.42), (0.9, 0.36, 0.32))):
        ball(f"Lamp{i}", (0, y, z), r, LAMP, (1.05, 1.0, 1.0), color2=LAMP_L, k=0.03)
    ball("LampCap", (0, 0.36, 0.82), 0.4, BR, (1.05, 0.6, 0.9), k=0.06)
    K.eyes(head, 0.46, 0.0, 0.165, iris=AMBER, iris_dark=AMBER_D, tall=1.2, socket=0.035)
    K.smile(head, -0.52, 0.12, skin=TAN)
    K.blush(head, 0.86, -0.36, 0.07)
    for s in (-1, 1):
        K.leaf(f"WingA{s}", (s * 0.3, 0.2, 1.45), (s * 1.55, 0.45, 2.15), 0.5, WING, (1.0, 0.98, 0.9), thick=0.06, bend=0.08, up=(0, 1, 0))
        K.leaf(f"WingB{s}", (s * 0.3, 0.4, 1.2), (s * 1.4, 0.7, 1.0), 0.36, WING, (1.0, 0.98, 0.9), thick=0.06, bend=0.08, up=(0, 1, 0))
        rope(f"Feeler{s}", [(s * 0.2, -0.2, 2.0), (s * 0.3, -0.26, 2.36), (s * 0.56, -0.3, 2.56), (s * 0.8, -0.3, 2.5)], [0.075, 0.065, 0.06, 0.055], BR_D, BR, n=12)
        ball(f"FeelerTip{s}", (s * 0.92, -0.3, 2.38), 0.17, LAMP, (1.0, 1.0, 1.25), color2=LAMP_L, k=0.04)
        for j in range(3):
            limb(f"Leg{s}{j}", (s * 0.3, -0.1 + j * 0.28, 0.7), (s * 0.42, -0.2 + j * 0.3, 0.3), 0.1, 0.085, BR_D, k=0.05)
            ball(f"Foot{s}{j}", (s * 0.43, -0.23 + j * 0.3, 0.24), 0.11, BR_D, (1, 1.2, 0.9), k=0.04)
    K.finish("pet_glowbug", out, triangles=8000)

elif kind == "crystalowl":
    FEA, FEA_D, CREAM, CREAM_D, GOLD, CRY, CRY_L = (0.56, 0.40, 0.28), (0.38, 0.26, 0.18), (0.98, 0.93, 0.84), (0.88, 0.78, 0.62), (0.95, 0.74, 0.24), (0.42, 0.74, 0.98), (0.82, 0.94, 1.0)
    # Sculpted against art/ref3d/turn/crystalowl.png. A round owl: one big egg, two cream face dishes round the
    # eyes under a feathered brow, a small beak, a cream chest, folded wings whose lower half is crystal feathers,
    # a fan of crystal shards over each brow, a gold collar with a gem.
    body = ball("Body", (0, 0.05, 1.0), 0.84, FEA_D, (1.0, 0.95, 1.16), color2=FEA, k=0.14)
    patch(body, (0, -1, -0.5), 0.5, CREAM, (1.1, 0.95), lift=0.012, name="Chest", color2=CREAM_D, axis="Y")
    for s in (-1, 1):
        # owl face: a shallow cream dish round each eye, a brow sweeping up and out, a full cheek
        ball(f"Disc{s}", (s * 0.36, -0.58, 1.46), 0.44, CREAM, (1.0, 0.5, 1.06), k=0.1)
        ball(f"OwlBrow{s}", (s * 0.44, -0.6, 1.9), 0.3, FEA, (1.5, 0.7, 0.5), rot=(0, rad(s * -24), 0), color2=FEA_D, k=0.1)
        ball(f"OwlCheek{s}", (s * 0.62, -0.28, 1.14), 0.44, FEA_D, (1.0, 0.9, 0.9), color2=FEA, k=0.14)
    K.eyes(body, 0.42, 0.46, 0.2, iris=AMBER, iris_dark=AMBER_D, tall=1.14)
    cone("Beak", (0, -0.9, 1.3), 0.11, 0.22, GOLD, (rad(125), 0, 0), top=0.02, verts=12, role="hard")
    patch(body, (0, -1, -0.12), 0.46, GOLD, (1.3, 0.13), lift=0.02, name="Collar")
    ball("Gem", (0, -0.85, 0.9), 0.1, CRY, (1.0, 0.6, 1.3), role="glow", seg=8)
    for s in (-1, 1):
        ball(f"Wing{s}", (s * 0.84, 0.12, 0.9), 0.56, FEA_D, (0.45, 0.95, 1.3), rot=(0, rad(s * 10), 0), color2=FEA, k=0.08)
        for j in range(4):
            cone(f"WingCrystal{s}{j}", (s * (1.0 - j * 0.04), -0.2 + j * 0.2, 0.44 - j * 0.03), 0.12, 0.62, CRY, (rad(180), 0, rad(s * 12)), verts=6, role="hard", flat=True, color2=CRY_L)
        # the crystal crown: a fan of shards over each brow, leaning outwards
        for j, (dx, h, ang) in enumerate(((0.2, 0.62, 8), (0.42, 0.8, 24), (0.62, 0.66, 42), (0.78, 0.44, 60))):
            cone(f"Crown{s}{j}", (s * dx, -0.26, 1.98 + h * 0.42 - dx * 0.34), 0.15, h, CRY, (rad(-8), rad(s * ang), 0), verts=6, role="hard", flat=True, color2=CRY_L)
        for j in (-1, 0, 1):
            cone(f"Toe{s}{j}", (s * 0.3 + j * 0.11, -0.56, 0.08), 0.07, 0.3, GOLD, (rad(98), 0, rad(j * -16)), verts=8, role="hard")
    for i, a in enumerate((-26, 0, 26)):
        cone(f"TailCrystal{i}", (math.sin(rad(a)) * 0.32, 0.8, 0.4), 0.11, 0.56, CRY, (rad(-118), 0, rad(-a)), verts=6, role="hard", flat=True, color2=CRY_L)
    K.finish("pet_crystalowl", out, triangles=8000)

elif kind in ("starunicorn", "voiddrake", "babydragon"):
    def wing(s, root, tips, color, color2):
        """a bat wing: skin from the root through the finger tips with a scalloped edge (the skin dips in between
        two fingers), and a finger bone to every tip"""
        tips = [(s * x, y, z) for x, y, z in tips]
        pts = [root]
        for i, t in enumerate(tips):
            pts.append(t)
            if i < len(tips) - 1:
                n = tips[i + 1]
                mid = [(t[j] + n[j]) / 2 for j in range(3)]
                pts.append(tuple(mid[j] + (root[j] - mid[j]) * 0.2 for j in range(3)))   # the dip between two fingers
        o = K.sheet(f"Wing{s}", pts, [(0, i, i + 1) for i in range(1, len(pts) - 1)], color2, 0.06)
        for i, t in enumerate(tips):
            limb(f"WingBone{s}{i}", root, t, 0.065, 0.03, color, role="hard", verts=8, cap=False)
        return o

    if kind == "starunicorn":
        COAT, COAT_D, GOLD, GOLD_L, GOLD_D, EARPINK = (1.0, 0.95, 0.86), (0.95, 0.85, 0.73), (0.98, 0.76, 0.22), (1.0, 0.93, 0.56), (0.85, 0.58, 0.14), (1.0, 0.72, 0.72)
        IRIS, IRIS_D = (0.80, 0.50, 0.14), (0.32, 0.15, 0.05)
        PINK, PEACH, YELLOW, MINT, SKY, LILAC = (1.0, 0.52, 0.70), (1.0, 0.72, 0.52), (1.0, 0.90, 0.48), (0.55, 0.88, 0.70), (0.50, 0.76, 1.0), (0.74, 0.60, 0.98)
        RAINBOW = [PINK, PEACH, YELLOW, MINT, SKY, LILAC]
        # Third build (Lemp 2026-11-23: "redo the unicorn, it still looks awful"). What was wrong, part by part against
        # art/ref3d/turn/starunicorn.png: the mane was two sausages hanging like headphones, the tail a flat curtain,
        # the legs stubs with gold balls, the pink snout read as a pig, the ears were tiny, the horn a thin spike.
        # Now: a pony standing on four sturdy legs with flat gold hooves, a big head with a SHORT cream muzzle that is
        # part of the head, big ears, a thick ridged horn leaning forward, a mane of many rainbow locks that fans out
        # from the crown behind the ears and falls in curls beside the face and down the neck, and a big rolled
        # rainbow tail that rises above the back.
        body = ball("Body", (0, 0.05, 1.3), 0.58, COAT_D, (1.0, 1.3, 0.95), color2=COAT, k=0.14)
        ball("Chest", (0, -0.42, 1.36), 0.5, COAT_D, (1.0, 0.9, 1.05), color2=COAT, k=0.14)
        ball("Rump", (0, 0.52, 1.32), 0.54, COAT_D, (1.02, 0.95, 1.0), color2=COAT, k=0.14)
        for s in (-1, 1):
            for j, (y, top) in enumerate(((-0.46, 1.15), (0.54, 1.1))):
                ball(f"Shoulder{s}{j}", (s * 0.32, y, top), 0.31, COAT, (0.95, 1.05, 1.15), k=0.12)
                limb(f"Leg{s}{j}", (s * 0.33, y, top - 0.05), (s * 0.35, y - 0.02, 0.2), 0.25, 0.21, COAT, color2=COAT_D, k=0.08)
                # a real hoof: a flat-bottomed gold cup, a little wider than the leg (a hard piece, so its edge is crisp)
                cone(f"Hoof{s}{j}", (s * 0.35, y - 0.03, 0.12), 0.265, 0.24, GOLD_D, (0, 0, 0), top=0.225, verts=18, role="hard", color2=GOLD_L)
        rope("Neck", [(0, -0.4, 1.58), (0, -0.56, 1.88), (0, -0.66, 2.13)], [0.4, 0.36, 0.38], COAT_D, COAT, n=10, k=0.14)
        HZ, HY = 2.4, -0.74
        head = K.head("Head", (0, HY, HZ), 0.66, COAT_D, COAT, wide=1.08, cheeks=0.56, cheek_drop=0.34, jaw=0.0, brow=0.0, back=0.3)
        # MUZZLE AND NOSE (Lemp 2026-11-23: "it has no nose"; the build before had melted the muzzle into the face and
        # shrunk the nostrils to nothing, after an earlier pink ball had read as a pig's snout). The muzzle is its own
        # round shape standing out from the face, a touch pinker than the coat, with a rounded nose on top and two
        # clear nostrils. The nostrils are "keep" marks: the painter never sees them, so it cannot paint them away.
        MUZ = (1.0, 0.90, 0.84)
        muzzle = ball("Muzzle", (0, HY - 0.56, HZ - 0.26), 0.3, MUZ, (1.15, 1.0, 0.8), k=0.11)
        ball("NoseTop", (0, HY - 0.66, HZ - 0.14), 0.19, MUZ, (1.3, 0.9, 0.7), k=0.1)
        for s in (-1, 1):
            patch(muzzle, (s * 0.42, -1, 0.62), 0.028, (0.74, 0.46, 0.46), (1.0, 1.7), roll=s * -16, lift=0.018, name="Nostril", lit=False, keep=True)   # small and well apart: big ones on the front read as a pig again
            # EARS (Lemp: "sharp like elf ears and not fluffy like unicorn ears"; they were cones). A rounded leaf:
            # widest in the lower half, a soft round tip, cupped with a pink inside, and tufts of fluff at the base.
            tilt = (rad(-6), rad(s * 24), 0)
            ear = ball(f"Ear{s}", (s * 0.6, HY - 0.02, HZ + 0.66), 0.3, COAT, (0.82, 0.5, 1.15), rot=tilt, color2=COAT_D, k=0.08)
            ball(f"EarTip{s}", (s * 0.72, HY - 0.02, HZ + 0.93), 0.17, COAT, (0.8, 0.55, 1.0), rot=tilt, k=0.1)
            ball(f"EarHollow{s}", (s * 0.63, HY - 0.17, HZ + 0.7), 0.21, EARPINK, (0.72, 0.42, 1.1), rot=tilt, role="cut", k=0.05)
            # (the pink inside is also painted on, so the painter finds it exactly where the ear is)
            patch(ear, (s * 0.06, -1, 0.3), 0.15, EARPINK, (0.9, 1.45), roll=s * -22, lift=0.014, name="EarIn")
            # a soft round puff of fluff sits in the bottom of the ear's opening (pointed tufts there stuck out
            # sideways and read as little spikes)
            ball(f"EarFluff{s}", (s * 0.6, HY - 0.17, HZ + 0.46), 0.13, COAT, (1.15, 0.7, 0.9), k=0.06)
        # (the mouth sits on the FRONT of the muzzle, under the nose: tucked below it, the game's camera saw a dark "o")
        K.smile(muzzle, -0.3, 0.19, skin=MUZ)
        K.eyes(head, 0.5, 0.04, 0.2, iris=IRIS, iris_dark=IRIS_D, lash=True, tall=1.2, socket=0.035)
        K.blush(head, 0.92, -0.32, 0.09)
        # horn: thick at the root, leaning forward, built from stacked tilted rings so it has the spiral ridges
        hb, hd = (0, HY - 0.34, HZ + 0.54), (0, -math.sin(rad(14)), math.cos(rad(14)))
        along, i = 0.05, 0
        while along < 0.8:
            t = along / 0.8
            r = 0.22 * (1 - t) + 0.04
            ball(f"Horn{i}", tuple(hb[j] + hd[j] * along for j in range(3)), r, tuple(GOLD[j] + (GOLD_L[j] - GOLD[j]) * t for j in range(3)),
                 (1, 1, 0.6), rot=(rad(14), rad(18), 0), k=0.02)
            along += r * 0.72
            i += 1
        cone("HornTip", tuple(hb[j] + hd[j] * (along + 0.06) for j in range(3)), 0.05, 0.22, GOLD_L, (rad(14), 0, 0), top=0.01, k=0.02)

        def lock(name, pts, radii, c, n=22, k=0.035):
            """one lock of hair in one rainbow colour: neighbours melt into a ribbed, banded mass"""
            rope(name, pts, radii, c, n=n, k=k)

        # MANE, in three parts (the first try was nine straight locks: a striped helmet from behind, a wig in front).
        # 1. Back: seven locks fan out from the crown and SWEEP SIDEWAYS as they fall, so the bands swirl like in
        #    the target's back view; every second lock is longer; each ends in a curl.
        cy = HY + 0.16
        crown = (0, cy - 0.06, HZ + 0.58)

        def at(a_deg, dist, z):
            """a point at angle a (0 = straight behind the head) and that far from the head's axis"""
            return (math.sin(rad(a_deg)) * dist, cy + math.cos(rad(a_deg)) * dist, z)

        ball("ManeCrown", (0, cy + 0.04, HZ + 0.6), 0.5, PINK, (1.2, 1.0, 0.9), k=0.1)   # rounds off the top, the locks lie on it
        # (The fan stops well short of the side ribbon it sweeps towards: where the two met, lock tips poked through
        # the ribbon as coloured specks.)
        for i, ang in enumerate((-70, -49, -28, -7, 14, 35)):
            tw, longer = 30, (i % 2) * 0.16
            lock(f"Mane{i}", [crown, at(ang, 0.42, HZ + 0.84), at(ang + tw * 0.25, 0.8, HZ + 0.3), at(ang + tw * 0.6, 0.92, HZ - 0.2),
                              at(ang + tw * 0.9, 0.88, HZ - 0.5 - longer), at(ang + tw, 1.04, HZ - 0.72 - longer), at(ang + tw * 1.1, 1.2, HZ - 0.58 - longer)],
                 [0.18, 0.22, 0.23, 0.21, 0.17, 0.12, 0.05], RAINBOW[i % 6])
        # 2. Sides: beside each cheek one broad ribbon of five nested bands, pink outside to lilac inside, falling to
        #    below the chin and curling out: from the front the face is framed by a rainbow, as in the target.
        for s in (-1, 1):
            flow = [(s * 0.2, HY + 0.3, 0.78), (s * 0.6, HY + 0.3, 0.66), (s * 0.82, HY + 0.26, 0.18), (s * 0.86, HY + 0.2, -0.32),
                    (s * 0.8, HY + 0.14, -0.74), (s * 0.94, HY + 0.12, -1.0), (s * 1.1, HY + 0.12, -0.86)]
            for b, (f, c) in enumerate(((1.14, PINK), (1.07, YELLOW), (1.0, MINT), (0.93, SKY), (0.86, LILAC))):
                # (the bands run together towards the tip: stepped all the way, the tips spread like a claw)
                pts = [(x * (1 + (f - 1) * w), y, HZ + z * (1 + (f - 1) * w)) for (x, y, z), w in zip(flow, (1, 1, 1, 1, 0.85, 0.5, 0.25))]
                rope(f"Fall{s}{b}", pts, [0.07, 0.085, 0.09, 0.09, 0.09, 0.085, 0.06], c, n=64, squash=(1, 2.4, 1), k=0.03)
        # 3. Forelock: a swoop of three bands from beside the horn across the brow to its left temple, curling up, and
        #    staying above the eyes.
        def brow_pt(phi, z, off):
            """a point on the skull at that angle round it (0 = straight ahead, 90 = its left side) and that height
            above the head's centre, lifted off the surface by off"""
            rho = math.sqrt(max(0.0, 1 - (z / 0.62) ** 2))
            return (math.sin(rad(phi)) * (0.71 * rho + off), HY - math.cos(rad(phi)) * (0.66 * rho + off), HZ + z)

        # (The forelock LIES ON the forehead and stays clear of the eyes. Hanging in front of it, it was a visor, and
        # where it covered an eye the painted eye was draped over the hair as dark specks.)
        for b, c in enumerate((MINT, YELLOW, PINK)):
            dz, out_ = b * 0.075, b * 0.06   # each band a step higher AND a step further out, or the upper ones sink into the crown
            lock(f"Forelock{b}", [brow_pt(8, 0.55 + dz, 0.02 + out_), brow_pt(25, 0.49 + dz, 0.04 + out_), brow_pt(45, 0.43 + dz, 0.05 + out_), brow_pt(65, 0.37 + dz, 0.06 + out_),
                                  brow_pt(85, 0.33 + dz * 0.8, 0.1 + out_), brow_pt(100, 0.38 + dz * 0.6, 0.22 + out_ * 0.6), brow_pt(108, 0.54 + dz * 0.4, 0.26 + out_ * 0.3)],
                 [0.075, 0.09, 0.095, 0.09, 0.085, 0.07, 0.045], c, n=30, k=0.03)
        # (nothing swoops the other way: a second tuft made a bar across the brow, a short one read as a blue ball)
        # TAIL: an arch of five rainbow bands that rises above the back, falls behind and flicks out at the end. The
        # bands are stepped both sideways and in size, so every side of the pet shows all five colours (the first
        # try was a flat roll: a snail shell from the side, a pink plank from behind).
        TY, TZ = 1.4, 1.3
        for b, (f, c, end) in enumerate(((1.0, PINK, -70), (0.86, YELLOW, -100), (0.72, MINT, -140), (0.58, SKY, -190), (0.44, LILAC, -230))):
            pts = [((b - 2) * 0.06, 0.92, 1.48)]
            for a in range(170, end - 1, -30):
                # the two outer bands swing outwards at the end (the flick); the inner ones roll on inwards and fill
                # the middle, so the tail is a full plume and not a hollow arch
                grow = 1.0 + 0.2 * max(0.0, (-10 - a) / 60.0) if b < 2 else 1.0 - 0.3 * max(0.0, (-60 - a) / 170.0)
                pts.append(((b - 2) * 0.12, TY + math.cos(rad(a)) * 0.58 * f * grow, TZ + math.sin(rad(a)) * 0.78 * f * grow))
            rope(f"Tail{b}", pts, [0.11] + [0.155] * (len(pts) - 3) + [0.12, 0.06], c, n=64, squash=(1.5, 1, 1), k=0.05)
        for i, (pos, R) in enumerate((((0.85, -0.7, 3.4), 0.23), ((-1.25, -0.5, 2.7), 0.17), ((1.2, 0.3, 1.6), 0.14))):
            sparkle(f"Sparkle{i}", pos, R)
        K.finish("pet_starunicorn", out, triangles=8750)
    elif kind == "babydragon":
        V, V_D, V_L, BELLY, HORN, HORN_L, IRIS, IRIS_D = (0.62, 0.36, 0.84), (0.46, 0.23, 0.68), (0.80, 0.58, 0.96), (0.97, 0.90, 0.72), (0.86, 0.66, 0.26), (1.0, 0.9, 0.52), (0.72, 0.44, 0.98), (0.28, 0.12, 0.46)
        # Sculpted against art/ref3d/turn/babydragon.png: a chubby dragon that SITS upright. Big head with a short
        # wide snout, a brow over each eye, frills sweeping back from the cheeks, gold horns curving up and back, a
        # cream belly, small arms resting in front, big hind feet, small wings, a tail curling round to the front.
        body = ball("Body", (0, 0.16, 0.68), 0.58, V_D, (1.04, 1.0, 1.12), color2=V, k=0.14)
        patch(body, (0, -1, 0.05), 0.42, BELLY, (0.95, 1.25), lift=0.012, name="Belly")
        for s in (-1, 1):
            ball(f"Haunch{s}", (s * 0.5, 0.16, 0.4), 0.4, V_D, (0.92, 1.1, 1.0), color2=V, k=0.12)
            ball(f"Foot{s}", (s * 0.52, -0.4, 0.14), 0.22, V, (1.0, 1.5, 0.66), color2=V_L, k=0.05)
            for j in (-1, 0, 1):
                cone(f"Claw{s}{j}", (s * 0.52 + j * 0.11, -0.74, 0.09), 0.05, 0.16, HORN_L, (rad(100), 0, 0), verts=8, role="hard")
            limb(f"Arm{s}", (s * 0.36, -0.3, 1.0), (s * 0.24, -0.54, 0.64), 0.16, 0.13, V, color2=V_L, k=0.08)
            ball(f"Hand{s}", (s * 0.24, -0.58, 0.6), 0.15, V_L, k=0.05)
        HZ, HY = 1.7, -0.1
        head = K.head("Head", (0, HY, HZ), 0.52, V_D, V, wide=1.06, cheeks=0.52, cheek_drop=0.36, jaw=0.3, brow=0.26, back=0.3)
        snout = ball("Snout", (0, HY - 0.44, HZ - 0.2), 0.26, V_L, (1.18, 1.0, 0.74), k=0.13)
        ball("SnoutTip", (0, HY - 0.62, HZ - 0.16), 0.15, V_L, (1.3, 0.9, 0.8), k=0.1)
        K.smile(snout, -0.6, 0.15, skin=V_L)
        K.eyes(head, 0.44, -0.02, 0.14, iris=IRIS, iris_dark=IRIS_D, tall=1.22, socket=0.04)
        for s in (-1, 1):
            patch(snout, (s * 0.4, -1, 0.5), 0.03, V_D, (1.0, 1.3), lift=0.016, name="Nostril", lit=False)
            cone(f"Fang{s}", (s * 0.12, HY - 0.6, HZ - 0.4), 0.035, 0.1, (1, 1, 1), (rad(180), 0, 0), verts=8, role="hard")
            # horns: curving up and back, thick at the root
            rope(f"Horn{s}", [(s * 0.27, HY + 0.02, HZ + 0.4), (s * 0.4, HY + 0.12, HZ + 0.7), (s * 0.4, HY + 0.3, HZ + 0.92), (s * 0.3, HY + 0.44, HZ + 1.0)],
                 [0.14, 0.12, 0.09, 0.03], HORN, HORN_L, n=14, k=0.04)
            # cheek frills: three soft fins sweeping back
            for j, (tx, ty, tz, r) in enumerate(((0.84, 0.22, 0.06, 0.16), (0.8, 0.26, -0.2, 0.15), (0.64, 0.22, -0.42, 0.13))):
                limb(f"Frill{s}{j}", (s * 0.44, HY + 0.02, HZ + tz * 0.6 - 0.04), (s * tx, HY + ty, HZ + tz), r, 0.03, V_D, color2=V_L, k=0.06)
            wing(s, (s * 0.38, 0.52, 1.2), [(0.84, 0.62, 1.74), (1.2, 0.7, 1.4), (1.08, 0.66, 0.98), (0.64, 0.58, 0.84)], V_D, V_L)
        # crest down the back of the head and the spine
        for i, (y, z, h) in enumerate(((HY + 0.2, HZ + 0.5, 0.26), (HY + 0.46, HZ + 0.26, 0.26), (0.62, 1.22, 0.24), (0.74, 0.86, 0.22))):
            cone(f"Spike{i}", (0, y, z), 0.13, h, HORN, (rad(-36), 0, 0), top=0.02, scale=(0.6, 1, 1), color2=HORN_L, k=0.05)
        rope("Tail", [(0, 0.7, 0.36), (-0.56, 0.84, 0.28), (-0.94, 0.48, 0.25), (-0.98, 0.0, 0.3), (-0.82, -0.3, 0.46)],
             [0.3, 0.24, 0.18, 0.12, 0.07], V_D, V, n=24)
        K.leaf("TailTip", (-0.8, -0.3, 0.46), (-0.7, -0.46, 0.84), 0.16, HORN, HORN_L, thick=0.07, up=(0, 1, 0))
        K.finish("pet_babydragon", out, triangles=8500)
    else:
        # VOID DRAKE: its own body since 2026-11-23 (it was the Baby Dragon in dark paint, and the outside judge called
        # it a copy). Sculpted against art/ref3d/turn/voiddrake.png. It sits like a proud cat on planted front legs:
        # a slim upright chest with a gold collar and a glowing gem, a crown of spiky scales round the head, thick
        # ram horns that curl in at the tips, a glowing blade on the brow, HUGE bat wings held high and wide (gold
        # arm, scalloped edge, glowing stars in the skin), and a long spiked tail sweeping out to one side that ends
        # in a gold blade. The stars, the gem and the blade are the only glowing pieces: they are what says "rare".
        V, V_D, V_L, BELLY, GOLD, GOLD_L = (0.27, 0.13, 0.42), (0.15, 0.07, 0.27), (0.50, 0.30, 0.80), (0.90, 0.80, 0.66), (0.80, 0.60, 0.26), (1.0, 0.88, 0.5)
        IRIS, IRIS_D, GLOW, STAR, SKIN = (0.82, 0.50, 1.0), (0.30, 0.10, 0.52), (0.66, 0.30, 1.0), (1.0, 0.95, 0.84), (0.66, 0.40, 0.95)
        body = ball("Body", (0, 0.24, 0.6), 0.5, V_D, (1.05, 1.05, 1.0), color2=V, k=0.14)
        chest = ball("Chest", (0, -0.08, 1.0), 0.42, V_D, (0.95, 0.9, 1.12), color2=V, k=0.14)
        patch(chest, (0, -1, -0.35), 0.3, BELLY, (0.85, 1.5), lift=0.012, name="Belly")
        for s in (-1, 1):
            ball(f"Haunch{s}", (s * 0.5, 0.26, 0.42), 0.38, V_D, (0.9, 1.1, 1.0), color2=V, k=0.12)
            ball(f"Foot{s}", (s * 0.6, -0.22, 0.13), 0.2, V_D, (1.0, 1.5, 0.66), color2=V, k=0.05)
            limb(f"Foreleg{s}", (s * 0.25, -0.26, 1.02), (s * 0.27, -0.5, 0.26), 0.18, 0.15, V, color2=V_D, k=0.08)
            ball(f"Paw{s}", (s * 0.27, -0.58, 0.13), 0.17, V_D, (1.0, 1.3, 0.7), color2=V, k=0.05)
            for j in (-1, 0, 1):
                cone(f"Claw{s}{j}", (s * 0.6 + j * 0.1, -0.54, 0.08), 0.045, 0.15, GOLD_L, (rad(100), 0, 0), verts=8, role="hard")
                cone(f"PawClaw{s}{j}", (s * 0.27 + j * 0.085, -0.8, 0.08), 0.04, 0.13, GOLD_L, (rad(100), 0, 0), verts=8, role="hard")
        HZ, HY = 1.78, -0.2
        head = K.head("Head", (0, HY, HZ), 0.5, V_D, V, wide=1.06, cheeks=0.5, cheek_drop=0.36, jaw=0.3, brow=0.26, back=0.3)
        snout = ball("Snout", (0, HY - 0.42, HZ - 0.2), 0.25, V, (1.15, 1.0, 0.72), color2=V_L, k=0.13)
        ball("SnoutTip", (0, HY - 0.6, HZ - 0.16), 0.14, V, (1.3, 0.9, 0.8), k=0.1)
        ball("Chin", (0, HY - 0.4, HZ - 0.37), 0.19, BELLY, (1.1, 1.0, 0.6), k=0.09)
        K.smile(snout, -0.6, 0.15, skin=V)
        K.eyes(head, 0.44, -0.02, 0.15, iris=IRIS, iris_dark=IRIS_D, tall=1.22, socket=0.04)
        for s in (-1, 1):
            patch(snout, (s * 0.4, -1, 0.5), 0.03, V_D, (1.0, 1.3), lift=0.016, name="Nostril", lit=False)
            cone(f"Fang{s}", (s * 0.12, HY - 0.58, HZ - 0.4), 0.035, 0.1, (1, 1, 1), (rad(180), 0, 0), verts=8, role="hard")
            # ram horns: out from the side of the head, up, and curling in at the tip
            rope(f"Horn{s}", [(s * 0.3, HY + 0.06, HZ + 0.4), (s * 0.6, HY + 0.14, HZ + 0.52), (s * 0.76, HY + 0.2, HZ + 0.8), (s * 0.64, HY + 0.2, HZ + 1.06), (s * 0.46, HY + 0.14, HZ + 1.12)],
                 [0.18, 0.17, 0.13, 0.08, 0.03], GOLD, GOLD_L, n=18, k=0.04)
            # the crown of spiky scales round the back of the head
            # (two rows of short fat scales, the back row in the gaps of the front row: shaggy, not needles)
            for j, (ang, back, reach) in enumerate(((-32, 0.0, 0.8), (2, 0.0, 0.84), (34, 0.0, 0.8), (-14, 0.2, 0.7), (20, 0.2, 0.7))):
                ca, sa = math.cos(rad(ang)), math.sin(rad(ang))
                limb(f"Mane{s}{j}", (s * ca * 0.34, HY + 0.14 + back, HZ + 0.06 + sa * 0.34), (s * ca * reach, HY + 0.4 + back, HZ + 0.06 + sa * reach), 0.2, 0.045, V_D, color2=V_L, k=0.07)
            # wing: every point lies in one slanted plane (y = 0.36 + 0.22 x), so skin, bones and stars sit flush
            def wp(x, z, lift=0.0):
                return (s * x, 0.36 + 0.22 * x + lift, z)
            root, wrist = wp(0.3, 1.3), wp(1.25, 2.34)
            tips = [wp(1.95, 2.02), wp(2.02, 1.36), wp(1.55, 0.8), wp(0.86, 0.7)]
            rim = []
            for i, t in enumerate(tips):
                rim.append(t)
                if i < len(tips) - 1:
                    n = tips[i + 1]
                    mid = [(t[j] + n[j]) / 2 for j in range(3)]
                    rim.append(tuple(mid[j] + (wrist[j] - mid[j]) * 0.22 for j in range(3)))   # the skin dips in between two fingers
            pts = [wrist] + rim + [root]
            K.sheet(f"Wing{s}", pts, [(0, i, i + 1) for i in range(1, len(pts) - 1)], SKIN, 0.06, color2=V)
            limb(f"WingArm{s}", root, wrist, 0.11, 0.085, GOLD, role="hard", verts=10, color2=GOLD_L)
            limb(f"WingHook{s}", wrist, wp(1.12, 2.66), 0.085, 0.02, GOLD, role="hard", verts=8, color2=GOLD_L)
            for i, t in enumerate(tips):
                limb(f"WingBone{s}{i}", wrist, t, 0.075 if i == 0 else 0.055, 0.025, GOLD if i == 0 else V_D, role="hard", verts=8, cap=False)
            # stars in the wing skin: flat four-point stars that stand a little proud on both sides and glow
            for j, (x, z, R) in enumerate(((1.62, 1.52, 0.26), (1.2, 1.16, 0.14), (1.78, 1.9, 0.12))):
                c = wp(x, z)
                star = [c]
                for a in range(8):
                    r = R if a % 2 == 0 else R * 0.3
                    dx, dz = math.cos(rad(a * 45 + 90)) * r, math.sin(rad(a * 45 + 90)) * r
                    star.append(wp(x + dx, z + dz))
                K.sheet(f"Star{s}{j}", star, [(0, i, i % 8 + 1) for i in range(1, 9)], STAR, 0.11, role="glow")
        # spikes down the back of the head and the spine, between the wings
        for i, (y, z, h) in enumerate(((HY + 0.22, HZ + 0.5, 0.28), (HY + 0.48, HZ + 0.24, 0.28), (0.4, 1.36, 0.26), (0.6, 1.0, 0.24), (0.74, 0.66, 0.22))):
            cone(f"Spike{i}", (0, y, z), 0.12, h, V_L, (rad(-40), 0, 0), top=0.02, scale=(0.6, 1, 1), color2=GOLD_L, k=0.05)
        # gold collar with the gem, and the blade on the brow
        patch(chest, (0, -1, 0.3), 0.4, GOLD, (1.2, 0.2), lift=0.02, name="Collar", color2=GOLD_L)
        ball("ChestGem", (0, -0.5, 1.04), 0.11, GLOW, (0.85, 0.5, 1.35), role="glow", seg=8)
        ball("BrowBlade", (0, HY - 0.36, HZ + 0.52), 0.15, GLOW, (0.5, 0.4, 1.6), rot=(rad(-25), 0, 0), role="glow", seg=8)
        # tail: long, out to its left and round to the front, spikes on top, a gold blade at the end
        tail = [(0, 0.66, 0.36), (0.5, 0.92, 0.26), (1.0, 0.62, 0.22), (1.22, 0.12, 0.26), (1.16, -0.36, 0.42), (0.96, -0.58, 0.74)]
        rope("Tail", tail, [0.28, 0.23, 0.18, 0.13, 0.09, 0.05], V_D, V, n=28)
        for i, (x, y, z) in enumerate(tail[1:4]):
            cone(f"TailSpike{i}", (x, y, z + 0.2 - i * 0.03), 0.09, 0.22, V_L, (0, 0, 0), top=0.02, scale=(0.6, 1, 1), color2=GOLD_L, k=0.04)
        K.leaf("TailBlade", tail[-1], (0.8, -0.72, 1.18), 0.2, GOLD, GOLD_L, thick=0.07, up=(0, 1, 0))
        K.finish("pet_voiddrake", out, triangles=8600)

else:
    raise SystemExit("unknown pet kind: " + kind)
