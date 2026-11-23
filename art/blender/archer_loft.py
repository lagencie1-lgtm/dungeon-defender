"""The Ranger's archer, rebuilt as closed lofted solids (Lemp 2026-11-23: "ripped apart face, the other side looking
has a cut head, the front and back always have a missing piece on the hoody"; coordinator's rebuild plan).
Shape: from art/ref3d/archer/ranger_archer_loft.json (scripts/archer_loft_spec.py measures the bare model sheet).
  Head   the hood: ONE closed solid lofted row by row (half-width from the symmetrised front outline, depth and forward
         offset from the side outline, a superellipse section per row, capped); the face a shallow recess on its front;
         the cream trim a band along the opening's edge; the hair fringe separate small tufts
  Body   torso (one solid, reaching up inside the hood: no gap at the neck), belt band, buckle, hem band, front slit
         band, collar, two trouser legs, two boots with cuffs
  ArmR, ArmL   sleeve tube, cream cuff band, upper arm tube, bracer, fist (each its own closed solid)
  Bow, Quiver  the old props, unchanged (their own sheet), placed on the new body
Paint: the face takes the front painting only (projected straight on, feathered out before the trim); everything else
is its palette colour with painted light (key light from the top left, ambient occlusion) baked in. No side painting.
Run: blender -b -P archer_loft.py -- <out dir> [old fbx with Bow and Quiver]"""
import json
import math
import os
import shutil
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.append(HERE)
args = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(args[0])
OLD = os.path.abspath(args[1]) if len(args) > 1 else os.path.join(ROOT, "tools", "archer2", "ranger_archer.fbx")
NAME = "ranger_archer"
SPEC = json.load(open(os.path.join(ROOT, "art", "ref3d", "archer", "ranger_archer_loft.json")))
SHEET = os.path.join(ROOT, "art", "ref3d", "archer", SPEC["sheet"])
PAL = SPEC["palette"]
SEG = 32
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# ---------------------------------------------------------------------------------------------------------------
# geometry helpers: every helper returns a closed bmesh shell (no boundary edges), tagged with a palette name
# ---------------------------------------------------------------------------------------------------------------
def se(t, n):
    """superellipse unit section: (cos, sin) raised to 2/n with their signs"""
    c, s = math.cos(t), math.sin(t)
    return math.copysign(abs(c) ** (2 / n), c), math.copysign(abs(s) ** (2 / n), s)


def section(row, t, n_front=2.4, n_back=2.2, grow=0.0):
    cx = row.get("cx", 0.0)
    c = (row["front"] + row["back"]) / 2
    d = (row["back"] - row["front"]) / 2 + grow
    w = row["hw"] + grow
    n = n_front if math.sin(t) < 0 else row.get("nb", n_back)
    a, b = se(t, n)
    return Vector((cx + w * a, c + d * b, row["z"]))


def shell_from_rings(bm, rings, top=None, bottom=None):
    """rings: list of vertex position lists (same count, going round), from the bottom up; capped with fans"""
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    faces = []
    for k in range(len(vs) - 1):
        a, b = vs[k], vs[k + 1]
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    lo = bm.verts.new(bottom if bottom is not None else sum(rings[0], Vector()) / n)
    hi = bm.verts.new(top if top is not None else sum(rings[-1], Vector()) / n)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((vs[0][j], vs[0][i], lo)))
        faces.append(bm.faces.new((vs[-1][i], vs[-1][j], hi)))
    return faces


def loft(bm, rows, grow=0.0, n_front=2.4, n_back=2.2, seg=SEG, dome=0.0, base=0.0):
    rings = []
    for r in sorted(rows, key=lambda r: r["z"]):
        rings.append([section(r, 2 * math.pi * i / seg - math.pi / 2, n_front, n_back, grow) for i in range(seg)])
    top = sum(rings[-1], Vector()) / seg + Vector((0, 0, dome))
    bot = sum(rings[0], Vector()) / seg - Vector((0, 0, base))
    return shell_from_rings(bm, rings, top, bot)


def frame_along(pts):
    """per point: tangent and two normals (parallel transport)"""
    out = []
    up = Vector((0, 0, 1))
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = prev_n if prev_n is not None else (up if abs(t.dot(up)) < 0.9 else Vector((1, 0, 0)))
        n = (n - t * n.dot(t)).normalized()
        out.append((t, n, t.cross(n)))
        prev_n = n
    return out


