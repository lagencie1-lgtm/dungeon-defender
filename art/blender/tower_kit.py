"""The tower kit (Lemp 2026-11-23: "make a better workflow ... without Tripo"): real built detail for the defenders,
modelled in code the way the Codex pictures are drawn, so the silhouette, the light and the occlusion already read
like the picture before any paint goes on.

  stone_wall      a tapering round wall of separate cut stones in offset rows (gaps left for doors and windows)
  stone_ring      one row of big footing stones
  shingle_roof    a bell-shaped roof of overlapping shingles in tiers, over a dark core
  balcony         a round lookout: floor, corbels, two rails, X braces, posts and brass corner plates with rivets
  roof_posts      posts with knee braces carrying the roof
  arched_door     plank door with a brass band and ring, a ring of arch stones and front steps
  banner          a cloth banner with sag, a pointed foot, border and leaf emblem, hung from a brass rod
  ivy             a vine climbing the wall with heart-shaped leaves
  wavy_flag       a flag with a sine wave
  finial          brass cup, pole and ball
  grass / pebbles round the footing

Everything is placed around the tower axis; FRONT is the angle (degrees) the door looks to (-90 = -Y, the game's
front). Units are studs. Colours are the pictures' palette; textures come from art/textures via sculpt/paint."""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import paint
import sculpt as S

rad = math.radians
STONE = (1.0, 0.88, 0.7)
MORTAR = (0.72, 0.62, 0.5)
WOOD = (0.8, 0.58, 0.4)
WOOD_DARK = (0.5, 0.33, 0.21)
ROOF = (0.74, 0.33, 0.26)      # the pictures' calm brick red (coordinator 2026-11-23: less orange-pink)
ROOF_DARK = (0.55, 0.25, 0.2)
GREEN = (0.34, 0.6, 0.25)
LEAF = (0.36, 0.66, 0.26)
CREAM = (0.97, 0.92, 0.8)
BRASS = (1.0, 0.76, 0.3)
GRASS = (0.45, 0.72, 0.26)
rnd = random.Random(7)


def at(a, r, z):
    return (math.cos(a) * r, math.sin(a) * r, z)


ATLAS = ["body"]   # which texture a new part is painted into (see atlas() and bake_atlases())


class atlas:
    """with atlas("roof"): ... puts the parts made inside into their own texture (coordinator 2026-11-23: the
    archer, the roof and the props each get texture room of their own)"""
    def __init__(self, name):
        self.name = name

    def __enter__(self):
        ATLAS.append(self.name)

    def __exit__(self, *a):
        ATLAS.pop()


def _link(name, mesh, color, key=None, tile=1.4):
    """puts a finished mesh in the scene with its paint, without selection operators (they slow down with every
    part in the scene; a tower has about a thousand parts)"""
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj["htd_atlas"] = ATLAS[-1]
    return paint.paint(obj, key, color, tile)


def _place(bm, pos, rot, size=(1, 1, 1)):
    from mathutils import Euler, Matrix
    m = Matrix.Translation(pos) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def block(name, pos, size, color, rot=(0, 0, 0), key=None, tile=1.4, bevel=0.04):
    """a box with one chamfer (cheap: 26 faces), placed and turned as it is made"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=2 if bevel >= 0.08 else 1, affect="EDGES",
                        profile=0.5)
    _place(bm, pos, rot)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return _link(name, mesh, color, key, tile)


def ball(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=10, key=None, tile=1.2):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    _place(bm, pos, rot)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    return _link(name, mesh, color, key, tile)

def cone(name, pos, r, h, color, rot=(0, 0, 0), top=0.0, verts=10, key=None, tile=1.2):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=top, depth=h)
    _place(bm, pos, rot)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return _link(name, mesh, color, key, tile)


def limb(name, a, b, r0, r1, color, verts=8, end=True, key=None, tile=1.2):
    va, vb = Vector(a), Vector(b)
    d = vb - va
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r0, radius2=r1, depth=max(1e-4, d.length))
    from mathutils import Matrix
    m = Matrix.Translation((va + vb) / 2) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    _link(name, mesh, color, key, tile)
    if end:
        ball(name + "End", b, r1, color, seg=verts)


def chain(name, points, radii, color, seg=8):
    ball(name + "Start", points[0], radii[0], color, seg=seg)
    for i in range(len(points) - 1):
        limb(f"{name}{i}", points[i], points[i + 1], radii[i], radii[i + 1], color, verts=seg)


def membrane(name, points, faces, color, thickness=0.04, key=None, tile=1.2):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in points]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    bm.normal_update()
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thickness)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return _link(name, mesh, color, key, tile)

def lathe(name, profile, color, key=None, tile=2.0, verts=24, cap=True):
    """a round body from a profile [(r, z), ...] (bottom to top)"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((math.cos(2 * math.pi * i / verts) * r, math.sin(2 * math.pi * i / verts) * r, z)) for i in range(verts)])
    for a, b in zip(rings, rings[1:]):
        for i in range(verts):
            j = (i + 1) % verts
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    return _link(name, mesh, color, key, tile)


def stone_wall(name, z0, z1, r0, r1, rows, per_row, gaps=(), depth=0.42, jitter=0.05):
    """cut stones in offset rows on a tapering round wall; gaps = [(angle_deg, half_width_deg, z_top)]"""
    lathe(name + "Core", [(r0 - depth * 0.55, z0), (r1 - depth * 0.55, z1)], MORTAR, key="stone", verts=24)
    h = (z1 - z0) / rows
    for row in range(rows):
        z = z0 + h * (row + 0.5)
        r = r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        n = per_row
        step = 360 / n
        off = step / 2 if row % 2 else 0
        for i in range(n):
            ang = i * step + off + rnd.uniform(-3, 3)
            if any(abs((ang - g[0] + 180) % 360 - 180) < g[1] and z < g[2] for g in gaps):
                continue
            a = rad(ang)
            w = 2 * math.pi * r / n * rnd.uniform(0.93, 0.99)
            c = rnd.uniform(0.9, 1.05)
            block(f"{name}{row}_{i}", at(a, r - depth * 0.2 + rnd.uniform(-jitter, jitter), z),
                  (w, depth, h * rnd.uniform(0.82, 0.9)), tuple(min(1, v * c) for v in STONE), (0, 0, a + rad(90)),
                  key=None, tile=1.3, bevel=0.13)  # few big stones with soft edges, like the paintings (coordinator 2026-11-23)


