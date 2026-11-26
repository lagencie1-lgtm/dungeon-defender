"""Map trees built the way the towers are (Lemp 2026-11-25: "the trees look really weird - make the map objects with
the same workflow, painterly and blender - right now they look like stupid bubble gum trees").

What made them bubble gum: a crown of perfect spheres in one saturated green, a smooth cone trunk, and shiny plastic
in the game. A painted tree is built differently, and that is what this builds:
  trunk     a gnarled tube with bark ridges, a flared foot whose buttress roots dive into the ground, a slight S
  limbs     tapering tubes that split from the trunk and run up into the crown, visible in the gaps between clumps
  crown     clumps, not balls: each a lumpy dome made of rounded lobes (a cauliflower outline that reads as massed
            leaves), flat and dark underneath, lighter and warmer on top (light from the top-left, art/STYLE.md);
            the clumps sit apart enough that the limbs show between them
Kinds:  oak   the Cursed Forest's round oak, about 17 studs tall (the game scales each one)
        oak_b a broad leaning oak with a wide low crown;  oak_c  a tall narrow oak (three shapes, so a wood
              is not one tree repeated)
        dead  a twisted bare tree with crooked branches in two orders (Forest, and Magma's burnt wood)
        bush  a low leafy bush (the chapel's), saved as keep_field_bush
        crown_test  one clump only (for the look sheet)
Run: blender -b -P tree_painted.py -- out.fbx <kind> [seed]
The paint pass (the painter repainting the model's own views, projected back) comes when the painter has credits
again; until then the painted bark and leaf textures, baked light and occlusion carry it.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import foliage  # noqa: E402
import lib  # noqa: E402
import paint  # noqa: E402

W = (1, 1, 1)
args = sys.argv[sys.argv.index("--") + 1:]
out, kind = os.path.abspath(args[0]), args[1]
seed = int(args[2]) if len(args) > 2 else 7
rnd = random.Random(seed)
lib.reset()
paint.setup()
foliage.setup(rnd, seed)
tube, clump, leaves, bark, limb = foliage.tube, foliage.clump, foliage.leaves, foliage.bark, foliage.limb


def base_tufts(count, radius):
    """grass and moss round the trunk's foot, so it grows out of the ground (the outside judge: trunks "plunge
    straight into the ground without natural blending")"""
    for k in range(count):
        a = k / count * math.tau + rnd.uniform(-0.3, 0.3)
        r = radius * rnd.uniform(0.85, 1.25)
        size = rnd.uniform(0.55, 0.85)
        leaves(clump((math.cos(a) * r, math.sin(a) * r, 0.05), (size * 1.3, size * 1.2, size * 0.7), lobes=7,
                     subdivisions=2, bump=0.4), 0.3, (1.02, 1.12, 0.62), (0.45, 0.68, 0.7))