def catmull(points, per=6):
    pts = [Vector(p) for p in points]
    if len(pts) < 3:
        return [pts[0].lerp(pts[-1], k / (per * 2)) for k in range(per * 2 + 1)]
    out = []
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return out


def tube(bm, points, radii, seg=16, per=6, flat=1.0, caps="dome"):
    """a lofted tube along a smooth centre line, round ends (closed)"""
    pts = catmull(points, per)
    rr = [radii[0]] * len(pts) if len(radii) == 1 else None
    if rr is None:   # radii given per control point: spread along the smoothed line
        rr = []
        for k in range(len(pts)):
            f = k / (len(pts) - 1) * (len(radii) - 1)
            i = min(int(f), len(radii) - 2)
            rr.append(radii[i] + (radii[i + 1] - radii[i]) * (f - i))
    fr = frame_along(pts)

    def ring(p, r, frame, f=1.0, off=0.0):
        t, n, b = frame
        return [p + (n * math.cos(2 * math.pi * i / seg) * flat + b * math.sin(2 * math.pi * i / seg)) * (r * f) + t * (r * off) for i in range(seg)]
    rings = [ring(p, r, f) for p, r, f in zip(pts, rr, fr)]
    if caps != "dome":
        return shell_from_rings(bm, rings)
    # round ends: shrinking rings past each end, then the tip
    for k in (1, 2, 3):
        a = math.pi / 2 * k / 4
        rings.insert(0, ring(pts[0], rr[0], fr[0], math.cos(a), -math.sin(a) * flat))
        rings.append(ring(pts[-1], rr[-1], fr[-1], math.cos(a), math.sin(a) * flat))
    return shell_from_rings(bm, rings, pts[-1] + fr[-1][0] * rr[-1] * flat, pts[0] - fr[0][0] * rr[0] * flat)


def ellipsoid(bm, c, r, seg=20, rings=12):
    c = Vector(c)
    rs = []
    for k in range(1, rings):
        ph = -math.pi / 2 + math.pi * k / rings
        rs.append([c + Vector((r[0] * math.cos(ph) * math.cos(2 * math.pi * i / seg), r[1] * math.cos(ph) * math.sin(2 * math.pi * i / seg), r[2] * math.sin(ph))) for i in range(seg)])
    return shell_from_rings(bm, rs, c + Vector((0, 0, r[2])), c - Vector((0, 0, r[2])))


def box(bm, c, size):
    r = bmesh.ops.create_cube(bm, size=1.0)
    for v in r["verts"]:
        v.co = Vector(c) + Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return list({f for v in r["verts"] for f in v.link_faces})


class Part:
    """one game part: several closed shells, each face tagged with a palette name"""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.tags = {}

    def add(self, faces, pal):
        for f in faces:
            self.tags[f] = pal
            f.smooth = True
        return faces


def interp(rows, key, zz):
    rows = sorted(rows, key=lambda r: r["z"])
    if zz <= rows[0]["z"]:
        return rows[0][key]
    if zz >= rows[-1]["z"]:
        return rows[-1][key]
    for a, b in zip(rows, rows[1:]):
        if a["z"] <= zz <= b["z"]:
            f = (zz - a["z"]) / (b["z"] - a["z"])
            return a[key] + (b[key] - a[key]) * f


def head_surface(x, zz, n_front=2.4):
    """the hood's front surface (y) at (x, z): the superellipse section solved for x"""
    hw = interp(SPEC["head"], "hw", zz)
    fr = interp(SPEC["head"], "front", zz)
    bk = interp(SPEC["head"], "back", zz)
    c, d = (fr + bk) / 2, (bk - fr) / 2
    u = min(abs(x) / hw, 0.999)
    cos_t = u ** (n_front / 2)
    sin_t = math.sqrt(max(0.0, 1 - cos_t * cos_t))
    return c - d * sin_t ** (2 / n_front), Vector((x / hw, (c - d * sin_t ** (2 / n_front) - c) / d, 0))