def stone_ring(name, z, r, h, n, depth=0.7, skip=()):
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-2, 2)
        if any(abs((ang - s[0] + 180) % 360 - 180) < s[1] for s in skip):
            continue
        a = rad(ang)
        w = 2 * math.pi * r / n * 0.92
        c = rnd.uniform(0.88, 1.02)
        block(f"{name}{i}", at(a, r - depth / 2, z + h / 2), (w, depth, h * rnd.uniform(0.9, 1.0)),
              tuple(min(1, v * c) for v in STONE), (0, 0, a + rad(90)), key=None, tile=1.2, bevel=0.16)


def shingle_roof(name, z0, z1, r_eave, tiers=4, per_tier=16, bell=0.75, overhang=0.4, thick=0.32):
    """a bell roof: profile radius r(u) = r_eave * (1-u)^bell for u in 0..1 up the roof"""
    def radius(u):
        return max(0.12, r_eave * (1 - u) ** bell)
    prof = [(radius(u) * 0.97, z0 + (z1 - z0) * u) for u in (0, 0.15, 0.3, 0.5, 0.7, 0.85, 0.97)]
    lathe(name + "Core", prof, ROOF_DARK, key="wood", verts=per_tier, tile=1.2)
    lathe(name + "Eave", [(r_eave * 0.9, z0 - 0.25), (r_eave * 0.98, z0 + 0.02)], WOOD_DARK, key="wood_dark", verts=per_tier * 2, tile=1.2)
    for t in range(tiers):
        u0, u1 = t / tiers, (t + 1) / tiers * 1.0
        ra, rb = radius(u0), radius(min(0.97, u1 + 0.08))
        za, zb = z0 + (z1 - z0) * u0, z0 + (z1 - z0) * min(0.97, u1 + 0.08)
        n = max(6, round(per_tier * (ra / r_eave) ** 0.5))
        length = math.hypot(ra - rb, zb - za) + overhang * (1 if t == 0 else 0.5)
        tilt = math.atan2(ra - rb, zb - za)
        off = 180 / n if t % 2 else 0
        for i in range(n):
            a = rad(i * 360 / n + off + rnd.uniform(-2, 2))
            rm, zm = (ra + rb) / 2, (za + zb) / 2 - (overhang * 0.25 if t == 0 else 0)
            w = 2 * math.pi * ra / n * rnd.uniform(1.02, 1.12)
            c = rnd.uniform(0.86, 1.06)
            # tilt about the tangent, then turn round the axis
            block(f"{name}{t}_{i}", at(a, rm + thick, zm), (w, thick, length),
                  tuple(min(1, v * c) for v in ROOF), (-(tilt + rad(9)), 0, a + rad(90)), key=None, tile=1.0, bevel=0.09)  # a bit flatter than the roof: each tier's lower edge stands out as a step


def finial(z, cup=0.55, pole=1.0, knob=0.3):
    lathe("FinialCup", [(0.1, z), (cup * 0.35, z + cup * 0.5), (cup, z + cup * 0.9), (cup * 0.9, z + cup)], BRASS, key="brass", verts=14, tile=0.8)
    limb("FinialPole", (0, 0, z + cup), (0, 0, z + cup + pole), 0.11, 0.09, BRASS, verts=8, end=False)
    ball("FinialBall", (0, 0, z + cup + pole + knob * 0.8), knob, BRASS, seg=12, key="brass", tile=0.8)
    return z + cup + pole


def wavy_flag(z_top, length, height, color=GREEN, waves=1.3, amp=0.22, cols=10):
    pts, faces = [], []
    for i in range(cols + 1):
        u = i / cols
        h = height * (1 - 0.7 * u)            # tapers to a point like the pictures' pennants
        x = u * length
        y = math.sin(u * math.pi * 2 * waves) * amp * 0.5 * u
        wave = math.sin(u * math.pi * 2 * waves) * amp * (0.3 + u)   # the wave shows in the outline: up and down
        mid = z_top - height / 2 + wave - 0.15 * u * height
        pts.append((x + 0.1, y, mid + h / 2))
        pts.append((x + 0.1, y, mid - h / 2))
    for i in range(cols):
        a, b, c, d = 2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2
        faces += [(a, b, c), (a, c, d)]
    membrane("Flag", pts, faces, color, 0.06)


def roof_posts(z0, z1, r, n, front, size=0.66, brace=True):
    for i in range(n):
        a = rad(front + 360 / n * (i + 0.5))
        block(f"RoofPost{i}", at(a, r, (z0 + z1) / 2), (size, size, z1 - z0), WOOD_DARK, rot=(0, 0, a), key="wood_dark", tile=1.2)
        if brace:
            for s in (-1, 1):
                b = a + s * rad(360 / n * 0.3)
                p0 = Vector(at(a, r, z1 - 1.1))
                p1 = Vector(at(b, r * 1.02, z1 - 0.1))
                limb(f"Knee{i}{s}", tuple(p0), tuple(p1), 0.19, 0.19, WOOD_DARK, verts=6, end=False)


