"""The pets as painted models, one per run. All share one cute build (big head, big shiny eyes, small body) so
they read as one family; ears, horns, wings, tails and colours make each kind. Front faces -Y, about 2 studs tall.
Run: blender -b -P pets.py -- out.fbx <kind>     kinds: see KINDS below (lower-case pet ids from Config.Pets)"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import smooth  # noqa: E402

W = (1, 1, 1)
args = sys.argv[sys.argv.index("--") + 1:]
out, kind = os.path.abspath(args[0]), args[1]
lib.reset()
paint.setup()


def flat(obj, color):
    return paint.paint(smooth(obj), None, color)


def ball(name, r, pos, color, scale=(1, 1, 1), seg=16):
    o = lib.sphere(name, r, pos, W, segments=seg)
    o.scale = scale
    return flat(o, color)


def cone(name, r, h, pos, color, rot=(0, 0, 0), top=0.0, verts=10):
    o = lib.cone(name, r, h, pos, W, vertices=verts, radius_top=top)
    o.rotation_euler = rot
    return flat(o, color)


def eyes(z=1.5, y=-0.62, spread=0.3, r=0.2, glow=None):
    for side in (-1, 1):
        if glow:
            paint.glow(lib.sphere(f"Eye{side}", r, (side * spread, y, z), W, segments=10), glow)
        else:
            ball(f"EyeW{side}", r, (side * spread, y, z), (1, 1, 1), seg=10)
            ball(f"Pupil{side}", r * 0.62, (side * spread, y - r * 0.55, z), (0.07, 0.05, 0.08), seg=8)
            ball(f"Shine{side}", r * 0.22, (side * spread - r * 0.25, y - r * 0.95, z + r * 0.3), (1, 1, 1), seg=6)


def body(color, belly=None, head_r=0.8):
    ball("Body", 0.6, (0, 0.05, 0.55), color, (1, 1, 0.95))
    ball("Head", head_r, (0, -0.05, 1.45), color)
    if belly:
        ball("Belly", 0.42, (0, -0.25, 0.5), belly, (1, 0.6, 1))
    for side in (-1, 1):
        ball(f"Foot{side}", 0.2, (side * 0.3, -0.2, 0.12), color, (1, 1.3, 0.7), 8)


def ears(color, inner=None, h=0.6, spread=0.5, tilt=18, r=0.26):
    for side in (-1, 1):
        cone(f"Ear{side}", r, h, (side * spread, 0, 2.15), color, (0, math.radians(side * tilt), 0))
        if inner:
            cone(f"EarIn{side}", r * 0.55, h * 0.7, (side * spread, -0.1, 2.12), inner, (0, math.radians(side * tilt), 0))


def wings(color, span=0.9, z=1.0):
    for side in (-1, 1):
        o = lib.box(f"Wing{side}", (span, 0.06, 0.6), (side * (0.45 + span / 2), 0.3, z), W,
                    rotation=(0, math.radians(side * -28), math.radians(side * 18)))
        paint.paint(o, None, color)
        cone(f"WingTip{side}", 0.12, 0.4, (side * (0.5 + span), 0.34, z + 0.45), color, (0, math.radians(side * -40), 0), verts=6)


def tail(color, tip=None, length=0.9, glow=None):
    cone("Tail", 0.2, length, (0, 0.75, 0.6), color, (math.radians(-55), 0, 0))
    if glow:
        paint.glow(lib.sphere("TailTip", 0.24, (0, 1.15, 0.95), W, segments=8), glow)
    elif tip:
        ball("TailTip", 0.22, (0, 1.15, 0.95), tip, seg=8)


def horns(color, h=0.45, spread=0.32):
    for side in (-1, 1):
        cone(f"Horn{side}", 0.11, h, (side * spread, 0.05, 2.25), color, (0, math.radians(side * 20), 0), verts=8)


GREEN, MOSS = (0.45, 0.85, 0.45), (0.38, 0.62, 0.3)
if kind == "slimey":
    ball("Body", 0.95, (0, 0, 0.75), GREEN, (1, 1, 0.8), 18)
    eyes(z=0.95, y=-0.78, spread=0.3, r=0.22)
    paint.glow(lib.sphere("Shine", 0.16, (-0.35, -0.5, 1.3), W, segments=8), (1, 1, 0.9))
elif kind == "leafling":
    body((0.5, 0.78, 0.35), (0.8, 0.92, 0.6))
    eyes()
    cone("Stem", 0.06, 0.5, (0, 0, 2.4), (0.3, 0.55, 0.2))
    for side in (-1, 1):
        ball(f"Leaf{side}", 0.42, (side * 0.38, 0, 2.6), (0.3, 0.7, 0.25), (1, 0.5, 0.25), 10)
elif kind == "stonepup":
    body((0.62, 0.6, 0.58), (0.78, 0.76, 0.72))
    eyes()
    for side in (-1, 1):
        ball(f"Ear{side}", 0.3, (side * 0.72, 0, 1.7), (0.48, 0.46, 0.45), (0.6, 0.5, 1.3), 10)
        ball(f"Moss{side}", 0.25, (side * 0.3, 0.3, 2.1), MOSS, (1.2, 1, 0.5), 8)
    ball("Nose", 0.11, (0, -0.83, 1.33), (0.15, 0.13, 0.13), seg=8)
    tail((0.48, 0.46, 0.45), length=0.6)
elif kind == "mosskitten":
    body((0.93, 0.88, 0.78), (1, 0.97, 0.9))
    eyes()
    ears((0.93, 0.88, 0.78), (0.95, 0.65, 0.7))
    ball("Moss", 0.55, (0, 0.3, 1.0), MOSS, (1.1, 1.1, 0.7), 10)
    ball("Flower", 0.14, (0.25, -0.1, 2.25), (1.0, 0.6, 0.75), seg=8)
    ball("Nose", 0.08, (0, -0.84, 1.36), (0.95, 0.55, 0.6), seg=8)
    tail((0.93, 0.88, 0.78), MOSS)
elif kind == "glowbug":
    body((0.35, 0.3, 0.25), (0.6, 0.5, 0.3))
    eyes()
    wings((0.9, 0.95, 1.0), 0.7, 1.3)
    paint.glow(lib.sphere("Lamp", 0.5, (0, 0.6, 0.55), W, segments=12), (1.0, 0.92, 0.35))
    for side in (-1, 1):
        cone(f"Feeler{side}", 0.04, 0.5, (side * 0.25, -0.2, 2.35), (0.2, 0.18, 0.15), (0, math.radians(side * 25), 0), verts=6)
elif kind == "emberfox":
    body((1.0, 0.55, 0.2), (1, 0.95, 0.85))
    eyes()
    ears((1.0, 0.55, 0.2), (0.25, 0.15, 0.1), h=0.7)
    cone("Snout", 0.28, 0.4, (0, -0.85, 1.3), (1, 0.95, 0.85), (math.radians(90), 0, 0))
    ball("Nose", 0.09, (0, -1.07, 1.3), (0.12, 0.1, 0.1), seg=8)
    tail((1.0, 0.55, 0.2), glow=(1.0, 0.55, 0.12), length=1.1)
elif kind == "minigolem":
    body((0.45, 0.38, 0.36), None)
    eyes(glow=(1.0, 0.6, 0.2), r=0.15)
    paint.glow(lib.sphere("Core", 0.25, (0, -0.52, 0.6), W, segments=10), (1.0, 0.5, 0.15))
    for side in (-1, 1):
        ball(f"Arm{side}", 0.3, (side * 0.75, 0, 0.55), (0.38, 0.32, 0.3), (0.8, 0.8, 1.3), 8)
        ball(f"Rock{side}", 0.25, (side * 0.4, 0.1, 2.2), (0.38, 0.32, 0.3), seg=6)
elif kind in ("babydragon", "voiddrake", "phoenix"):
    col, belly, wing, horn = {
        "babydragon": ((0.62, 0.3, 0.85), (0.9, 0.8, 1.0), (0.42, 0.18, 0.6), (1.0, 0.85, 0.4)),
        "voiddrake": ((0.14, 0.1, 0.26), (0.3, 0.2, 0.5), (0.22, 0.12, 0.42), (0.75, 0.5, 1.0)),
        "phoenix": ((1.0, 0.45, 0.12), (1.0, 0.85, 0.35), (1.0, 0.7, 0.15), (1.0, 0.9, 0.4)),
    }[kind]
    body(col, belly)
    if kind == "voiddrake":
        eyes(glow=(0.8, 0.55, 1.0), r=0.17)
        for i, (x, y, z) in enumerate(((1.1, 0.33, 1.15), (0.85, 0.3, 0.85), (-1.1, 0.33, 1.15), (-0.85, 0.3, 0.85))):
            paint.glow(lib.sphere(f"Star{i}", 0.07, (x, y - 0.06, z), W, segments=6), (0.85, 0.7, 1.0))
    else:
        eyes()
    wings(wing, 0.95)
    if kind == "phoenix":
        cone("Beak", 0.16, 0.35, (0, -0.9, 1.35), (1.0, 0.8, 0.2), (math.radians(90), 0, 0))
        for i in range(3):
            cone(f"Crest{i}", 0.1, 0.5, ((i - 1) * 0.2, 0.1, 2.3), (1.0, 0.8, 0.2), (math.radians(20), math.radians((i - 1) * 20), 0), verts=6)
        tail(col, glow=(1.0, 0.6, 0.1), length=1.2)
    else:
        horns(horn)
        cone("Snout", 0.3, 0.35, (0, -0.8, 1.3), col, (math.radians(90), 0, 0), top=0.2)
        tail(col, glow=(0.8, 0.55, 1.0) if kind == "voiddrake" else None, tip=horn)
elif kind == "crystalowl":
    body((0.7, 0.86, 1.0), (0.95, 0.98, 1.0), head_r=0.85)
    eyes(r=0.26, spread=0.33)
    cone("Beak", 0.1, 0.25, (0, -0.85, 1.3), (1.0, 0.8, 0.3), (math.radians(90), 0, 0), verts=6)
    ears((0.5, 0.75, 1.0), h=0.45, spread=0.55, tilt=30, r=0.18)
    wings((0.5, 0.75, 1.0), 0.6, 0.8)
    for i in range(3):
        paint.glow(lib.cone(f"Shard{i}", 0.1, 0.4, ((i - 1) * 0.3, 0.55, 1.0 + i % 2 * 0.3), W, vertices=6), (0.6, 0.9, 1.0))
elif kind == "starunicorn":
    body((1.0, 0.98, 1.0), None)
    eyes()
    ears((1.0, 0.98, 1.0), (1.0, 0.75, 0.85), h=0.45, spread=0.55, r=0.18)
    paint.glow(lib.cone("Horn", 0.12, 0.75, (0, -0.25, 2.5), W, vertices=8), (1.0, 0.85, 0.35))
    cone("Snout", 0.32, 0.35, (0, -0.8, 1.28), (1.0, 0.9, 0.95), (math.radians(90), 0, 0), top=0.24)
    for i, col in enumerate(((1.0, 0.6, 0.75), (1.0, 0.85, 0.5), (0.6, 0.9, 0.7), (0.55, 0.75, 1.0), (0.8, 0.6, 1.0))):
        ball(f"Mane{i}", 0.24, (0, 0.5 + i * 0.05, 2.1 - i * 0.3), col, seg=8)
    tail((1.0, 0.6, 0.75), (0.55, 0.75, 1.0))

parts = paint.bake("pet_" + kind, out[:-4] + "_paint.png", 256)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