# ---------------------------------------------------------------------------------------------------------------
# Head
# ---------------------------------------------------------------------------------------------------------------
head = Part("Head")
# the hood's soft point at the back: the sections turn pointed (in plan) round the row that reaches furthest back,
# so the point is part of the one solid, not a piece stuck on
Z_TIP = max(SPEC["head"], key=lambda r: r["back"])["z"]
head_rows = [dict(r, nb=2.2 - 0.8 * math.exp(-((r["z"] - Z_TIP) / 0.22) ** 2)) for r in SPEC["head"]]
hood_faces = head.add(loft(head.bm, head_rows, dome=0.0, seg=40), "hood")
# smooth the rows into each other (no row banding): along z only
hood_verts = list({v for f in hood_faces for v in f.verts})
for _ in range(6):
    bmesh.ops.smooth_vert(head.bm, verts=hood_verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=False)

OPEN = sorted(SPEC["opening"], key=lambda r: r["z"])
Z_OPEN_TOP, Z_OPEN_BOT = OPEN[-1]["z"], OPEN[0]["z"]


def opening_w(zz):
    if zz > Z_OPEN_TOP or zz < Z_OPEN_BOT:
        return 0.0
    return interp(OPEN, "ow", zz)


def edge_distance(x, zz):
    """how far (x, z) is inside the opening, seen from the front (0 at the edge, negative outside)"""
    ow = opening_w(zz)
    d_side = ow - abs(x)
    d_top = Z_OPEN_TOP - zz
    return min(d_side, d_top)


RECESS = 0.035
for v in hood_verts:
    c = (interp(SPEC["head"], "front", v.co.z) + interp(SPEC["head"], "back", v.co.z)) / 2
    if v.co.y < c:   # front half only
        e = edge_distance(v.co.x, v.co.z)
        if e > 0:
            f = min(1.0, e / 0.08)
            v.co.y += RECESS * (f * f * (3 - 2 * f))

# the cream trim: a band along the opening's edge, left side up over the top and down the right side
edge = []
for r in OPEN:
    edge.append((-r["ow"], r["z"]))
edge.append((0.0, Z_OPEN_TOP + 0.01))
for r in reversed(OPEN):
    edge.append((r["ow"], r["z"]))
pts = []
for x, zz in edge[::2]:
    y, _ = head_surface(x * 0.985, zz)
    pts.append(Vector((x, y - 0.006, zz)))
head.add(tube(head.bm, pts, [0.036], seg=12, per=3, flat=0.75), "cream")

# the hair fringe: small tufts hanging from under the trim at the top of the opening, ahead of the recessed face
for x, ln, tilt in ((-0.2, 0.12, -0.6), (0.0, 0.13, -0.25), (0.2, 0.12, 0.5)):
    zt = Z_OPEN_TOP
    while opening_w(zt) < abs(x) + 0.03 and zt > Z_OPEN_BOT:
        zt -= 0.005
    y0, _ = head_surface(x, zt - 0.02)
    a = Vector((x, y0 + RECESS * 0.8, zt - 0.08))      # lying on the forehead, under the trim
    b = a + Vector((math.sin(tilt) * ln, -0.005, -math.cos(tilt) * ln))
    head.add(tube(head.bm, [a, (a + b) / 2 + Vector((0, -0.02, 0)), b], [0.1, 0.075, 0.03], seg=12, per=3, flat=0.4), "hair")

# the hood's soft point at the back, curling down (the side painting's tail)


# ---------------------------------------------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------------------------------------------
body = Part("Body")
torso_rows = [dict(r) for r in SPEC["torso"]]
top = max(torso_rows, key=lambda r: r["z"])
for dz, f in ((0.04, 0.85), (0.08, 0.65)):     # up inside the hood: nothing to see through at the neck
    torso_rows.append(dict(top, z=top["z"] + dz, hw=top["hw"] * f))
body.add(loft(body.bm, torso_rows, n_front=2.6, n_back=2.6), "tunic")


def band(part, z0, z1, grow, pal, rows=None, cx=0.0):
    rows = rows or torso_rows
    rr = [dict(hw=interp(rows, "hw", zz), front=interp(rows, "front", zz), back=interp(rows, "back", zz), z=zz, cx=cx)
          for zz in (z0, (z0 + z1) / 2, z1)]
    return part.add(loft(part.bm, rr, grow=grow, n_front=2.6, n_back=2.6), pal)


