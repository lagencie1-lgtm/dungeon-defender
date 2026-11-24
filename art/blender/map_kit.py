"""The battle maps' building kit (2026-11-24, Lemp: "much more obstacles and environment", like Dungeon Defenders):
ruined walls, a gate arch over the lane, broken pillars, bridge parapets and one set piece per map, in three
themes that share the shapes and differ in paint:
  forest   pale mossy masonry          magma   dark basalt with lava seams and iron      crystal  violet rune stone, crystals
Pieces (front faces -Y, the long side runs along X, studs):
  wall      a ruined wall run, 14 long, stepping down from 5.5 to 2.5 high, rubble at its foot
  low       a low battlement, 12 long, 2.4 high with merlons (the rim of raised ground; a hero can jump it)
  arch      a gate over the lane: two piers 14 apart and a ring of arch stones, 15 high
  pillar    a broken column, 6.5 high, its top drum lying beside it
  bridge    a plank deck 15 x 16 with a stone parapet and end posts on each side (lies on the lane across a channel)
  set       the theme's own piece: a trilithon of standing stones / a fire brazier / a crystal cart on its rails
  face      a retaining wall for the edge of raised ground: 12 long, big stones from 1.5 below the ground to a coping
            at 5.5 (the top of ground raised 5; sink it by 1 for ground raised 4)
  stairs    stone steps up raised ground: 7 wide, five steps to 5 high over a run of 6.5, cheek walls; the top step
            is at the origin, the steps come down towards the front
Run: blender -b -P map_kit.py -- out.fbx <piece> <theme>
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel  # noqa: E402

W = (1, 1, 1)
args = sys.argv[sys.argv.index("--") + 1:]
out, piece, theme = os.path.abspath(args[0]), args[1], args[2]
rnd = random.Random({"forest": 11, "magma": 23, "crystal": 37}[theme] + len(piece))
lib.reset()
paint.setup()

THEMES = {
    "forest": {"stone": ("stone", (0.86, 0.9, 0.86), 6.0), "cap": ("leaves", (0.8, 1.0, 0.72), 2.0),
               "trim": ("wood_dark", W, 1.6), "glow": None},
    "magma": {"stone": ("basalt", (1.0, 0.94, 0.9), 6.0), "cap": ("iron", (0.8, 0.76, 0.74), 2.0),
              "trim": ("iron", (0.75, 0.72, 0.7), 1.6), "glow": (1.0, 0.45, 0.12)},
    "crystal": {"stone": ("rune_stone", (0.98, 0.96, 1.02), 6.0), "cap": ("t_cave_wall", (1.15, 1.12, 1.2), 3.0),
                "trim": ("wood_dark", (0.8, 0.78, 0.9), 1.6), "glow": (0.45, 0.9, 1.0)},
}
T = THEMES[theme]
n_made = 0


def stone(obj, kind="stone", shade=1.0):
    key, tint, scale = T[kind]
    return paint.paint(obj, key, tuple(c * shade for c in tint), scale)


def block(size, at, kind="stone", turn=0.0, tilt=(0, 0), round_=0.1):
    """one dressed stone: a bevelled box with a little shade variation so courses read as single stones"""
    global n_made
    n_made += 1
    b = lib.box(f"B{n_made}", size, at, W, rotation=(tilt[0], tilt[1], turn))
    if round_ > 0:
        bevel(b, round_, 1)
    return stone(b, kind, rnd.uniform(0.9, 1.06))


def course_wall(length, thick, height_at, y=0.0, x0=None, gap=None, z0=0.0, big=1.0):
    """Masonry in courses: `height_at(x)` gives the ragged top line. `gap(x)` true leaves a hole (a doorway).
    `big` scales the stones (retaining walls are built of large blocks), `z0` is where the lowest course starts."""
    x0 = -length / 2 if x0 is None else x0
    z, row = z0, 0
    while True:
        h = rnd.uniform(0.85, 1.05) * big
        x = x0 - (rnd.uniform(0.6, 1.2) * big if row % 2 else 0.0)
        any_stone = False
        while x < x0 + length:
            w = rnd.uniform(1.5, 2.5) * big
            mid = min(max(x + w / 2, x0), x0 + length)
            left, right = max(x, x0), min(x + w, x0 + length)
            if right - left > 0.5 and z + h * 0.6 < height_at(mid) and not (gap and gap(mid, z)):
                d = thick * rnd.uniform(0.94, 1.06)
                block((right - left - 0.04, d, h - 0.04), ((left + right) / 2, y + rnd.uniform(-0.05, 0.05), z + h / 2))
                any_stone = True
            x += w
        z += h
        row += 1
        if not any_stone or z > 20:
            break


def rubble(count, spread_x, spread_y, y0=0.0, kind="stone"):
    for _ in range(count):
        r = rnd.uniform(0.35, 0.8)
        block((r * 1.9, r * 1.4, r), (rnd.uniform(-spread_x, spread_x), y0 + rnd.uniform(-spread_y, spread_y), r * 0.42), kind,
              turn=rnd.uniform(0, 3), tilt=(rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)), round_=0.12)


def moss(at, size):
    """a soft cap lying on top of stones (forest: moss; crystal: a crust of cave rock; magma: an iron cap plate)"""
    global n_made
    n_made += 1
    if theme == "magma":
        return block((size[0], size[1], 0.22), (at[0], at[1], at[2] + 0.05), "cap", round_=0.04)
    # two or three soft cushions that hang a little over the edge
    last = None
    for k in range(3):
        m = lib.sphere(f"M{n_made}_{k}", 1.0, (at[0] + rnd.uniform(-0.35, 0.35) * size[0], at[1] + rnd.uniform(-0.3, 0.3) * size[1],
                                                 at[2] - 0.12), W, segments=8)
        m.scale = (size[0] * rnd.uniform(0.32, 0.5), size[1] * rnd.uniform(0.4, 0.58), size[2] * rnd.uniform(1.4, 2.2))
        last = stone(m, "cap", rnd.uniform(0.85, 1.05))
    return last


def shard(at, height, radius, lean=(0.0, 0.0), glow=False):
    """a crystal (crystal theme) : a six-sided spike"""
    global n_made
    n_made += 1
    c = lib.cone(f"S{n_made}", radius, height, (at[0], at[1], at[2] + height / 2), W, vertices=6, radius_top=radius * 0.12)
    c.rotation_euler = (lean[0], lean[1], rnd.uniform(0, 1))
    if glow:
        return paint.glow(c, T["glow"])
    return paint.paint(c, "crystal", (0.9, 1.0, 1.05), 2.0)


def seam(at, length):
    """a glowing lava crack (magma) on a wall's front face: three short strokes that zigzag downwards"""
    global n_made
    x, y, z = at
    angle = rnd.uniform(-0.5, 0.5)
    last = None
    for k in range(3):
        n_made += 1
        step = length * rnd.uniform(0.28, 0.4)
        angle = -angle * rnd.uniform(0.6, 1.2) + rnd.uniform(-0.25, 0.25)
        dx, dz = math.sin(angle) * step, -math.cos(angle) * step
        last = paint.glow(lib.box(f"G{n_made}", (0.13, 0.1, step + 0.08), (x + dx / 2, y, z + dz / 2), W, rotation=(0, -angle, 0)), T["glow"])
        x, z = x + dx, z + dz
    return last


