"""Foliage and bark for map objects, shared by tree_painted.py (trees, bushes) and map_kit.py (the keep tower's tree).
Clumps instead of balls (a scalloped outline of rounded lobes, flat dark undersides) painted in three value bands
from the top-left; tubes with bark ridges and buttress flares. Call setup(rnd, seed) first with the builder's own
random generator, so each builder stays repeatable."""
import math

import bmesh
import bpy
from mathutils import Vector, noise

import paint

rnd = None
seed = 0
n_made = 0


def setup(generator, number):
    global rnd, seed
    rnd, seed = generator, number


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