def balcony(z, r, height, bays, front, floor_r=None, posts_out=0.15):
    """a round wooden lookout: floor ring, corbels underneath, bottom and top rails, X braces, brass corner plates"""
    floor_r = floor_r or r + 0.15
    lathe("LookFloor", [(floor_r * 0.9, z - 0.2), (floor_r, z), (floor_r, z + 0.35), (floor_r * 0.9, z + 0.4)], WOOD, key="wood", verts=bays * 3, tile=1.5)
    step = 360 / bays
    for i in range(bays):
        a = rad(front + i * step)
        # corbel under the floor
        block(f"Corbel{i}", at(a, r - 0.35, z - 0.55), (0.42, 0.9, 0.75), WOOD_DARK, rot=(0, 0, a + rad(90)), key="wood_dark", tile=1.0)
        # corner post and brass plate with rivets
        p = at(a, r + posts_out, z + height / 2 + 0.2)
        block(f"BPost{i}", p, (0.62, 0.62, height + 0.3), WOOD_DARK, rot=(0, 0, a), key="wood_dark", tile=1.0, bevel=0.1)
        pl = Vector(at(a, r + posts_out + 0.24, z + height * 0.55))
        block(f"Plate{i}", tuple(pl), (0.62, 0.08, height * 0.8), BRASS, rot=(0, 0, a + rad(90)), key="brass", tile=0.8, bevel=0.03)
        for dz in (-0.3, 0.3):
            for dt in (-0.17, 0.17):
                q = pl + Vector((math.cos(a), math.sin(a), 0)) * 0.06 + Vector((-math.sin(a), math.cos(a), 0)) * dt + Vector((0, 0, dz * height * 0.8))
                ball(f"Rivet{i}{dz}{dt}", tuple(q), 0.07, BRASS, seg=5)
        ball(f"Knob{i}", at(a, r + posts_out, z + height + 0.4), 0.2, BRASS, seg=8, key="brass", tile=0.6)
        # rails and braces in the bay to the next post
        b = a + rad(step / 2)
        span = 2 * (r + 0.05) * math.sin(rad(step / 2)) - 0.4
        for zz, hh in ((z + 0.55, 0.32), (z + height, 0.4)):
            block(f"Rail{i}{zz:.1f}", at(b, (r + 0.05) * math.cos(rad(step / 2)), zz), (span, 0.42, hh * 1.35), WOOD, rot=(0, 0, b + rad(90)), key="wood", tile=1.4, bevel=0.1)
        diag = math.atan2(height - 0.75, span)
        for s in (-1, 1):
            block(f"Brace{i}{s}", at(b, (r - 0.05) * math.cos(rad(step / 2)), z + 0.55 + (height - 0.55) / 2),
                  (math.hypot(span, height - 0.6) * 0.9, 0.26, 0.3), WOOD_DARK, (0, s * diag, b + rad(90)), key="wood_dark", tile=1.0)


def arched_door(front, r_wall, z, w=1.6, h=2.2, steps=2, arch_stones=7):
    a = rad(front)
    n = Vector((math.cos(a), math.sin(a), 0))
    t = Vector((-math.sin(a), math.cos(a), 0))
    base = Vector(at(a, r_wall - 0.05, 0))
    rot = (0, 0, a + rad(90))
    # dark doorway, planks, brass band and ring
    block("Doorway", tuple(base - n * 0.15 + Vector((0, 0, z + h * 0.5))), (w + 0.3, 0.3, h + 0.2), (0.12, 0.08, 0.06), rot=rot, bevel=0.02)
    for k in range(3):
        block(f"Plank{k}", tuple(base + t * ((k - 1) * w / 3) + Vector((0, 0, z + h * 0.42))), (w / 3 - 0.06, 0.18, h * 0.84),
              WOOD, rot=rot, key="wood", tile=1.0, bevel=0.03)
    top = base + Vector((0, 0, z + h * 0.84))
    for k in range(7):
        ang = math.pi * (k + 0.5) / 7
        p = top + t * (math.cos(ang) * (w / 2 - 0.05)) * 0.92 + Vector((0, 0, math.sin(ang) * (w / 2) * 0.6))
        block(f"PlankTop{k}", tuple(p), (w / 7.5, 0.18, 0.4), WOOD, rot=rot, key="wood", tile=1.0, bevel=0.02)
    block("DoorBand", tuple(base + n * 0.1 + Vector((0, 0, z + h * 0.6))), (w, 0.08, 0.16), BRASS, rot=rot, key="brass", tile=0.6, bevel=0.02)
    for k in (-1, 1):
        ball(f"BandStud{k}", tuple(base + n * 0.16 + t * (k * w * 0.38) + Vector((0, 0, z + h * 0.6))), 0.07, BRASS, seg=5)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.05, major_segments=12, minor_segments=6,
                                     location=tuple(base + n * 0.2 + Vector((0, 0, z + h * 0.38))), rotation=(rad(90), 0, a + rad(90)))
    S.textured(bpy.context.active_object, "brass", BRASS, 0.6)
    # arch of cut stones
    c = base + n * 0.12 + Vector((0, 0, z + h - w / 2))
    for k in range(arch_stones):
        ang = math.pi * k / (arch_stones - 1)
        p = c + t * (math.cos(ang) * (w / 2 + 0.35)) + Vector((0, 0, math.sin(ang) * (w / 2 + 0.35)))
        block(f"Voussoir{k}", tuple(p), (0.62, 0.55, 0.75), STONE, (0, -(ang - math.pi / 2), a + rad(90)), key=None, tile=1.0, bevel=0.12)
    for s in (-1, 1):
        for k in range(3):
            block(f"Jamb{s}{k}", tuple(base + n * 0.12 + t * (s * (w / 2 + 0.35)) + Vector((0, 0, z + 0.35 + k * 0.55))),
                  (0.68, 0.55, 0.62), STONE, rot=rot, key=None, tile=1.0, bevel=0.12)
    # a threshold slab under the steps, so no ground shows through the gap in the footing ring
    block("Threshold", tuple(base + n * 0.55 + Vector((0, 0, 0.1))), (w + 1.6, 1.6, 0.2), STONE, rot, key="stone", tile=1.0, bevel=0.05)
    for k in range(steps):
        block(f"Step{k}", tuple(base + n * (0.45 + (steps - 1 - k) * 0.4) + Vector((0, 0, 0.2 + k * 0.3))),
              (w + 0.9 - k * 0.3, 0.55 + 0.4 * (steps - 1 - k) * 0, 0.3), STONE, rot=rot, key="stone", tile=1.0, bevel=0.08)