band(body, SPEC["belt"]["z0"], SPEC["belt"]["z1"], 0.022, "leather")
band(body, SPEC["hem"]["z0"], SPEC["hem"]["z1"], 0.014, "cream")
bz0, bz1, bhw = SPEC["buckle"]["z0"], SPEC["buckle"]["z1"], SPEC["buckle"]["hw"]
by = interp(torso_rows, "front", (bz0 + bz1) / 2) - 0.03
for c, s in (((0, by, bz1 - 0.02), (bhw, 0.03, 0.02)), ((0, by, bz0 + 0.02), (bhw, 0.03, 0.02)),
             ((-bhw + 0.02, by, (bz0 + bz1) / 2), (0.02, 0.03, (bz1 - bz0) / 2)), ((bhw - 0.02, by, (bz0 + bz1) / 2), (0.02, 0.03, (bz1 - bz0) / 2)),
             ((0, by - 0.005, (bz0 + bz1) / 2), (0.012, 0.03, (bz1 - bz0) / 2 - 0.02))):
    body.add(box(body.bm, c, (s[0] * 2, s[1] * 2, s[2] * 2)), "gold")
sz0, sz1 = SPEC["slit"]["z0"], SPEC["slit"]["z1"]
sy = interp(torso_rows, "front", (sz0 + sz1) / 2)
body.add(tube(body.bm, [Vector((0, interp(torso_rows, "front", sz1) - 0.004, sz1)), Vector((0, interp(torso_rows, "front", sz0) - 0.01, sz0 + 0.02))],
              [0.022], seg=10, per=3, flat=0.6), "cream")
# collar: a cream V at the neck under the chin
for s in (-1, 1):   # (the painting: from under the hood's chin at 305 px down to a point at 335 px)
    vz = [(0.10, 1.41), (0.05, 1.35), (0.0, 1.29)]
    body.add(tube(body.bm, [Vector((s * x, interp(torso_rows, "front", zz) - 0.004, zz)) for x, zz in vz],
                  [0.024], seg=10, per=3, flat=0.6), "cream")
for s in (-1, 1):
    legs = [dict(r, cx=s * r["cx"]) for r in SPEC["leg"]]
    hi = max(legs, key=lambda r: r["z"])
    legs.append(dict(hi, z=hi["z"] + 0.15))
    lo = min(legs, key=lambda r: r["z"])
    legs.append(dict(lo, z=lo["z"] - 0.08))
    body.add(loft(body.bm, legs, seg=20), "trousers")
    boot = [dict(r, cx=s * r["cx"]) for r in SPEC["boot"]]
    body.add(loft(body.bm, boot, seg=24, n_front=2.2, n_back=2.6), "boot")
    bc = SPEC["boot_cuff"]
    body.add(loft(body.bm, [dict(hw=interp(boot, "hw", zz), front=interp(boot, "front", zz), back=interp(boot, "back", zz), z=zz, cx=interp(boot, "cx", zz))
                            for zz in (bc["z0"], (bc["z0"] + bc["z1"]) / 2, bc["z1"])], grow=0.018, seg=24), "boot")

# ---------------------------------------------------------------------------------------------------------------
# Arms (character's right arm at -X)
# ---------------------------------------------------------------------------------------------------------------
arms = []
A = SPEC["arm"]
for name, s in (("ArmR", 1), ("ArmL", -1)):
    p = Part(name)

    def m(v):
        return Vector((v[0] * s, v[1], v[2]))
    p.add(tube(p.bm, [m(v) for v in A["sleeve"]["path"]], A["sleeve"]["r"], seg=16), "tunic")
    cu = A["cuff"]
    d = Vector((cu["dir"][0] * s, cu["dir"][1], cu["dir"][2])).normalized()
    p.add(tube(p.bm, [m(cu["at"]) - d * cu["w"] / 2, m(cu["at"]) + d * cu["w"] / 2], [cu["r"] * 1.06], seg=16, per=2), "cream")
    p.add(tube(p.bm, [m(v) for v in A["upper"]["path"]], A["upper"]["r"], seg=14), "skin")
    p.add(tube(p.bm, [m(v) for v in A["bracer"]["path"]], A["bracer"]["r"], seg=16, flat=0.92), "bracer")
    fi = A["fist"]
    p.add(ellipsoid(p.bm, m(fi["at"]), fi["r"]), "skin")
    arms.append(p)