def theme_touches(points, front=0.9):
    """the theme's own accents at a few given spots (x, y, z on top of stone)"""
    for i, (x, y, z) in enumerate(points):
        if theme == "forest":
            moss((x, y, z), (rnd.uniform(1.6, 2.6), rnd.uniform(1.4, 2.0), 0.28))
        elif theme == "magma":
            if i % 2 == 0:
                seam((x + rnd.uniform(-0.4, 0.4), y - front - 0.02, z - rnd.uniform(0.5, 1.0)), rnd.uniform(1.8, 2.6))
        else:
            shard((x, y, z - 0.2), rnd.uniform(1.2, 2.4), rnd.uniform(0.3, 0.5), (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3)),
                  glow=(i % 3 == 0))


if piece == "wall":
    def top(x):
        # tall at the left end, a bite out of the middle, low at the right end
        t = (x + 7) / 14
        return 5.6 - 3.0 * t - (1.1 if 0.42 < t < 0.6 else 0.0) + (0.5 if t < 0.12 else 0.0)
    course_wall(14, 1.8, top)
    # a buttress on the back at the tall end and a footing course in front
    block((1.6, 1.4, 3.4), (-5.6, 1.3, 1.7))
    block((1.9, 1.0, 1.6), (-5.6, 2.2, 0.8))
    for x in (-5.2, -1.6, 2.0, 5.4):
        block((3.3, 0.5, 0.5), (x, -1.05, 0.25), round_=0.08)
    rubble(7, 6.5, 1.0, y0=-1.9)
    rubble(3, 3.0, 0.6, y0=1.6)
    theme_touches([(-5.5, 0, 5.9), (-2.4, 0, 4.9), (2.6, 0, 3.6), (5.6, 0, 2.8)])