def banner(ang, r_wall, z_top, w, h, emblem=True, field=CREAM, trim=GREEN, mark=GREEN):
    """field = the cloth, trim = its border, mark = the leaf emblem (level 2 is green with cream, level 3 the reverse)"""
    a = rad(ang)
    n = Vector((math.cos(a), math.sin(a), 0))
    t = Vector((-math.sin(a), math.cos(a), 0))
    top = Vector(at(a, r_wall + 0.25, z_top))
    limb("BannerRod", tuple(top - t * (w / 2 + 0.25)), tuple(top + t * (w / 2 + 0.25)), 0.06, 0.06, BRASS, verts=6, end=False)
    for s in (-1, 1):
        ball(f"RodBall{s}", tuple(top + t * (s * (w / 2 + 0.3))), 0.17, BRASS, seg=8, key="brass", tile=0.6)

    def cloth(name, inset, color, lift=0.0):
        pts, faces = [], []
        rows = 5
        for k in range(rows + 1):
            v = k / rows
            for s in (-1, 1):
                sag = 0.08 * math.sin(v * math.pi)
                p = top - Vector((0, 0, v * h)) + t * (s * (w / 2 - inset)) + n * (sag + lift)
                pts.append(tuple(p))
        pts.append(tuple(top - Vector((0, 0, h + w * 0.45 - inset)) + n * lift))
        for k in range(rows):
            i = 2 * k
            faces += [(i, i + 1, i + 3), (i, i + 3, i + 2)]
        last = 2 * rows
        faces.append((last, last + 1, len(pts) - 1))
        membrane(name, pts, faces, color, 0.05)
    cloth("BannerBorder", 0.0, trim, 0.0)
    cloth("BannerCloth", 0.12, field, 0.035)
    if emblem:
        c = top - Vector((0, 0, h * 0.55)) + n * 0.12
        for k, (dx, sc, tilt) in enumerate(((0, 1.0, 0), (-0.22, 0.7, 40), (0.22, 0.7, -40))):
            p = c + t * dx + Vector((0, 0, -0.12 if k else 0.05))
            # a leaf of three blades, big enough to read (the first ones vanished in the paint)
            ball(f"Emblem{k}", tuple(p), w * 0.24 * sc, mark, (0.5, 0.18, 1.2), rot=(0, rad(tilt), a + rad(90)), seg=8)


def leaf(name, p, normal, size, color=LEAF, turn=0.0):
    """a heart-shaped ivy leaf lying on the wall, facing out along normal"""
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1))
    side = up.cross(n).normalized()
    up = n.cross(side).normalized()
    c, s = math.cos(turn), math.sin(turn)
    side, up = side * c + up * s, up * c - side * s
    base = Vector(p) + n * 0.06
    shape = [(0, -0.5), (0.55, 0.05), (0.42, 0.45), (0.0, 0.3), (-0.42, 0.45), (-0.55, 0.05)]
    pts = [tuple(base + n * 0.0)] + [tuple(base + side * (x * size) + up * (y * size) + n * (0.08 * size * (1 - abs(x)))) for x, y in shape]
    faces = [(0, i, i % 6 + 1) for i in range(1, 7)]
    membrane(name, pts, faces, color, 0.03)


def ivy(name, r_of_z, ang0, z0, z1, leaves=10, sway=18, size=0.62):
    pts = []
    n = 8
    for k in range(n):
        u = k / (n - 1)
        z = z0 + (z1 - z0) * u
        a = rad(ang0 + math.sin(u * 5.0 + ang0) * sway * u)
        pts.append(at(a, r_of_z(z) + 0.08, z))
    chain(name + "Stem", pts, [0.07] * n, WOOD_DARK, seg=5)
    for k in range(leaves):
        u = (k + 0.5) / leaves
        z = z0 + (z1 - z0) * u
        side = 1 if k % 2 else -1
        a = rad(ang0 + math.sin(u * 5.0 + ang0) * sway * u + side * rnd.uniform(5, 10))
        p = at(a, r_of_z(z) + 0.18, z)
        col = LEAF if k % 3 else (0.28, 0.52, 0.22)
        # leaves stand off the wall, turned a little sideways and up (the pictures' ivy pops out of the outline)
        out = (math.cos(a) - side * 0.6 * math.sin(a), math.sin(a) + side * 0.6 * math.cos(a), 0.35)
        leaf(f"{name}Leaf{k}", p, out, size * rnd.uniform(0.8, 1.15), col, turn=side * rnd.uniform(0.2, 0.7))


def grass(r, n, h=0.7, skip=()):
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-10, 10)
        if any(abs((ang - s[0] + 180) % 360 - 180) < s[1] for s in skip):
            continue
        a = rad(ang)
        rr = r + rnd.uniform(0.0, 0.45)
        # a soft clump with a few short blades (spiky cones alone read as low-poly, Gemini 2026-11-23)
        ball(f"Tuft{i}", at(a, rr, 0.12), h * 0.38, (0.36, 0.62, 0.22), (1.3, 1.0, 0.6), seg=7)
        for k in range(3):
            cone(f"Grass{i}{k}", at(a + (k - 1) * 0.05, rr, h * 0.35), 0.09, h * rnd.uniform(0.55, 0.8),
                 (0.5, 0.78, 0.3), (rad((k - 1) * 22), rad((k - 1) * 16), 0), verts=3)