parts = [head, body] + arms


# ---------------------------------------------------------------------------------------------------------------
# gate: watertight per shell
# ---------------------------------------------------------------------------------------------------------------
def watertight(part):
    bm = part.bm
    bm.verts.ensure_lookup_table()
    bad = [e for e in bm.edges if len(e.link_faces) != 2]
    return len(bad)


GATES = {"watertight": {}}
for p in parts:
    bad = watertight(p)
    GATES["watertight"][p.name] = bad
    print("WATERTIGHT", p.name, "ok" if bad == 0 else f"FAIL {bad} open or non-manifold edges")


# ---------------------------------------------------------------------------------------------------------------
# paint: palette + painted light; the face takes the front painting only
# ---------------------------------------------------------------------------------------------------------------
img = bpy.data.images.load(SHEET)
IW, IH = img.size
S, CX, GROUND = SPEC["scale"], SPEC["cx"], SPEC["ground"]
NAMES = sorted(PAL) + ["hood_inner"]
PAL["hood_inner"] = [v * 0.55 for v in PAL["hood"]]


def to_object(part):
    mesh = bpy.data.meshes.new(part.name)
    bm = part.bm
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))   # outward on every closed shell
    bm.normal_update()
    col = bm.loops.layers.float_color.new("pal")
    facew = bm.loops.layers.float_color.new("facew")
    for f in bm.faces:
        c = lin(PAL[part.tags.get(f, "hood")]) + (1.0,)
        for loop in f.loops:
            w = 0.0
            if part.name == "Head" and part.tags.get(f) == "hood":
                v = loop.vert.co
                ctr = (interp(SPEC["head"], "front", v.z) + interp(SPEC["head"], "back", v.z)) / 2
                if v.y < ctr:
                    e = edge_distance(v.x, v.z)
                    if e > 0:
                        w = max(0.0, min(1.0, (e - 0.075) / 0.05))
                        # only where the surface looks to the front: the painting is never stretched round a side
                        nf = max(0.0, min(1.0, (-loop.vert.normal.y - 0.35) / 0.3))
                        w *= nf
                        if w < 1.0:   # the strip right inside the trim: the hood's shaded inside
                            ci = lin(PAL["hood_inner"])
                            k = max(0.0, min(1.0, e / 0.06))
                            c = tuple(a * (1 - k) + b * k for a, b in zip(lin(PAL["hood"]), ci)) + (1.0,)
            loop[col] = c
            loop[facew] = (w, w, w, 1.0)
    bm.to_mesh(mesh)
    o = bpy.data.objects.new(part.name, mesh)
    bpy.context.scene.collection.objects.link(o)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return o