elif piece == "low":
    course_wall(12, 1.4, lambda x: 1.75)
    for i, x in enumerate((-5.1, -2.55, 0.0, 2.55, 5.1)):
        if not (theme == "forest" and i == 3):  # one merlon has fallen in the forest
            block((1.5, 1.5, 0.85), (x, 0, 2.2), round_=0.1)
    if theme == "forest":
        block((1.5, 1.4, 0.8), (3.2, -1.6, 0.4), turn=0.5, tilt=(0.2, 0.1))
    theme_touches([(-5.1, 0, 2.65), (0, 0, 2.65), (5.1, 0, 2.65)], front=0.75)
elif piece == "arch":
    half, pier = 8.6, 3.2   # pier centres; inner faces 14 apart
    for side in (-1, 1):
        course_wall(pier, pier, lambda x: 8.6, x0=side * half - pier / 2)
        block((pier + 0.7, pier + 0.7, 0.7), (side * half, 0, 0.35), round_=0.12)       # plinth
        block((pier + 0.5, pier + 0.5, 0.6), (side * half, 0, 8.7), round_=0.12)        # impost
    # the ring: 13 arch stones on a half circle whose feet stand on the imposts
    n, radius, spring = 13, half, 9.0
    for k in range(n):
        a = math.pi * (k + 0.5) / n
        tx, tz = -radius * math.sin(a), 0.62 * radius * math.cos(a)   # the curve's direction here
        block((math.hypot(tx, tz) * math.pi / n + 0.1, 2.6, 1.9), (radius * math.cos(a), 0, spring + radius * 0.62 * math.sin(a)),
              tilt=(0, -math.atan2(tz, tx)), round_=0.12)
    block((2.3, 2.9, 2.5), (0, 0, spring + radius * 0.62 + 0.3), round_=0.14)             # keystone
    rubble(5, 11.5, 1.2, y0=-2.6)
    if theme == "forest":
        rubble(2, 2.0, 0.5, y0=2.3)
    theme_touches([(-half, 0, 9.2), (half, 0, 9.2), (-3.5, 0, 14.4), (3.5, 0, 14.4)], front=1.65)
    if T["glow"]:
        # a lit keystone sign (magma: a lava rune; crystal: a crystal set in the keystone)
        paint.glow(lib.box("Key", (0.9, 0.2, 1.1), (0, -1.5, spring + radius * 0.62 + 0.3), W, rotation=(0, math.pi / 4, 0)), T["glow"])
elif piece == "pillar":
    block((3.0, 3.0, 0.7), (0, 0, 0.35), round_=0.12)
    block((2.5, 2.5, 0.5), (0, 0, 0.95), round_=0.1)
    z = 1.2
    for i in range(5):
        h = rnd.uniform(0.95, 1.15)
        d = lib.cylinder(f"Drum{i}", 1.0 - i * 0.02, h - 0.05, (rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), z + h / 2), W, vertices=12)
        d.rotation_euler = (0, 0, rnd.uniform(0, 1))
        stone(bevel(d, 0.07, 1), "stone", rnd.uniform(0.92, 1.05))
        z += h
    # the broken top: a slanted stub, and the fallen drum beside the foot
    stub = lib.cylinder("Stub", 0.96, 0.7, (0.1, 0, z + 0.25), W, vertices=12)
    stub.rotation_euler = (0.22, 0.1, 0)
    stone(bevel(stub, 0.07, 1))
    fallen = lib.cylinder("Fallen", 0.98, 1.3, (2.6, -1.2, 0.95), W, vertices=12)
    fallen.rotation_euler = (math.pi / 2, 0, 0.7)
    stone(bevel(fallen, 0.07, 1), "stone", 0.95)
    rubble(4, 2.6, 2.4)
    theme_touches([(0.1, 0, z + 0.65), (2.6, -1.2, 1.9)], front=1.0)