def pebbles(r, n, skip=()):
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-15, 15)
        if any(abs((ang - s[0] + 180) % 360 - 180) < s[1] for s in skip):
            continue
        a = rad(ang)
        ball(f"Pebble{i}", at(a, r + rnd.uniform(0, 0.4), 0.15), rnd.uniform(0.22, 0.34), (0.82, 0.76, 0.68), (1.3, 1, 0.65), seg=7,
               key="stone", tile=1.0)


def archer(x, y, z, s=1.0, face=-90):
    """the Ranger's archer, the tower's face (coordinator 2026-11-23): a chibi hooded archer like the pictures: big
    head in a pointed green hood with the face showing, brown tunic and belt, arms out to a drawn bow, a quiver of
    arrows on the back. About 700 triangles; it goes into its own texture (atlas "archer")."""
    with atlas("archer"):
        a = rad(face)
        f = Vector((math.cos(a), math.sin(a), 0))
        rt = Vector((math.sin(a), -math.cos(a), 0))  # the archer's right hand side
        o = Vector((x, y, z))

        def P(fw, side, up):
            return tuple(o + f * (fw * s) + rt * (side * s) + Vector((0, 0, up * s)))
        TUNIC = (0.36, 0.56, 0.22)
        SKIN = (0.98, 0.79, 0.64)
        LEATHER = (0.55, 0.34, 0.2)
        ball("ArcherBody", P(0, 0, 0.62), 0.42, TUNIC, (1.0, 0.85, 1.15), seg=10)
        ball("ArcherBelt", P(0.02, 0, 0.42), 0.4, LEATHER, (1.03, 0.9, 0.22), seg=10)
        ball("ArcherBuckle", P(0.38, 0, 0.42), 0.07, BRASS, (1, 0.5, 1), seg=6)
        # head: big, round, the face forward; the hood wraps the back and top and ends in a point
        ball("ArcherHead", P(0.12, 0, 1.32), 0.4, SKIN, seg=12)
        ball("ArcherHood", P(-0.1, 0, 1.42), 0.47, GREEN, (1.0, 1.04, 1.04), seg=12)
        cone("ArcherHoodTip", P(-0.48, 0, 1.62), 0.22, 0.55, GREEN, (0, 0, 0), verts=6)
        ball("ArcherHoodRim", P(0.18, 0, 1.6), 0.36, GREEN, (0.55, 1.05, 0.35), seg=10)
        for k in (-1, 1):
            ball(f"ArcherEye{k}", P(0.48, k * 0.14, 1.34), 0.065, (0.12, 0.08, 0.06), (0.6, 1, 1.2), seg=6)
            block(f"ArcherBrow{k}", P(0.5, k * 0.15, 1.46), (0.05, 0.14, 0.04), (0.35, 0.22, 0.12), (0, 0, a + rad(90)), bevel=0.0)
        ball("ArcherNose", P(0.52, 0, 1.27), 0.05, (0.95, 0.7, 0.56), seg=6)
        # arms and hands, the bow held out to the left, the string drawn to the right cheek
        limb("ArcherArmL", P(0.05, -0.36, 0.86), P(0.62, -0.5, 1.0), 0.11, 0.09, TUNIC, verts=6)
        limb("ArcherArmR", P(0.05, 0.36, 0.86), P(0.32, 0.2, 1.1), 0.11, 0.09, TUNIC, verts=6)
        ball("ArcherHandL", P(0.66, -0.5, 1.0), 0.1, SKIN, seg=6)
        ball("ArcherHandR", P(0.34, 0.2, 1.12), 0.1, SKIN, seg=6)
        bow = [P(0.7, -0.5 + 0.22 * math.cos(t), 1.0 + 0.72 * math.sin(t)) for t in (-1.3, -0.65, 0, 0.65, 1.3)]
        chain("Bow", bow, [0.05, 0.07, 0.08, 0.07, 0.05], LEATHER, seg=6)
        limb("BowString", bow[0], P(0.32, 0.2, 1.1), 0.018, 0.018, CREAM, verts=3, end=False)
        limb("BowString2", P(0.32, 0.2, 1.1), bow[-1], 0.018, 0.018, CREAM, verts=3, end=False)
        limb("Arrow", P(0.32, 0.2, 1.1), P(1.3, -0.62, 1.05), 0.03, 0.03, (0.92, 0.86, 0.7), verts=4, end=False)
        cone("ArrowHead", P(1.36, -0.66, 1.05), 0.08, 0.22, (0.78, 0.78, 0.82), (0, rad(90), a - rad(35)), verts=4)
        # quiver with three fletched arrows
        limb("Quiver", P(-0.36, 0.12, 0.5), P(-0.5, 0.3, 1.35), 0.15, 0.17, LEATHER, verts=8, end=False)
        for k in range(3):
            cone(f"Fletch{k}", P(-0.5 + k * 0.06, 0.24 + k * 0.08, 1.52), 0.09, 0.32, CREAM, verts=4)
    global LAST_MUZZLE
    LAST_MUZZLE = P(1.3, -0.62, 1.05)   # the arrow tip: where the game's shots start

LAST_MUZZLE = None


def finish_check():
    if LAST_MUZZLE:   # Blender (x, y, z) -> the game's (-x, z, y) (the FBX export turns -Y forward into -Z)
        x, y, z = LAST_MUZZLE
        print("MUZZLE Vector3.new(%.2f, %.2f, %.2f)" % (-x, z, y))
    count = sum(len(p.vertices) - 2 for o in bpy.context.scene.objects if o.type == "MESH" for p in o.data.polygons)
    print("RAW TRIANGLES", count)
    return count