def material(o):
    mat = bpy.data.materials.new(o.name + "_m")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs[0])
    pal = nt.nodes.new("ShaderNodeVertexColor")
    pal.layer_name = "pal"
    fw = nt.nodes.new("ShaderNodeVertexColor")
    fw.layer_name = "facew"
    # the front painting, projected straight on (x -> u, z -> v)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    mu = nt.nodes.new("ShaderNodeMath")
    mu.operation = "MULTIPLY_ADD"
    nt.links.new(sep.outputs["X"], mu.inputs[0])
    mu.inputs[1].default_value = 1 / (S * IW)
    mu.inputs[2].default_value = CX / IW
    mv = nt.nodes.new("ShaderNodeMath")
    mv.operation = "MULTIPLY_ADD"
    nt.links.new(sep.outputs["Z"], mv.inputs[0])
    mv.inputs[1].default_value = 1 / (S * IH)
    mv.inputs[2].default_value = 1 - GROUND / IH
    nt.links.new(mu.outputs[0], comb.inputs[0])
    nt.links.new(mv.outputs[0], comb.inputs[1])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Cubic"
    tex.extension = "EXTEND"
    nt.links.new(comb.outputs[0], tex.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(fw.outputs["Color"], mix.inputs["Factor"])
    nt.links.new(pal.outputs["Color"], mix.inputs["A"])
    nt.links.new(tex.outputs["Color"], mix.inputs["B"])
    # painted light: ambient + soft key from the top left front + ambient occlusion (the painting has its own light,
    # so the face gets only a little of it)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    key = nt.nodes.new("ShaderNodeVectorMath")
    key.operation = "DOT_PRODUCT"
    nt.links.new(geo.outputs["Normal"], key.inputs[0])
    key.inputs[1].default_value = Vector((-0.45, -0.55, 0.7)).normalized()
    wrap = nt.nodes.new("ShaderNodeMath")
    wrap.operation = "MULTIPLY_ADD"   # half-Lambert: n.l * 0.5 + 0.5
    nt.links.new(key.outputs["Value"], wrap.inputs[0])
    wrap.inputs[1].default_value = 0.5
    wrap.inputs[2].default_value = 0.5
    shade = nt.nodes.new("ShaderNodeMath")
    shade.operation = "MULTIPLY_ADD"  # 0.62 .. 1.12
    nt.links.new(wrap.outputs[0], shade.inputs[0])
    shade.inputs[1].default_value = 0.5
    shade.inputs[2].default_value = 0.62
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 16
    ao.inputs["Distance"].default_value = 0.25
    aom = nt.nodes.new("ShaderNodeMath")
    aom.operation = "MULTIPLY_ADD"    # AO 0..1 -> 0.6..1
    nt.links.new(ao.outputs["AO"], aom.inputs[0])
    aom.inputs[1].default_value = 0.4
    aom.inputs[2].default_value = 0.6
    light = nt.nodes.new("ShaderNodeMath")
    light.operation = "MULTIPLY"
    nt.links.new(shade.outputs[0], light.inputs[0])
    nt.links.new(aom.outputs[0], light.inputs[1])
    # the painted face keeps most of its own light: light -> mix(light, 1, 0.7*facew)
    soft = nt.nodes.new("ShaderNodeMix")
    soft.data_type = "FLOAT"
    fwm = nt.nodes.new("ShaderNodeMath")
    fwm.operation = "MULTIPLY"
    sepw = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(fw.outputs["Color"], sepw.inputs[0])
    nt.links.new(sepw.outputs[0], fwm.inputs[0])
    fwm.inputs[1].default_value = 0.7
    nt.links.new(fwm.outputs[0], soft.inputs["Factor"])
    nt.links.new(light.outputs[0], soft.inputs["A"])
    soft.inputs["B"].default_value = 1.0
    final = nt.nodes.new("ShaderNodeMix")
    final.data_type = "RGBA"
    final.blend_type = "MULTIPLY"
    final.inputs["Factor"].default_value = 1.0
    nt.links.new(mix.outputs["Result"], final.inputs["A"])
    gray = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(soft.outputs["Result"], gray.inputs[i])
    nt.links.new(gray.outputs[0], final.inputs["B"])
    nt.links.new(final.outputs["Result"], emit.inputs["Color"])
    return mat, nt


def seam_check(o, tex):
    """gate: across every texture seam the colour must not jump (both sides of each cut edge sampled in the bake)"""
    import numpy as np
    w, h = tex.size
    px = np.empty(w * h * 4, dtype=np.float32)
    tex.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[:, :, :3]
    uv = o.data.uv_layers.active.data
    by_edge = {}
    for poly in o.data.polygons:
        n = poly.loop_total
        for k in range(n):
            li = poly.loop_start + k
            lj = poly.loop_start + (k + 1) % n
            a, b = o.data.loops[li].vertex_index, o.data.loops[lj].vertex_index
            key = (min(a, b), max(a, b))
            ua, ub = uv[li].uv, uv[lj].uv
            if a > b:
                ua, ub = ub, ua
            by_edge.setdefault(key, []).append(((ua.x + ub.x) / 2, (ua.y + ub.y) / 2, ua, ub))
    def sample(px, x, y):   # a 3x3 texel average (the bake's own grain is not a seam)
        i, j = int(y * h), int(x * w)
        return px[max(0, i - 1):min(h, i + 2), max(0, j - 1):min(w, j + 2)].reshape(-1, 3).mean(axis=0)
    jumps = []
    for key, sides in by_edge.items():
        if len(sides) != 2:
            continue
        (x0, y0, a0, b0), (x1, y1, a1, b1) = sides
        if (a0 - a1).length < 1e-4 and (b0 - b1).length < 1e-4:
            continue    # not a seam
        c0 = sample(px, x0, y0)
        c1 = sample(px, x1, y1)
        jumps.append(float(np.abs(c0 - c1).max()) * 255)
    jumps.sort()
    p99 = jumps[int(len(jumps) * 0.99)] if jumps else 0
    GATES.setdefault("seam", {})[o.name] = {"edges": len(jumps), "p99": round(p99, 1), "max": round(jumps[-1], 1) if jumps else 0}
    print("SEAM", o.name, len(jumps), "seam edges, 99th percentile jump %.1f /255" % p99, "ok" if p99 <= 14 else "FAIL")


def bake(o, size):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    o.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    mat, nt = material(o)
    o.data.materials.append(mat)
    tex = bpy.data.images.new(o.name + "_paint", size, size)
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = tex
    nt.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 96
    sc.render.bake.margin = 16
    bpy.ops.object.bake(type="EMIT")
    path = os.path.join(OUT, f"{NAME}_{o.name.lower()}_paint.png")
    tex.filepath_raw = path
    tex.file_format = "PNG"
    tex.save()
    fin = bpy.data.materials.new(o.name + "_baked")
    fin.use_nodes = True
    t = fin.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = tex
    fin.node_tree.links.new(t.outputs["Color"], fin.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(fin)
    seam_check(o, tex)
    print("PART", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), "triangles", path)


objs = [to_object(p) for p in parts]
# phone budget: fewer triangles, the same outline (collapse keeps every shell closed; checked again below)
BUDGET = {"Head": 3200, "Body": 3200, "ArmR": 900, "ArmL": 900}
for o in objs:
    count = sum(len(q.vertices) - 2 for q in o.data.polygons)
    if count > BUDGET[o.name]:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        dec = o.modifiers.new("dec", "DECIMATE")
        dec.ratio = BUDGET[o.name] / count
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dec.name)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bad = len([e for e in bm.edges if len(e.link_faces) != 2])
    bm.free()
    GATES["watertight"][o.name] = bad
    print("WATERTIGHT (final)", o.name, "ok" if bad == 0 else f"FAIL {bad} open or non-manifold edges")
    for poly in o.data.polygons:
        poly.use_smooth = True