elif piece == "bridge":
    # the deck lies on the road (0.12 thick, so walkers' feet stay on top); planks run across the lane
    for i in range(8):
        x = -7.0 + i * 2.0
        pl = lib.box(f"Plank{i}", (1.92, 15.2, 0.12), (x, rnd.uniform(-0.08, 0.08), 0.06), W)
        deck = {"forest": ("wood_dark", (1.25, 1.15, 1.0)), "magma": ("iron", (0.62, 0.58, 0.56)), "crystal": ("wood_dark", (1.0, 1.0, 1.25))}[theme]
        paint.paint(pl, deck[0], tuple(c * rnd.uniform(0.88, 1.0) for c in deck[1]), 2.4)
    for side in (-1, 1):
        y = side * 8.1
        course_wall(16, 1.1, lambda x: 2.1, y=y)
        block((16.6, 1.5, 0.35), (0, y, 2.3), "cap" if theme != "forest" else "stone", round_=0.08)   # coping
        for end in (-1, 1):
            block((1.7, 1.7, 3.3), (end * 8.3, y, 1.65), round_=0.12)
            block((2.0, 2.0, 0.4), (end * 8.3, y, 3.5), round_=0.1)
            if T["glow"]:
                paint.glow(lib.box(f"Lamp{side}{end}", (0.7, 0.7, 0.7), (end * 8.3, y, 4.05), W, rotation=(0, 0, math.pi / 4)), T["glow"])
            elif end == 1:
                moss((end * 8.3, y, 3.75), (1.6, 1.6, 0.25))
elif piece == "set":
    if theme == "forest":
        # a trilithon: two leaning standing stones and a lintel, a fallen third stone, moss
        for side, lean in ((-1, 0.05), (1, -0.07)):
            block((2.0, 1.5, 7.2), (side * 2.6, 0, 3.6), tilt=(0, lean), round_=0.22)
        block((7.8, 1.9, 1.4), (0, 0, 7.8), tilt=(0, 0.03), round_=0.22)
        block((1.8, 1.4, 5.6), (5.6, -1.6, 0.75), turn=0.5, tilt=(0, math.pi / 2 - 0.08), round_=0.22)
        rubble(4, 4.5, 2.0)
        for at, size in (((0, 0, 8.5), (5.5, 1.8, 0.3)), ((-2.6, 0, 7.2), (1.6, 1.4, 0.2)), ((5.6, -1.6, 1.55), (3.6, 1.4, 0.25))):
            moss(at, size)
    elif theme == "magma":
        # a fire brazier: a stepped basalt base, an iron bowl on three legs, glowing coals
        block((3.4, 3.4, 0.6), (0, 0, 0.3), round_=0.12)
        block((2.5, 2.5, 0.6), (0, 0, 0.9), round_=0.1)
        for i in range(3):
            a = i / 3 * math.pi * 2 + 0.3
            leg = lib.box(f"Leg{i}", (0.22, 0.22, 2.4), (math.cos(a) * 0.8, math.sin(a) * 0.8, 2.3), W, rotation=(math.sin(a) * 0.22, -math.cos(a) * 0.22, 0))
            paint.paint(leg, "iron", (0.7, 0.68, 0.66), 1.2)
        bowl = lib.cone("Bowl", 0.7, 1.0, (0, 0, 3.7), W, vertices=10, radius_top=1.55)
        paint.paint(bevel(bowl, 0.05, 1), "iron", (0.72, 0.7, 0.68), 1.4)
        rim = lib.cylinder("Rim", 1.62, 0.2, (0, 0, 4.2), W, vertices=10)
        paint.paint(rim, "iron", (0.85, 0.8, 0.74), 1.2)
        ash = lib.cylinder("Ash", 1.45, 0.12, (0, 0, 4.24), W, vertices=10)
        paint.paint(ash, None, (0.16, 0.13, 0.12))
        for i in range(9):
            a = i * 2.4
            r = 0.36 * math.sqrt(i)
            paint.glow(lib.sphere(f"Coal{i}", rnd.uniform(0.2, 0.3), (math.cos(a) * r, math.sin(a) * r, 4.36), W, segments=6), T["glow"])
    else:
        # a crystal cart: a wooden mine cart heaped with crystals on a short length of rail
        for y in (-1.0, 1.0):
            paint.paint(lib.box(f"Rail{y}", (7.5, 0.22, 0.22), (0, y, 0.33), W), "iron", (0.8, 0.8, 0.86), 1.4)
        for i in range(5):
            paint.paint(lib.box(f"Tie{i}", (0.6, 2.8, 0.22), (-3.0 + i * 1.5, 0, 0.11), W), "wood_dark", (0.85, 0.82, 0.9), 1.4)
        tub = lib.box("Tub", (3.6, 2.4, 1.6), (0, 0, 1.75), W)
        paint.paint(bevel(tub, 0.08, 1), "wood", (0.82, 0.74, 0.78), 1.6)
        for x in (-1.85, 1.85):
            paint.paint(lib.box(f"Band{x}", (0.14, 2.5, 1.7), (x, 0, 1.75), W), "iron", (0.75, 0.75, 0.82), 1.2)
        for y in (-1.25, 1.25):
            paint.paint(lib.box(f"LipX{y}", (3.8, 0.16, 0.18), (0, y, 2.6), W), "iron", (0.8, 0.8, 0.86), 1.2)
        for x in (-1.85, 1.85):
            paint.paint(lib.box(f"LipY{x}", (0.16, 2.6, 0.18), (x, 0, 2.6), W), "iron", (0.8, 0.8, 0.86), 1.2)
        heap = lib.sphere("Heap", 1.0, (0, 0, 2.35), W, segments=8)
        heap.scale = (1.6, 1.05, 0.5)
        paint.paint(heap, "crystal", (0.75, 0.85, 0.95), 2.0)
        for x in (-1.2, 1.2):
            for y in (-1.0, 1.0):
                wheel = lib.cylinder(f"Wheel{x}{y}", 0.55, 0.26, (x, y, 0.95), W, vertices=10, rotation=(math.pi / 2, 0, 0))
                paint.paint(wheel, "iron", (0.62, 0.62, 0.68), 1.0)
        for i in range(7):
            shard((rnd.uniform(-1.2, 1.2), rnd.uniform(-0.7, 0.7), 2.5), rnd.uniform(1.0, 2.0), rnd.uniform(0.3, 0.5),
                  (rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45)), glow=(i % 3 == 0))
        rubble(3, 3.6, 1.8, kind="cap")