# the three oaks (the outside judge: "canopies use the exact same stacked shape across the board"), as
# (trunk points, trunk radii, crown clumps: list of (centre, size, height in the crown 0..1))
def oak_shape(shape):
    if shape == "b":
        # broad and leaning: a short trunk bending one way, a wide low crown
        trunk = [(0, 0, -0.6), (0.1, 0, 0.6), (0.45, 0.1, 2.2), (0.9, 0.2, 3.8), (1.35, 0.3, 5.4), (1.6, 0.4, 7.2)]
        radii = [2.2, 1.85, 1.5, 1.25, 1.08, 0.95]
        top = Vector(trunk[-1])
        clumps = [(top + Vector((0, 0, 4.8)), (3.4, 3.2, 2.3), 1.0)]
        for ang in (30, 150, 270, 345):
            a = math.radians(ang + rnd.uniform(-12, 12))
            clumps.append((top + Vector((math.cos(a) * 3.2, math.sin(a) * 3.2, rnd.uniform(3.0, 3.8))),
                           (rnd.uniform(2.8, 3.1), rnd.uniform(2.7, 3.0), rnd.uniform(2.0, 2.3)), 0.8))
        for ang in (0, 60, 120, 180, 240, 300):
            a = math.radians(ang + rnd.uniform(-14, 14))
            clumps.append((top + Vector((math.cos(a) * 5.6, math.sin(a) * 5.4, rnd.uniform(1.2, 2.4))),
                           (rnd.uniform(2.5, 2.9), rnd.uniform(2.4, 2.8), rnd.uniform(1.7, 2.0)), 0.5))
        return trunk, radii, clumps
    if shape == "c":
        # tall and narrow: a long trunk and a crown stacked like a tall oval
        trunk = [(0, 0, -0.6), (0.1, 0, 0.6), (0.3, 0.1, 2.6), (0.1, 0.25, 4.8), (-0.2, 0.15, 7.0), (0.0, 0.0, 9.0),
                 (0.2, -0.1, 10.8)]
        radii = [1.9, 1.6, 1.3, 1.12, 1.0, 0.9, 0.78]
        top = Vector(trunk[-1])
        clumps = [(top + Vector((0, 0, 8.2)), (2.4, 2.3, 2.2), 1.0)]
        for tier, (h, r, n, size) in enumerate(((5.8, 1.9, 3, 2.6), (3.4, 2.3, 4, 2.7), (1.0, 2.6, 4, 2.5))):
            for k in range(n):
                a = k / n * math.tau + tier * 0.7 + rnd.uniform(-0.2, 0.2)
                clumps.append((top + Vector((math.cos(a) * r, math.sin(a) * r, h + rnd.uniform(-0.3, 0.3))),
                               (size * rnd.uniform(0.92, 1.05), size * rnd.uniform(0.9, 1.0), size * 0.8), 0.85 - tier * 0.2))
        return trunk, radii, clumps
    # "a": the round oak, a tall dome
    trunk = [(0, 0, -0.6), (0.1, 0, 0.6), (0.35, 0.1, 2.2), (0.2, 0.25, 4.0), (-0.15, 0.2, 5.8), (0.05, 0.0, 7.4),
             (0.3, -0.15, 8.6)]
    radii = [2.1, 1.75, 1.4, 1.2, 1.08, 0.98, 0.85]
    clumps = [(Vector((0.3, 0.0, 15.2)), (3.0, 2.8, 2.4), 1.0)]
    for ang in (60, 180, 300):
        a = math.radians(ang + rnd.uniform(-15, 15))
        clumps.append((Vector((math.cos(a) * 2.4, math.sin(a) * 2.4, rnd.uniform(12.6, 13.4))),
                       (rnd.uniform(2.7, 3.0), rnd.uniform(2.6, 2.9), rnd.uniform(2.1, 2.4)), 0.8))
    for k, ang in enumerate((20, 95, 165, 240, 315)):
        a = math.radians(ang + rnd.uniform(-12, 12))
        r = rnd.uniform(4.0, 4.5)
        clumps.append((Vector((math.cos(a) * r, math.sin(a) * r, rnd.uniform(9.6, 11.2))),
                       (rnd.uniform(2.4, 2.8), rnd.uniform(2.3, 2.7), rnd.uniform(1.8, 2.1)), 0.45 + 0.08 * k))
    return trunk, radii, clumps


if kind in ("oak", "oak_b", "oak_c", "crown_test"):
    # warm sunlit yellow-green on top, cool blue-green below (the outside judge: "tint top highlights warmer,
    # push inner shadows cooler")
    TOP, BOTTOM = (1.16, 1.12, 0.6), (0.42, 0.66, 0.76)
    if kind == "crown_test":
        leaves(clump((0, 0, 3), (3.2, 3.0, 2.6)), 0.8, TOP, BOTTOM)
    else:
        trunk_pts, trunk_radii, clumps = oak_shape({"oak": "a", "oak_b": "b", "oak_c": "c"}[kind])
        # the trunk: ridged bark, buttress roots at the foot
        bark(tube(trunk_pts, trunk_radii, ring=12, ridges=7, ridge_depth=0.1, flare=(1.6, 5, 0.9)))
        # roots that dive into the ground beside the flare
        for k in range(5):
            a = k / 5 * math.tau + rnd.uniform(-0.25, 0.25)
            d = Vector((math.cos(a), math.sin(a), 0))
            pts = [Vector((0, 0, 1.0)) + d * 0.6, d * 1.8 + Vector((0, 0, 0.55)), d * 2.9 + Vector((0, 0, 0.12)),
                   d * 3.5 + Vector((0, 0, -0.4))]
            bark(tube([tuple(p) for p in pts], [0.55, 0.42, 0.26, 0.1], ring=7, ridges=3, ridge_depth=0.05))
        base_tufts(7, 2.6)
        # the crown: clumps apart enough to show the limbs; each limb runs from the trunk's top into its clump
        top = Vector(trunk_pts[-1])
        for k, (c, size, h) in enumerate(clumps):
            c = Vector(c) + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(-0.2, 0.2)))
            leaves(clump(tuple(c), size, lobes=rnd.randint(13, 18)), h, TOP, BOTTOM)
            if k > 0:
                end = c + Vector((0, 0, -size[2] * 0.25))
                bark(limb(tuple(top + Vector((0, 0, rnd.uniform(-1.2, 0.2)))), tuple(end), 0.62, 0.26))
        # a few twigs that poke out between the clumps (a painted tree never shows a closed shell)
        for k in range(5):
            a = rnd.uniform(0, math.tau)
            s0 = top + Vector((0, 0, rnd.uniform(0.8, 2.6)))
            e = s0 + Vector((math.cos(a) * 4.2, math.sin(a) * 4.2, rnd.uniform(0.6, 1.8)))
            bark(limb(tuple(s0), tuple(e), 0.22, 0.06, bend=0.4))