# ---------------------------------------------------------------------------------------------------------------
# the props from the old build: Bow in the left fist, Quiver on the back
# ---------------------------------------------------------------------------------------------------------------
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=OLD)
props = {}
for o in set(bpy.data.objects) - before:
    base = o.name.split(".")[0]
    if o.type == "MESH" and base in ("Bow", "Quiver"):
        props[base] = o
    else:
        bpy.data.objects.remove(o, do_unlink=True)
for base, o in props.items():
    o.name = base
    bpy.context.view_layer.update()
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector([min(v[i] for v in bb) for i in range(3)])
    hi = Vector([max(v[i] for v in bb) for i in range(3)])
    print("PROP", base, "size", tuple(round(v, 3) for v in hi - lo), "centre", tuple(round(v, 3) for v in (lo + hi) / 2))
    if base == "Bow":
        fist = Vector(A["fist"]["at"])
        fist.x = -fist.x   # the left fist (+X)
        o.location += fist - (lo + hi) / 2 + Vector((0.02, 0, 0))
    else:
        zc = (lo.z + hi.z) / 2
        back = interp(torso_rows, "back", 1.15)
        o.location += Vector((-0.1 - (lo.x + hi.x) / 2, back - 0.04 - lo.y, 1.12 - zc))
    shutil.copy(os.path.join(os.path.dirname(OLD), f"{NAME}_{base.lower()}_paint.png"), os.path.join(OUT, f"{NAME}_{base.lower()}_paint.png"))

for o, size in zip(objs, (1024, 1024, 512, 512)):
    bake(o, size)

import lib  # noqa: E402
out_fbx = os.path.join(OUT, NAME + ".fbx")
lib.export_fbx(out_fbx)
json.dump(GATES, open(os.path.join(OUT, "gates_build.json"), "w"), indent=1)
print("HEIGHT %.2f" % SPEC["height"])
print("EXPORTED", out_fbx)