# --- level 1 and level 3 pieces --------------------------------------------------------------------------------
def gable_roof(name, length, span, z_eave, z_ridge, rows=4, cols=6, thick=0.16, caps=True):
    """a gable roof along X: two shingled slopes over dark boards, a ridge beam, brass caps on the four corners"""
    half = span / 2
    slope = math.atan2(z_ridge - z_eave, half)
    run = math.hypot(half, z_ridge - z_eave)
    for s in (-1, 1):
        mid_y, mid_z = s * half / 2, (z_eave + z_ridge) / 2
        block(f"{name}Board{s}", (0, mid_y, mid_z - 0.08), (length, run + 0.3, 0.14), WOOD_DARK, (-s * slope, 0, 0), key="wood_dark", tile=1.2)
        for r in range(rows):
            u = (r + 0.5) / rows
            y = s * half * (1 - u)
            z = z_eave + (z_ridge - z_eave) * u + 0.05
            off = 0.5 if r % 2 else 0
            for c in range(cols):
                x = -length / 2 + length * (c + 0.5 + off * 0.5) / (cols + off * 0.5)
                if abs(x) > length / 2:
                    continue
                k = rnd.uniform(0.86, 1.06)
                block(f"{name}Sh{s}{r}{c}", (x, y + s * 0.04, z + thick / 2), (length / cols * 0.95, run / rows * 1.25, thick),
                      tuple(min(1, v * k) for v in ROOF), (-s * (slope + rad(5)), 0, 0), key="wood", tile=1.0, bevel=0.03)
    for e in (-1, 1):   # the gable ends: a triangle of boards with a tie beam (the picture shows one end open)
        x = e * (length / 2 - 0.25)
        pts = [(x, -half * 0.92, z_eave + 0.05), (x, half * 0.92, z_eave + 0.05), (x, 0, z_ridge - 0.1)]
        membrane(f"{name}Gable{e}", pts, [(0, 1, 2)], (0.62, 0.42, 0.27), 0.18)
        block(f"{name}Tie{e}", (x + e * 0.1, 0, z_eave + 0.1), (0.25, span * 0.95, 0.3), WOOD_DARK, key="wood_dark", tile=1.0)
        block(f"{name}King{e}", (x + e * 0.1, 0, (z_eave + z_ridge) / 2), (0.22, 0.25, z_ridge - z_eave), WOOD_DARK, key="wood_dark", tile=1.0)
    block(f"{name}Ridge", (0, 0, z_ridge + 0.15), (length + 0.3, 0.5, 0.4), WOOD_DARK, key="wood_dark", tile=1.2)
    for s in (-1, 1):
        # barge boards on the gable ends
        for e in (-1, 1):
            block(f"{name}Barge{s}{e}", (e * (length / 2 + 0.08), s * half / 2, (z_eave + z_ridge) / 2 + 0.05),
                  (0.22, run + 0.35, 0.36), WOOD_DARK, (-s * slope, 0, 0), key="wood_dark", tile=1.0)
    if caps:
        for e in (-1, 1):
            block(f"{name}CapRidge{e}", (e * (length / 2 + 0.12), 0, z_ridge + 0.2), (0.5, 0.65, 0.55), BRASS, key="brass", tile=0.6)
            for s in (-1, 1):
                block(f"{name}Cap{e}{s}", (e * (length / 2 + 0.12), s * (half + 0.1), z_eave - 0.05), (0.45, 0.55, 0.45), BRASS,
                      (-s * slope, 0, 0), key="brass", tile=0.6)


