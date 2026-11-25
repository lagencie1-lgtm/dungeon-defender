"""Map trees built the way the towers are (Lemp 2026-11-25: "the trees look really weird - make the map objects with
the same workflow, painterly and blender - right now they look like stupid bubble gum trees").

What made them bubble gum: a crown of perfect spheres in one saturated green, a smooth cone trunk, and shiny plastic
in the game. A painted tree is built differently, and that is what this builds:
  trunk     a gnarled tube with bark ridges, a flared foot whose buttress roots dive into the ground, a slight S
  limbs     tapering tubes that split from the trunk and run up into the crown, visible in the gaps between clumps
  crown     clumps, not balls: each a lumpy dome made of rounded lobes (a cauliflower outline that reads as massed
            leaves), flat and dark underneath, lighter and warmer on top (light from the top-left, art/STYLE.md);
            the clumps sit apart enough that the limbs show between them
Kinds:  oak   the Cursed Forest's oak, about 17 studs tall (the game scales each one)
        dead  a twisted bare tree with crooked branches in two orders (Forest, and Magma's burnt wood)
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
import lib  # noqa: E402
import paint  # noqa: E402

W = (1, 1, 1)
args = sys.argv[sys.argv.index("--") + 1:]
out, kind = os.path.abspath(args[0]), args[1]
seed = int(args[2]) if len(args) > 2 else 7
rnd = random.Random(seed)
lib.reset()
paint.setup()
n_made = 0


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def tube(points, radii, ring=10, ridges=6, ridge_depth=0.09, flare=None, cap=True):
    """A tube through `points` with a radius per point. Bark ridges run along it (`ridges` of them); `flare` is
    (height, lobes, amount): below that height the radius swells into buttress lobes."""
    global n_made
    n_made += 1
    bm = bmesh.new()
    rings = []
    phase = rnd.uniform(0, 6.28)
    for i, (p, r) in enumerate(zip(points, radii)):
        p = Vector(p)
        a = Vector(points[max(i - 1, 0)])
        b = Vector(points[min(i + 1, len(points) - 1)])
        d = (b - a).normalized()
        side = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))).normalized()
        up = side.cross(d).normalized()
        verts = []
        for k in range(ring):
            ang = k / ring * math.tau
            rr = r * (1 + ridge_depth * math.sin(ang * ridges + phase + i * 0.35))
            if flare and p.z < flare[0]:
                f = 1 - p.z / flare[0]
                rr *= 1 + flare[2] * f * f * max(0.0, math.cos(ang * flare[1] + phase)) ** 2 + 0.25 * f
            off = side * math.cos(ang) * rr + up * math.sin(ang) * rr
            verts.append(bm.verts.new(p + off))
        rings.append(verts)
    for i in range(len(rings) - 1):
        for k in range(ring):
            a, b = rings[i][k], rings[i][(k + 1) % ring]
            c, e = rings[i + 1][(k + 1) % ring], rings[i + 1][k]
            bm.faces.new((a, b, c, e))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(f"Tube{n_made}", bm)


def clump(centre, size, lobes=16, flat=0.5, bump=0.34, subdivisions=3):
    """A crown clump: an ellipsoid (size = radii x, y, z) whose surface rises in rounded lobes round `lobes` points,
    flattened underneath. Each lobe is a smooth swelling, so the outline is scalloped like massed leaves, not round."""
    global n_made
    n_made += 1
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    centres = []
    for _ in range(lobes):
        v = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), abs(rnd.gauss(0, 1)) * 0.8 + 0.1)).normalized()
        centres.append((v, rnd.uniform(0.75, 1.15)))
    for v in bm.verts:
        n = v.co.normalized()
        # the nearest two lobes: a swelling round each, a crease where they meet
        near = sorted((1 - n.dot(c)) / s for c, s in centres)
        lift = bump * max(0.0, 1 - near[0] * 3.2) ** 2 + 0.08 * noise.noise(n * 3.1 + Vector((seed, n_made, 0)))
        r = 1 + lift
        x, y, z = n.x * r, n.y * r, n.z * r
        if z < 0:
            z *= flat
        v.co = Vector((centre[0] + x * size[0], centre[1] + y * size[1], centre[2] + z * size[2]))
    return new_object(f"Clump{n_made}", bm)


LIGHT = Vector((-0.45, -0.4, 0.8)).normalized()   # from the top-left, towards the viewer (art/STYLE.md)


def leaves(obj, height, top, bottom):
    """Leaf paint in three painted value bands, the way a painter blocks in a crown: a warm light where the clump
    faces the light, a mid green, a cool deep shadow underneath. The higher the clump, the lighter all three."""
    t = max(0.0, min(1.0, height))
    base = [bottom[i] + (top[i] - bottom[i]) * t for i in range(3)]
    jitter = rnd.uniform(0.95, 1.05)
    bands = [tuple(c * 1.18 * jitter for c in (base[0] * 1.06, base[1], base[2] * 0.82)),   # light: warmer
             tuple(c * 0.92 * jitter for c in base),                                           # mid
             tuple(c * 0.55 * jitter for c in (base[0] * 0.85, base[1], base[2] * 1.15))]     # shadow: cooler
    mesh = obj.data
    mesh.materials.clear()
    for tint in bands:
        mesh.materials.append(paint.material("leaves", tint, 7.0))
    for poly in mesh.polygons:
        d = poly.normal.dot(LIGHT)
        poly.material_index = 0 if d > 0.42 else 1 if d > -0.1 else 2
    obj["htd_paint"] = True


def bark(obj, tint=(1.0, 0.94, 0.88)):
    paint.paint(obj, "bark", tint, 2.2)


def limb(start, end, r0, r1, bend=0.25):
    """a branch with a slight upward bow"""
    s, e = Vector(start), Vector(end)
    mid = (s + e) / 2 + Vector((rnd.uniform(-bend, bend), rnd.uniform(-bend, bend), (e - s).length * 0.12))
    pts = [s, s.lerp(mid, 0.5), mid, mid.lerp(e, 0.5), e]
    return tube([tuple(p) for p in pts], [r0 + (r1 - r0) * i / 4 for i in range(5)], ring=7, ridges=3, ridge_depth=0.06)


if kind in ("oak", "crown_test"):
    TOP, BOTTOM = (1.05, 1.1, 0.72), (0.52, 0.72, 0.66)   # warm sunlit yellow-green on top, cool deep green below
    if kind == "crown_test":
        leaves(clump((0, 0, 3), (3.2, 3.0, 2.6)), 0.8, TOP, BOTTOM)
    else:
        # the trunk: an S that leans a little, ridged bark, buttress roots at the foot
        trunk_pts = [(0, 0, -0.6), (0.1, 0, 0.6), (0.35, 0.1, 2.2), (0.2, 0.25, 4.0), (-0.15, 0.2, 5.8), (0.05, 0.0, 7.4),
                     (0.3, -0.15, 8.6)]
        bark(tube(trunk_pts, [2.1, 1.75, 1.4, 1.2, 1.08, 0.98, 0.85], ring=12, ridges=7, ridge_depth=0.1,
                  flare=(1.6, 5, 0.9)))
        # roots that dive into the ground beside the flare
        for k in range(5):
            a = k / 5 * math.tau + rnd.uniform(-0.25, 0.25)
            d = Vector((math.cos(a), math.sin(a), 0))
            pts = [Vector((0, 0, 1.0)) + d * 0.6, d * 1.8 + Vector((0, 0, 0.55)), d * 2.9 + Vector((0, 0, 0.12)),
                   d * 3.5 + Vector((0, 0, -0.4))]
            bark(tube([tuple(p) for p in pts], [0.55, 0.42, 0.26, 0.1], ring=7, ridges=3, ridge_depth=0.05))
        # the crown: clumps round a dome, apart enough to show the limbs; each limb runs into its clump
        top = Vector((0.3, -0.15, 8.6))
        # an oak's crown is a tall dome, not an umbrella: a top clump, a middle tier of three set in from the
        # edge, and five low clumps round the rim, far enough apart that the limbs show in the gaps
        clumps = [((0.3, 0.0, 15.2), (3.0, 2.8, 2.4), 1.0)]
        for k, ang in enumerate((60, 180, 300)):
            a = math.radians(ang + rnd.uniform(-15, 15))
            clumps.append(((math.cos(a) * 2.4, math.sin(a) * 2.4, rnd.uniform(12.6, 13.4)),
                           (rnd.uniform(2.7, 3.0), rnd.uniform(2.6, 2.9), rnd.uniform(2.1, 2.4)), 0.8))
        for k, ang in enumerate((20, 95, 165, 240, 315)):
            a = math.radians(ang + rnd.uniform(-12, 12))
            r = rnd.uniform(4.0, 4.5)
            clumps.append(((math.cos(a) * r, math.sin(a) * r, rnd.uniform(9.6, 11.2)),
                           (rnd.uniform(2.4, 2.8), rnd.uniform(2.3, 2.7), rnd.uniform(1.8, 2.1)), 0.45 + 0.08 * k))
        for k, (c, size, h) in enumerate(clumps):
            c = Vector(c) + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(-0.2, 0.2)))
            leaves(clump(tuple(c), size, lobes=rnd.randint(13, 18)), h, TOP, BOTTOM)
            if k > 0:
                # the limb from the trunk's top into the clump's lower middle
                end = c + Vector((0, 0, -size[2] * 0.25))
                bark(limb(tuple(top + Vector((0, 0, rnd.uniform(-1.2, 0.2)))), tuple(end), 0.62, 0.26))
        # a few twigs that poke out between the clumps (a painted tree never shows a closed shell)
        for k in range(5):
            a = rnd.uniform(0, math.tau)
            s = top + Vector((0, 0, rnd.uniform(0.8, 2.6)))
            e = s + Vector((math.cos(a) * 4.2, math.sin(a) * 4.2, rnd.uniform(0.6, 1.8)))
            bark(limb(tuple(s), tuple(e), 0.22, 0.06, bend=0.4))
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

name = {"oak": "tree_oak", "dead": "tree_dead"}.get(kind, "tree_" + kind)
parts = paint.bake(name, out[:-4] + "_paint.png", 1024, triangles=9000)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