elif piece == "face":
    course_wall(12, 1.3, lambda x: 5.05, z0=-1.5, big=1.6)
    # the coping: flat stones that overhang the face a little
    x = -6.0
    while x < 6.0:
        w = min(rnd.uniform(2.6, 3.6), 6.0 - x)
        if w > 0.6:
            block((w - 0.05, 1.75, 0.5), (x + w / 2, -0.12, 5.25), "cap" if theme == "magma" else "stone", round_=0.1)
        x += w
    if theme == "forest":
        moss((rnd.uniform(-4, 4), -0.2, 5.5), (2.6, 1.6, 0.26))
        moss((rnd.uniform(-5, 5), -0.75, 2.4), (1.8, 0.5, 0.5))
    elif theme == "magma":
        seam((rnd.uniform(-3.5, 3.5), -0.69, rnd.uniform(3.4, 4.4)), rnd.uniform(2.2, 3.0))
    else:
        shard((rnd.uniform(-4, 4), -0.5, 5.3), rnd.uniform(1.2, 1.9), 0.38, (rnd.uniform(-0.2, 0.2), -0.25), glow=True)
elif piece == "stairs":
    steps, rise, run = 5, 1.0, 1.3
    for i in range(steps):
        top = 5.0 - i * rise
        # each step is a solid block down to below the ground, a hair narrower than the one above it
        block((6.0, run + 0.04, top + 1.5), (0, -(i + 0.5) * run, (top - 1.5) / 2), round_=0.08)
        if theme != "forest":
            # a paler tread on each step, so the stairs read as stairs on a dark map
            block((5.9, run - 0.1, 0.14), (0, -(i + 0.5) * run - 0.05, top + 0.05), "cap", round_=0.03)
    for side in (-1, 1):
        for i in range(steps):
            top = 5.6 - i * rise
            block((0.9, run + 0.06, top + 1.5), (side * 3.45, -(i + 0.5) * run, (top - 1.5) / 2), "cap" if theme == "magma" else "stone", round_=0.08)
        block((1.2, 1.2, 1.6), (side * 3.45, -steps * run - 0.5, 0.8), round_=0.12)   # newel at the foot
        if T["glow"]:
            paint.glow(lib.box(f"Lamp{side}", (0.6, 0.6, 0.6), (side * 3.45, -steps * run - 0.5, 1.9), W, rotation=(0, 0, math.pi / 4)), T["glow"])
    if theme == "forest":
        moss((3.45, -1.0, 5.55), (0.9, 1.4, 0.2))
else:
    raise SystemExit("unknown piece " + piece)

size = {"wall": 512, "arch": 512, "bridge": 512, "face": 512}.get(piece, 256)
parts = paint.bake(f"mapkit_{piece}_{theme}", out[:-4] + "_paint.png", size)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