def corner_plate(name, p, a, size=0.6, rivets=4):
    """an L of brass round a square post corner at p, turned by a (radians), with rivets"""
    for k, turn in enumerate((0, math.pi / 2)):
        aa = a + turn
        n = Vector((math.cos(aa), math.sin(aa), 0))
        q = Vector(p) + n * 0.02
        block(f"{name}{k}", tuple(q), (size, 0.07, size), BRASS, (0, 0, aa + rad(90)), key="brass", tile=0.6, bevel=0.02)
        for i in range(rivets // 2):
            ball(f"{name}R{k}{i}", tuple(q + n * 0.05 + Vector((0, 0, (i - 0.5) * size * 0.5))), 0.07, BRASS, seg=5)


def ladder(name, foot, top, width=1.0, rungs=5, across=(1, 0, 0)):
    f, t = Vector(foot), Vector(top)
    side = Vector(across) * (width / 2)
    for s in (-1, 1):
        limb(f"{name}Rail{s}", tuple(f + side * s), tuple(t + side * s), 0.1, 0.1, WOOD, verts=4, end=False)
    for k in range(rungs):
        p = f + (t - f) * ((k + 0.7) / (rungs + 0.4))
        block(f"{name}Rung{k}", tuple(p), (width, 0.16, 0.14), WOOD_DARK, (0, 0, math.atan2(across[1], across[0])), key="wood_dark", tile=1.0)


def plank_wall(name, p0, p1, z0, z1, boards=3, thick=0.25):
    """horizontal boards between two points (a lookout side)"""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    ang = math.atan2(d.y, d.x)
    h = (z1 - z0) / boards
    for k in range(boards):
        c = (a + b) / 2
        block(f"{name}{k}", (c.x, c.y, z0 + h * (k + 0.5)), (d.length, thick, h * 0.92), WOOD if k % 2 else (0.74, 0.52, 0.36),
              (0, 0, ang), key="wood", tile=1.4, bevel=0.04)


def brass_band(name, z, r, h=0.55, studs=16):
    lathe(name, [(r - 0.05, z - h / 2), (r + 0.12, z - h / 2 + 0.05), (r + 0.12, z + h / 2 - 0.05), (r - 0.05, z + h / 2)], BRASS, key="brass", verts=32, tile=0.8)
    for i in range(studs):
        a = rad(i * 360 / studs)
        ball(f"{name}Stud{i}", at(a, r + 0.15, z), 0.12, BRASS, seg=6)


def window(name, ang, r, z, w=0.9, h=1.1):
    a = rad(ang)
    n = Vector((math.cos(a), math.sin(a), 0))
    t = Vector((-math.sin(a), math.cos(a), 0))
    base = Vector(at(a, r, z))
    rot = (0, 0, a + rad(90))
    block(f"{name}Hole", tuple(base - n * 0.05), (w, 0.3, h), (0.16, 0.1, 0.07), rot, bevel=0.02)
    block(f"{name}Sill", tuple(base + n * 0.1 - Vector((0, 0, h / 2 + 0.12))), (w + 0.5, 0.45, 0.25), STONE, rot, key="stone", tile=1.0)
    for k in range(7):
        ang2 = math.pi * k / 6
        p = base + n * 0.1 + t * (math.cos(ang2) * (w / 2 + 0.25)) + Vector((0, 0, h / 2 - w / 2 + math.sin(ang2) * (w / 2 + 0.25)))
        block(f"{name}Arch{k}", tuple(p), (0.32, 0.4, 0.42), STONE, (0, -(ang2 - math.pi / 2), a + rad(90)), key="stone", tile=1.0, bevel=0.06)
    for s in (-1, 1):
        block(f"{name}Jamb{s}", tuple(base + n * 0.1 + t * (s * (w / 2 + 0.25)) - Vector((0, 0, 0.2))), (0.35, 0.4, h * 0.75), STONE, rot, key="stone", tile=1.0, bevel=0.06)


def swag(name, a0, a1, r, z, drop=0.45, color=GREEN, trim=CREAM, n=6):
    """a cloth swag hanging between two angles on a round rail (degrees)"""
    for layer, (col, dz, dd) in enumerate(((color, 0.0, 0.0), (trim, -0.12, 0.08))):
        pts, faces = [], []
        for k in range(n + 1):
            u = k / n
            a = rad(a0 + (a1 - a0) * u)
            sag = math.sin(u * math.pi) * (drop + dd)
            for zz in (0.0, -0.32):
                pts.append(at(a, r + 0.06 + layer * 0.04, z + zz + dz - sag))
        for k in range(n):
            i = 2 * k
            faces += [(i, i + 1, i + 3), (i, i + 3, i + 2)]
        membrane(f"{name}{layer}", pts, faces, col, 0.04)


def roof_ribs(name, z0, z1, r_eave, bell, n=8, front=0.0):
    for i in range(n):
        a = rad(front + i * 360 / n)
        pts = []
        for k in range(5):
            u = k / 4 * 0.95
            r = max(0.15, r_eave * (1 - u) ** bell) + 0.22
            pts.append(at(a, r, z0 + (z1 - z0) * u + 0.1))
        for k in range(4):
            mid = Vector(pts[k]).lerp(Vector(pts[k + 1]), 0.5)
            d = Vector(pts[k + 1]) - Vector(pts[k])
            tilt = math.atan2(math.hypot(d.x, d.y), d.z)
            block(f"{name}{i}_{k}", tuple(mid), (0.34, 0.3, d.length + 0.1), BRASS, (-tilt, 0, a + rad(90)), key="brass", tile=0.6, bevel=0.0)
        block(f"{name}End{i}", pts[0], (0.5, 0.5, 0.5), BRASS, (0, 0, a), key="brass", tile=0.6)


def crown(z, r=0.7):
    lathe("CrownBase", [(r * 0.6, z), (r, z + 0.2), (r, z + 0.5), (r * 0.8, z + 0.55)], BRASS, key="brass", verts=16, tile=0.6)
    for i in range(6):
        a = rad(i * 60)
        cone(f"CrownSpike{i}", at(a, r * 0.85, z + 0.85), 0.2, 0.6, BRASS, verts=4)
    return z + 0.55


def gem(z, size=0.75, color=(0.35, 1.0, 0.35)):
    """the glowing gem: its own part (the game makes it Neon)"""
    mesh = bpy.data.meshes.new("Gem")
    bm = bmesh.new()
    top = bm.verts.new((0, 0, z + size * 1.35))   # squat, like the pictures' gem
    bot = bm.verts.new((0, 0, z))
    ring = [bm.verts.new((math.cos(rad(i * 60)) * size * 0.6, math.sin(rad(i * 60)) * size * 0.62, z + size * 0.5)) for i in range(6)]
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((ring[i], ring[j], top))
        bm.faces.new((ring[j], ring[i], bot))
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Gem", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return S.glow(obj, color)


def cull_hidden(reach=0.9, rays=16):
    """Deletes faces nobody can see (pressed against the wall core, under other stones, on the ground) before the
    model is joined and unwrapped: the texture's room then goes to what is seen (about twice the paint detail).
    A face is hidden when every ray from it into its open side hits another part within `reach` studs."""
    from mathutils.bvhtree import BVHTree
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    whole = bmesh.new()
    for o in objs:
        m = o.data.copy()
        m.transform(o.matrix_world)
        whole.from_mesh(m)
        bpy.data.meshes.remove(m)
    tree = BVHTree.FromBMesh(whole)
    golden = math.pi * (3 - math.sqrt(5))
    dirs = []
    for i in range(rays):
        y = 1 - 2 * (i + 0.5) / rays
        r = math.sqrt(1 - y * y)
        dirs.append(Vector((math.cos(golden * i) * r, math.sin(golden * i) * r, y)))
    removed = total = 0
    for o in objs:
        if o.get("htd_atlas") == "barrel":
            # (2026-11-24: the turning weapon is slim and crowded with bands, rail and bolt round it: every ray from
            # the ballista's stock met one of them within reach and the whole stock was cut away; weapons are kept)
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        mw = o.matrix_world
        nm = mw.to_3x3().inverted().transposed()
        gone = []
        for f in bm.faces:
            total += 1
            c = mw @ f.calc_center_median()
            n = (nm @ f.normal).normalized()
            if n.z < -0.7 and c.z < 0.25:
                gone.append(f)
                continue
            hidden = True
            for d in dirs:
                if d.dot(n) <= 0.05:
                    continue
                hit = tree.ray_cast(c + d * 0.03, d, reach)
                if hit[0] is None:
                    hidden = False
                    break
            if hidden:
                gone.append(f)
        if gone:
            bmesh.ops.delete(bm, geom=gone, context="FACES")
            bm.to_mesh(o.data)
            removed += len(gone)
        bm.free()
    whole.free()
    print("CULLED %d of %d faces" % (removed, total))


SIZES = {"body": 1024, "roof": 1024, "props": 512, "archer": 512}


def bake_atlases(name, out, budget=16000):
    """Joins the painted parts per atlas and bakes each into its own texture: the body is the MeshPart "Body"
    (texture <out>_paint.png, the game's paint_<name>), the others "Skin_<atlas>" (<out>_paint_<atlas>.png, the
    game's paint_<name>_<atlas>). Glowing parts stay c_R_G_B parts. Writes the fbx and prints HEIGHT/TRIANGLES."""
    import os
    import lib
    scene = bpy.context.scene
    out = os.path.abspath(out)
    objs = [o for o in scene.objects if o.type == "MESH"]
    glowing = [o for o in objs if not o.get("htd_paint")]
    groups = {}
    for o in objs:
        if o.get("htd_paint"):
            groups.setdefault(o.get("htd_atlas", "body"), []).append(o)
    total = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.bake.margin = 6
    parts = []
    for key, members in groups.items():
        for i, o in enumerate(members):
            o.name = f"{key}_piece_{i}"
        bpy.ops.object.select_all(action="DESELECT")
        for o in members:
            o.select_set(True)
        bpy.context.view_layer.objects.active = members[0]
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = joined.data.name = "Body" if key == "body" else "Skin_" + key
        count = sum(len(p.vertices) - 2 for p in joined.data.polygons)
        share = budget * count / max(1, total)
        if count > share * 1.02 and total > budget:
            mod = joined.modifiers.new("decimate", "DECIMATE")
            mod.ratio = share / count
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0, scale_to_bounds=True)
        bpy.ops.object.mode_set(mode="OBJECT")
        size = SIZES.get(key, 512)
        img = bpy.data.images.new(f"{name}_{key}", size, size)
        for mat in joined.data.materials:
            node = mat.node_tree.nodes.new("ShaderNodeTexImage")
            node.image = img
            mat.node_tree.nodes.active = node
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = out[:-4] + ("_paint.png" if key == "body" else f"_paint_{key}.png")
        img.file_format = "PNG"
        img.save()
        joined.data.materials.clear()
        final = bpy.data.materials.new(f"{name}_{key}_baked")
        final.use_nodes = True
        tex = final.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        final.node_tree.links.new(tex.outputs["Color"], final.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
        joined.data.materials.append(final)
        scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        parts.append(joined)
        print("ATLAS", key, size, sum(len(p.vertices) - 2 for p in joined.data.polygons), "triangles")
    colours = {}
    for o in glowing:
        c = [float(v) for v in o.get("htd_color", (1, 1, 1))]
        lib._paint(o, (1, 1, 1))
        colours.setdefault("c_%d_%d_%d" % tuple(round(max(0, min(1, v)) * 255) for v in c[:3]), []).append(o)
    for key, members in colours.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in members:
            o.select_set(True)
        bpy.context.view_layer.objects.active = members[0]
        if len(members) > 1:
            bpy.ops.object.join()
        o = bpy.context.active_object
        o.name = o.data.name = key
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        parts.append(o)
    print("TRIANGLES", lib.triangles(parts))
    print("HEIGHT %.2f" % max((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices))
    lib.export_fbx(out)
    print("EXPORTED", out)


def _in(name, fn):
    def wrapped(*a, **k):
        with atlas(name):
            return fn(*a, **k)
    wrapped.__doc__ = fn.__doc__
    return wrapped


# which texture each kind of part goes into: the roof and lookout, and the cloth and plants (banners, swags, ivy,
# flag) get their own; stones, door and footing stay in the body
shingle_roof = _in("roof", shingle_roof)
gable_roof = _in("roof", gable_roof)
roof_ribs = _in("roof", roof_ribs)
roof_posts = _in("roof", roof_posts)
balcony = _in("roof", balcony)
finial = _in("roof", finial)
crown = _in("roof", crown)
banner = _in("props", banner)
swag = _in("props", swag)
ivy = _in("props", ivy)
wavy_flag = _in("props", wavy_flag)


def archer_anchor(x, y, z, face, height=3.1):
    """where an archer stands (the archer is its own model now, ranger_archer, placed by the game): an empty at his
    feet, turned to `face` degrees (his front). anchors_report() prints them for TowerService and removes them."""
    e = bpy.data.objects.new("ArcherAnchor", None)
    e.location = (x, y, z)
    e.rotation_euler = (0, 0, rad(face))
    e["height"] = height
    bpy.context.scene.collection.objects.link(e)
    bpy.context.view_layer.update()   # (or its matrix stays the identity until the next update)
    return e


def anchors_report():
    """ARCHER lines in the game's space: position (-x, z, y) and the yaw that turns the archer's front (-Z) there"""
    lines = []
    bpy.context.view_layer.update()
    # the game stands a model by the bottom centre of its box: give the feet relative to that point
    pts = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == "MESH" for c in o.bound_box]
    base = Vector(((min(p.x for p in pts) + max(p.x for p in pts)) / 2, (min(p.y for p in pts) + max(p.y for p in pts)) / 2,
                   min(p.z for p in pts)))
    for e in [o for o in bpy.context.scene.objects if o.name.startswith("ArcherAnchor")]:
        p = e.matrix_world.translation - base
        a = e.matrix_world.to_euler().z
        yaw = math.degrees(math.atan2(math.cos(a), -math.sin(a)))
        lines.append("ARCHER Vector3.new(%.2f, %.2f, %.2f) %.0f %.2f" % (-p.x, p.z, p.y, yaw, e["height"]))
        bpy.data.objects.remove(e, do_unlink=True)
    for ln in lines:
        print(ln)