elif kind == "bush":
    # a low bush of four lobed clumps, painted in the same bands, a few red berries on the light side
    # (lighter than the oak's: a bush sits low, in the shade of walls, and read as a black blob in the first film)
    TOP, BOTTOM = (1.3, 1.38, 0.88), (0.78, 1.0, 0.86)
    for k, (c, size, h) in enumerate((((0, 0, 1.5), (1.5, 1.4, 1.2), 1.0), ((1.2, 0.5, 0.95), (1.1, 1.0, 0.9), 0.6),
                                      ((-1.1, 0.7, 0.9), (1.1, 1.0, 0.85), 0.55), ((0.2, -1.2, 0.85), (1.05, 1.0, 0.8), 0.5))):
        leaves(clump(c, size, lobes=10, subdivisions=2, bump=0.3), h, TOP, BOTTOM)
    for k in range(5):
        a = rnd.uniform(-2.4, -0.6)
        r = rnd.uniform(1.2, 1.6)
        paint.paint(lib.sphere(f"Berry{k}", 0.16, (math.cos(a) * r, math.sin(a) * r, rnd.uniform(1.1, 1.9)), W, segments=6),
                    None, (0.86, 0.22, 0.28))
elif kind == "dead":
    # a twisted bare tree: a leaning trunk that corkscrews, branches in two orders, each crooked
    trunk_pts = [(0, 0, -0.6), (0.15, 0, 0.8), (0.6, 0.2, 2.8), (0.3, 0.6, 4.8), (-0.4, 0.5, 6.8), (-0.2, -0.2, 8.6),
                 (0.5, -0.4, 10.2), (0.9, 0.1, 11.6)]
    bark(tube(trunk_pts, [1.4, 1.15, 0.92, 0.8, 0.68, 0.56, 0.42, 0.26], ring=10, ridges=6, ridge_depth=0.12,
              flare=(1.3, 4, 0.8)), (0.74, 0.7, 0.76))
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, 0.9)) + d * 0.5, d * 1.6 + Vector((0, 0, 0.45)), d * 2.6 + Vector((0, 0, 0.05)),
               d * 3.1 + Vector((0, 0, -0.4))]
        bark(tube([tuple(p) for p in pts], [0.45, 0.32, 0.2, 0.08], ring=6, ridges=3, ridge_depth=0.05), (0.74, 0.7, 0.76))

    def crooked(start, direction, length, r0, depth):
        """a branch in three crooked pieces; at depth 1 it forks once more"""
        pts, p, d = [Vector(start)], Vector(start), Vector(direction).normalized()
        for _ in range(3):
            d = (d + Vector((rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45), rnd.uniform(-0.15, 0.35)))).normalized()
            p = p + d * length / 3
            pts.append(p)
        bark(tube([tuple(q) for q in pts], [r0, r0 * 0.7, r0 * 0.45, r0 * 0.15], ring=6, ridges=3, ridge_depth=0.05),
             (0.74, 0.7, 0.76))
        if depth > 0:
            for t in (0.45, 0.8):
                q = pts[1].lerp(pts[2], t) if t < 0.6 else pts[2].lerp(pts[3], t - 0.5)
                side = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.2, 0.9)))
                crooked(tuple(q), tuple(side), length * 0.5, r0 * 0.5, depth - 1)

    for k, (h, a, up, length, r0) in enumerate(((5.2, 0.3, 0.5, 5.2, 0.42), (6.9, 2.4, 0.6, 4.8, 0.36),
                                                 (8.5, 4.3, 0.7, 4.4, 0.3), (9.8, 1.4, 0.9, 3.6, 0.24))):
        base = Vector(trunk_pts[min(len(trunk_pts) - 1, int(h / 1.6) + 1)])
        crooked(tuple(Vector((base.x, base.y, h))), (math.cos(a), math.sin(a), up), length, r0, 1)
else:
    raise SystemExit("unknown kind " + kind)

name = {"oak": "tree_oak", "oak_b": "tree_oak_b", "oak_c": "tree_oak_c", "dead": "tree_dead",
        "bush": "keep_field_bush"}.get(kind, "tree_" + kind)
parts = paint.bake(name, out[:-4] + "_paint.png", 1024, triangles=9000)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
