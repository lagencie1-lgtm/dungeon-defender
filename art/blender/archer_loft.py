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
    """one row's ring: a superellipse; the front half spans the skull (front .. body_back), the back half reaches to
    "back" and may be narrower ("wb") and pointed ("nb"): that is how the hood's tail grows out of the same solid"""
    cx = row.get("cx", 0.0)
    bb = row.get("body_back", row["back"])
    c = (row["front"] + bb) / 2
    back = math.sin(t) >= 0
    d = ((row["back"] - c) if back else (c - row["front"])) + grow
    w = (row["hw"] * (row.get("wb", 1.0) if back else 1.0)) + grow
    n = row.get("nb", n_back) if back else n_front
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


def frame_along(pts, nvec=None):
    """per point: tangent and two normals (parallel transport)"""
    out = []
    up = Vector((0, 0, 1))
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = prev_n if prev_n is not None else (Vector(nvec) if nvec is not None else up if abs(t.dot(up)) < 0.9 else Vector((1, 0, 0)))
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


def tube(bm, points, radii, seg=16, per=6, flat=1.0, caps="dome", nvec=None):
    """a lofted tube along a smooth centre line, round ends (closed)"""
    pts = catmull(points, per)
    rr = [radii[0]] * len(pts) if len(radii) == 1 else None
    if rr is None:   # radii given per control point: spread along the smoothed line
        rr = []
        for k in range(len(pts)):
            f = k / (len(pts) - 1) * (len(radii) - 1)
            i = min(int(f), len(radii) - 2)
            rr.append(radii[i] + (radii[i + 1] - radii[i]) * (f - i))
    fr = frame_along(pts, nvec)

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


def head_c(zz):
    """the middle of the skull at height z (the front half of the hood's section is centred there)"""
    rows = SPEC["head"]
    return (interp(rows, "front", zz) + interp(rows, "body_back" if "body_back" in rows[0] else "back", zz)) / 2


def head_surface(x, zz, n_front=2.4):
    """the hood's front surface (y) at (x, z): the superellipse section solved for x"""
    hw = interp(SPEC["head"], "hw", zz)
    fr = interp(SPEC["head"], "front", zz)
    c = head_c(zz)
    d = c - fr
    u = min(abs(x) / hw, 0.999)
    cos_t = u ** (n_front / 2)
    sin_t = math.sqrt(max(0.0, 1 - cos_t * cos_t))
    return c - d * sin_t ** (2 / n_front), Vector((x / hw, (c - d * sin_t ** (2 / n_front) - c) / d, 0))


# ---------------------------------------------------------------------------------------------------------------
# Head
# ---------------------------------------------------------------------------------------------------------------
head = Part("Head")
# the elf hood: one solid; where it reaches far back the plan sections turn to a teardrop (pointed toward the back),
# so the hood runs back to a ridge and a point instead of a round dome
# the skull is about as deep as it is wide: what the side outline shows behind that is the hood's cone and tail
for r in SPEC["head"]:
    # (above the tail's start the whole outline is crown: the crown runs back into the tail with no saddle)
    # the notch only where the side painting has it (the rows where the tail hangs free); above, the crown is merged
    # into the tail as painted
    free = [t["z"] for t in SPEC.get("tip", [])]
    zt0 = (min(free) - 0.04) if free else 0
    zt1 = (max(free) + 0.06) if free else 0
    narrow = min(r.get("body_back", r["back"]), r["front"] + 1.75 * r["hw"])
    w_ = max(0.0, min(1.0, min(r["z"] - zt0, zt1 - r["z"]) / 0.05))
    skull = r.get("body_back", r["back"]) * (1 - w_) + narrow * w_
    t = max(0.0, min(1.0, (2.20 - r["z"]) / 0.12))
    r["body_back"] = r["back"] * (1 - t) + skull * t
# the hood is the skull's round shape here; its tail is a tube of its own along a curved spine, melted on below
# (round B: a single loft along the vertical cannot hang a tail free over the nape)
head_rows = [dict(r, back=r["body_back"]) for r in SPEC["head"]]
for r in SPEC["head"]:
    r["back"] = r["body_back"]
hood_faces = head.add(loft(head.bm, head_rows, dome=0.035, seg=40), "hood")
hood_verts = list({v for f in hood_faces for v in f.verts})
for _ in range(3):
    bmesh.ops.smooth_vert(head.bm, verts=hood_verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=False)
OPEN = sorted(SPEC["opening"], key=lambda r: r["z"])
# the trim's line: the measured opening smoothed (an even band, no wobble from single painted pixels)
_ow = [r["ow"] for r in OPEN]
for _ in range(6):
    _ow = [_ow[0]] + [(_ow[i - 1] + 2 * _ow[i] + _ow[i + 1]) / 4 for i in range(1, len(_ow) - 1)] + [_ow[-1]]
OPEN = [dict(r, ow=w) for r, w in zip(OPEN, _ow)]
Z_OPEN_TOP, Z_OPEN_BOT = OPEN[-1]["z"], OPEN[0]["z"]
TW = SPEC["trim_w"]


def opening_w(zz):
    if zz > Z_OPEN_TOP or zz < Z_OPEN_BOT - 0.06:
        return 0.0
    return interp(OPEN, "ow", zz)


def edge_distance(x, zz):
    """how far (x, z) is inside the trim band's inner edge, seen from the front (0 at that edge, negative outside)"""
    ow = opening_w(zz) - TW
    return min(ow - abs(x), Z_OPEN_TOP - TW - zz, zz - (Z_OPEN_BOT - 0.04))


RECESS = 0.025
for v in hood_verts:
    c = head_c(v.co.z)
    if v.co.y < c:
        e = edge_distance(v.co.x, v.co.z) + TW * 0.5
        if e > 0:
            f = min(1.0, e / 0.07)
            v.co.y += RECESS * (f * f * (3 - 2 * f))

HEAD_C = Vector((0, head_c(1.85), 1.85))

# the tail: a tapered tube along the traced spine, joined to the hood with a smooth union (no seam, no knob)
if SPEC.get("tail") and not os.environ.get("HTD_NO_TAIL"):   # (HTD_NO_TAIL: the same hood without it, the gate's control)
    import vdb_union
    tl = SPEC["tail"]
    tb = bmesh.new()
    TAIL_FAT = float(os.environ.get("HTD_TAIL_FAT", "1.0"))   # (as traced; fuller tails overshot the painting's outline)
    tube(tb, [Vector((0, t["y"], t["z"])) for t in tl], [max(0.012, t["r"] * TAIL_FAT) for t in tl], seg=20, per=6, flat=1.15)
    tb.verts.index_update()
    t_pts = [v.co[:] for v in tb.verts]
    t_faces = [[v.index for v in f.verts] for f in tb.faces]
    tb.free()
    hv = sorted({v for f in hood_faces for v in f.verts}, key=lambda v: v.index)
    idx = {v: i for i, v in enumerate(hv)}
    h_pts = [v.co[:] for v in hv]
    h_faces = [[idx[v] for v in f.verts] for f in hood_faces]
    pts, faces = vdb_union.smooth_union([(h_pts, h_faces), (t_pts, t_faces)], voxel=0.011, k=0.1)
    for f in hood_faces:
        head.tags.pop(f, None)
    bmesh.ops.delete(head.bm, geom=hv, context="VERTS")
    nv = [head.bm.verts.new(p) for p in pts.tolist()]
    new_faces = []
    for f in faces:
        try:
            new_faces.append(head.bm.faces.new([nv[i] for i in f]))
        except ValueError:
            pass
    head.add(new_faces, "hood")
    hood_faces = new_faces
    print("TAIL joined:", len(new_faces), "faces in the hood")


def band_loop(bm, pts, half_w, half_t, centre, seg=12, lift=None):
    """a closed flat band (soft rounded-rectangle section) along a closed loop of points, lying on a surface whose
    outward normal is taken from `centre` (a point inside); closed all round, so watertight"""
    n = len(pts)
    rings = []
    for i in range(n):
        p = pts[i]
        t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        nn = (p - centre)
        if lift is not None:
            nn = Vector((nn.x, nn.y, nn.z * lift))
        nn = (nn - t * nn.dot(t)).normalized()
        b = t.cross(nn).normalized()
        q = p + nn * half_t
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            cu, su = math.cos(a), math.sin(a)
            u = math.copysign(abs(cu) ** 0.5, cu) * half_w
            w = math.copysign(abs(su) ** 0.5, su) * half_t
            ring.append(q + b * u + nn * w)
        rings.append(ring)
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    faces = []
    for i in range(n):
        a, b2 = vs[i], vs[(i + 1) % n]
        for k in range(seg):
            j = (k + 1) % seg
            faces.append(bm.faces.new((a[k], a[j], b2[j], b2[k])))
    return faces


# the cream trim: a wide flat band round the opening, closed under the chin
loop = []
for r in OPEN:
    loop.append((-(r["ow"] - TW / 2), r["z"]))
loop.append((0.0, Z_OPEN_TOP - TW / 2 + 0.005))
for r in reversed(OPEN):
    loop.append((r["ow"] - TW / 2, r["z"]))
xb = OPEN[0]["ow"] - TW / 2
for k in range(1, 8):     # under the chin, right to left, dipping a little
    x = xb - 2 * xb * k / 8
    loop.append((x, Z_OPEN_BOT + TW * 0.3))   # resting on the chin's rim, not hanging below it
pts = []
for x, zz in loop:
    y, _ = head_surface(x, max(zz, SPEC["head"][-1]["z"]))
    sink = 0.016 * max(0.0, min(1.0, (zz - (Z_OPEN_TOP - 0.2)) / 0.15))   # over the brow it lies flush: no lip in profile
    pts.append(Vector((x, y + sink, zz)))
head.add(band_loop(head.bm, pts, TW / 2, 0.016, HEAD_C), "cream")

# the hair: big flat locks across the forehead and down by the cheeks, lying on the face under the trim
# three broad swept locks along the fringe line of the front painting, parted a little left of the middle, each a
# flattened leaf with a soft point (round B: the forehead read as a row of small curls)
LOCKS = [(-0.17, 0.12, -0.45), (-0.02, 0.14, -0.25), (0.14, 0.13, 0.38)]   # (kept well inside the opening)
for x, ln, tilt in LOCKS:
    zt = Z_OPEN_TOP - TW
    while opening_w(zt) - TW < abs(x) + 0.05 and zt > Z_OPEN_BOT:
        zt -= 0.005
    y0, _ = head_surface(x, zt)
    a = Vector((x, y0 + RECESS * 0.6, zt - 0.025))    # (its top tucked under the trim)
    b = a + Vector((math.sin(tilt) * ln, -0.025, -math.cos(tilt) * ln))
    head.add(tube(head.bm, [a, (a + b) / 2 + Vector((0, -0.025, 0)), b], [0.11, 0.1, 0.03], seg=12, per=4, flat=0.32, nvec=(0, 1, 0)), "hair")
for s in (-1, 1):       # side locks by the cheeks
    zt = 1.8
    x = s * (opening_w(zt) - TW - 0.12)      # (by the cheek, clear of the eye, inside the opening's outline seen side-on)
    y0, _ = head_surface(x * 0.95, zt)
    a = Vector((x, y0 + RECESS * 0.7, zt))
    b = a + Vector((-s * 0.03, 0.0, -0.17))
    head.add(tube(head.bm, [a, (a + b) / 2 + Vector((s * 0.01, -0.012, 0)), b], [0.065, 0.058, 0.025], seg=12, per=3, flat=0.6,
                  nvec=(s * 0.9, 0.45, 0)), "hair")

# ---------------------------------------------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------------------------------------------
body = Part("Body")
torso_rows = [dict(r) for r in SPEC["torso"]]
top = max(torso_rows, key=lambda r: r["z"])
for dz, f in ((0.05, 0.85), (0.1, 0.6)):     # up inside the hood: nothing to see through at the neck
    torso_rows.append(dict(top, z=top["z"] + dz, hw=top["hw"] * f))
body.add(loft(body.bm, torso_rows, n_front=2.6, n_back=2.6), "tunic")


def torso_surface(x, zz, side=-1, n=2.6):
    """the torso's surface y at (x, z), front (side -1) or back (+1)"""
    hw = interp(torso_rows, "hw", zz)
    fr, bk = interp(torso_rows, "front", zz), interp(torso_rows, "back", zz)
    c, d = (fr + bk) / 2, (bk - fr) / 2
    u = min(abs(x) / hw, 0.98)
    cos_t = u ** (n / 2)
    sin_t = math.sqrt(max(0.0, 1 - cos_t * cos_t))
    return c + side * d * sin_t ** (2 / n)


def band(part, z0, z1, grow, pal, rows=None, cx=0.0):
    rows = rows or torso_rows
    rr = [dict(hw=interp(rows, "hw", zz), front=interp(rows, "front", zz), back=interp(rows, "back", zz), z=zz, cx=cx)
          for zz in (z0, (z0 + z1) / 2, z1)]
    return part.add(loft(part.bm, rr, grow=grow, n_front=2.6, n_back=2.6), pal)


band(body, SPEC["belt"]["z0"], SPEC["belt"]["z1"], 0.024, "leather")
band(body, SPEC["hem"]["z0"], SPEC["hem"]["z1"], 0.016, "lime")
# the collar roll where the hood meets the shoulders
co = SPEC["collar"]
cz = co["z"] - 0.005
fr, bk = interp(torso_rows, "front", cz) - 0.05, interp(torso_rows, "back", cz) + 0.05
cc, cd = (fr + bk) / 2, (bk - fr) / 2
cring = []
for k in range(32):
    a = 2 * math.pi * k / 32
    cs, sn = math.cos(a), math.sin(a)
    cring.append(Vector((math.copysign(abs(cs) ** (2 / 2.4), cs) * co["hw"], cc + math.copysign(abs(sn) ** (2 / 2.4), sn) * cd, cz)))
body.add(band_loop(body.bm, cring, co["r"] * 0.95, co["r"] * 0.95, Vector((0, cc, cz - 0.25)), seg=12), "roll")   # a soft round roll on the shoulders
# the big gold buckle: a chunky square frame on the belt
bz0, bz1, bhw, bar = SPEC["buckle"]["z0"], SPEC["buckle"]["z1"], SPEC["buckle"]["hw"], SPEC["buckle"]["bar"]
by = torso_surface(0, (bz0 + bz1) / 2) - 0.035
for c, s in (((0, by, bz1 - bar / 2), (bhw, 0.022, bar / 2)), ((0, by, bz0 + bar / 2), (bhw, 0.022, bar / 2)),
             ((-bhw + bar / 2, by, (bz0 + bz1) / 2), (bar / 2, 0.022, (bz1 - bz0) / 2)),
             ((bhw - bar / 2, by, (bz0 + bz1) / 2), (bar / 2, 0.022, (bz1 - bz0) / 2)),
             ((-bhw / 2 + bar / 2, by + 0.004, (bz0 + bz1) / 2), (bhw / 2, 0.02, 0.011))):   # the prong, across
    body.add(box(body.bm, c, (s[0] * 2, s[1] * 2, s[2] * 2)), "gold")
# the tunic's front split with lime edging, the trousers showing in it
sp = SPEC["split"]
for s in (-1, 1):
    pa = Vector((s * sp["top_w"], torso_surface(s * sp["top_w"], sp["z1"]) - 0.006, sp["z1"]))
    pb = Vector((s * sp["bottom_w"], torso_surface(s * sp["bottom_w"], sp["z0"]) - 0.012, sp["z0"] + 0.01))
    body.add(tube(body.bm, [pa, pb], [sp["w"] / 2], seg=10, per=3, flat=0.45, nvec=(0, 1, 0)), "lime")

# the chest strap: over his left shoulder, across the chest to his right hip, round the back (a closed band)
st = SPEC["strap"]
(x0, z0), (x1, z1) = st["from"], st["to"]
spts = []
for k in range(10):                       # front, shoulder to hip
    t = k / 9
    x, zz = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
    spts.append(Vector((x, torso_surface(x, zz, -1) - 0.004, zz)))
xs = x1 - 0.06
yc = (torso_surface(xs, z1, -1) + torso_surface(xs, z1, 1)) / 2
yd = (torso_surface(xs, z1, 1) - torso_surface(xs, z1, -1)) / 2
for k in range(1, 4):                     # round his right side
    a = math.pi * k / 4
    spts.append(Vector((xs - math.sin(a) * 0.06, yc - math.cos(a) * yd, z1)))
for k in range(10):                       # back, hip to shoulder
    t = k / 9
    x, zz = x1 + (x0 - x1) * t, z1 + (z0 - z1) * t
    spts.append(Vector((x, torso_surface(x, zz, 1) + 0.004, zz)))
yc = (torso_surface(x0, z0, -1) + torso_surface(x0, z0, 1)) / 2
yd = (torso_surface(x0, z0, 1) - torso_surface(x0, z0, -1)) / 2
for k in range(1, 4):                     # over his left shoulder
    a = math.pi * k / 4
    spts.append(Vector((x0, yc + math.cos(a) * yd, z0 + math.sin(a) * 0.06)))
tc = Vector((0, (interp(torso_rows, "front", 1.2) + interp(torso_rows, "back", 1.2)) / 2, 1.2))
body.add(band_loop(body.bm, spts, st["w"] / 2, 0.012, tc, lift=0.0), "strap")
bx, bz = st["buckle"]
bby = torso_surface(bx, bz) - 0.026
for c, s in (((bx, bby, bz + 0.04), (0.048, 0.013, 0.011)), ((bx, bby, bz - 0.04), (0.048, 0.013, 0.011)),
             ((bx - 0.04, bby, bz), (0.011, 0.013, 0.048)), ((bx + 0.04, bby, bz), (0.011, 0.013, 0.048))):
    body.add(box(body.bm, c, (s[0] * 2, s[1] * 2, s[2] * 2)), "gold")
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
                            for zz in (bc["z0"], (bc["z0"] + bc["z1"]) / 2, bc["z1"])], grow=0.03, seg=24), "boot_cuff")
    zs = SPEC["sole"]["z1"]
    body.add(loft(body.bm, [dict(hw=interp(boot, "hw", zz), front=interp(boot, "front", zz), back=interp(boot, "back", zz), z=zz, cx=interp(boot, "cx", zz))
                            for zz in (0.003, zs / 2, zs)], grow=0.014, seg=24, n_front=2.2, n_back=2.6), "sole")

# ---------------------------------------------------------------------------------------------------------------
# Arms (character's right arm at -X): short sleeve, wide lime cuff, bare forearm, big bracer with raised edges, fist
# ---------------------------------------------------------------------------------------------------------------
arms = []
A = SPEC["arm"]


def rounded_box(bm, c, size, frame, e=4.0, seg=20, rings=12):
    """a soft box (superellipsoid) at c with half sizes `size` along the frame's axes (x, y, z)"""
    ax, ay, az = frame
    rs = []
    for k in range(1, rings):
        ph = -math.pi / 2 + math.pi * k / rings
        cp, sp_ = math.cos(ph), math.sin(ph)
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            ct, st_ = math.cos(th), math.sin(th)
            fx = math.copysign(abs(cp) ** (2 / e), cp) * math.copysign(abs(ct) ** (2 / e), ct)
            fy = math.copysign(abs(cp) ** (2 / e), cp) * math.copysign(abs(st_) ** (2 / e), st_)
            fz = math.copysign(abs(sp_) ** (2 / e), sp_)
            ring.append(Vector(c) + ax * (fx * size[0]) + ay * (fy * size[1]) + az * (fz * size[2]))
        rs.append(ring)
    return shell_from_rings(bm, rs, Vector(c) + az * size[2], Vector(c) - az * size[2])


for name, s in (("ArmR", 1), ("ArmL", -1)):
    p = Part(name)

    def m(v):
        return Vector((v[0] * s, v[1], v[2]))
    p.add(tube(p.bm, [m(v) for v in A["sleeve"]["path"]], A["sleeve"]["r"], seg=16), "tunic")
    cu = A["cuff"]
    d = Vector((cu["dir"][0] * s, cu["dir"][1], cu["dir"][2])).normalized()
    p.add(tube(p.bm, [m(cu["at"]) - d * cu["w"] / 2, m(cu["at"]) + d * cu["w"] / 2], [cu["r"]], seg=16, per=2), "lime")
    p.add(tube(p.bm, [m(v) for v in A["fore"]["path"]], A["fore"]["r"], seg=14), "skin")
    bp = [m(v) for v in A["bracer"]["path"]]
    p.add(tube(p.bm, bp, A["bracer"]["r"], seg=16), "bracer")
    bd = (bp[-1] - bp[0]).normalized()
    for end, rr in ((bp[0] + bd * 0.012, A["bracer"]["r"][0]), (bp[-1] - bd * 0.012, A["bracer"]["r"][-1])):   # raised edges
        p.add(tube(p.bm, [end - bd * 0.012, end + bd * 0.012], [rr * 1.08], seg=16, per=2), "bracer_edge")
    fi = A["fist"]
    fc = m(fi["at"])
    az = (bp[-1] - bp[0]).normalized()          # the fist continues the forearm
    ay_ = Vector((0, -1, 0))                    # knuckles to the front
    ax_ = ay_.cross(az).normalized()
    ay_ = az.cross(ax_).normalized()
    sz = fi["size"]
    p.add(rounded_box(p.bm, fc, (sz[0], sz[1], sz[2]), (ax_, ay_, az), e=3.0), "skin")
    # the thumb on the inner side, and finger lines (thin darker grooves across the knuckles)
    tcen = fc + ax_ * (-s * sz[0] * 0.55) + ay_ * (sz[1] * 0.75) + az * (sz[2] * 0.25)
    p.add(ellipsoid(p.bm, tcen, (sz[0] * 0.32, sz[1] * 0.35, sz[2] * 0.5), seg=12, rings=8), "skin")
    for k in (-1, 0, 1):
        q = fc + ay_ * (sz[1] * 0.98) + az * (k * sz[2] * 0.35 - sz[2] * 0.1)
        p.add(tube(p.bm, [q - ax_ * sz[0] * 0.55, q + ax_ * sz[0] * 0.55], [0.006], seg=6, per=2), "skin_line")
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
PAL["roll"] = [(a + b) / 2 for a, b in zip(PAL["hood"], PAL["lime"])]   # the collar roll: the hood's cloth, catching light
PAL["boot_cuff"] = [min(1.0, v * 1.06) for v in PAL["boot"]]
PAL["bracer_edge"] = [v * 0.78 for v in PAL["bracer"]]
PAL["skin_line"] = [v * 0.8 for v in PAL["skin"]]


def to_object(part):
    mesh = bpy.data.meshes.new(part.name)
    bm = part.bm
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))   # outward on every closed shell
    bm.normal_update()
    col = bm.loops.layers.float_color.new("pal")
    facew = bm.loops.layers.float_color.new("facew")
    keepw = bm.loops.layers.float_color.new("keepw")   # kept from the plain bake by the painterly pass (the trim)
    for f in bm.faces:
        c = lin(PAL[part.tags.get(f, "hood")]) + (1.0,)
        for loop in f.loops:
            w = 0.0
            if part.name == "Head" and part.tags.get(f) == "hood":
                v = loop.vert.co
                ctr = head_c(v.z)
                if v.y < ctr:
                    e = edge_distance(v.x, v.z)
                    if e > 0:
                        w = max(0.0, min(1.0, (e - 0.01) / 0.04))
                        # only where the surface looks to the front: the painting is never stretched round a side
                        nf = max(0.0, min(1.0, (-loop.vert.normal.y - 0.55) / 0.25))
                        # and not where it turns down under the chin (a flat skin strip at oblique angles)
                        nd = max(0.0, min(1.0, (loop.vert.normal.z + 0.75) / 0.2))   # (only faces turned well down)
                        w *= nf * nd
                        # inside the opening, wherever the painting does not reach: the hood's own dark inside
                        c = lin(PAL["hood_inner"]) + (1.0,)
            loop[col] = c
            loop[facew] = (w, w, w, 1.0)
            k = 1.0 if (part.name == "Head" and part.tags.get(f) in ("cream", "hair")) else 0.0   # (smooth as baked)
            loop[keepw] = (k, k, k, 1.0)
    bm.to_mesh(mesh)
    o = bpy.data.objects.new(part.name, mesh)
    bpy.context.scene.collection.objects.link(o)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return o


def material(o, image=None):
    """image: project this picture instead of the front painting and return only it, where the face is (no palette,
    no light): used to bake the face marks' mask (eyes, brows, mouth) for the painterly pass"""
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
    tex.image = image or img
    tex.interpolation = "Cubic"
    tex.extension = "EXTEND"
    nt.links.new(comb.outputs[0], tex.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(fw.outputs["Color"], mix.inputs["Factor"])
    nt.links.new(pal.outputs["Color"], mix.inputs["A"])
    nt.links.new(tex.outputs["Color"], mix.inputs["B"])
    if image is not None:
        nt.links.remove(mix.inputs["A"].links[0])
        mix.inputs["A"].default_value = (0, 0, 0, 1)
        kw = nt.nodes.new("ShaderNodeVertexColor")
        kw.layer_name = "keepw"
        light = nt.nodes.new("ShaderNodeMix")
        light.data_type = "RGBA"
        light.blend_type = "LIGHTEN"
        light.inputs["Factor"].default_value = 1.0
        nt.links.new(mix.outputs["Result"], light.inputs["A"])
        nt.links.new(kw.outputs["Color"], light.inputs["B"])
        nt.links.new(light.outputs["Result"], emit.inputs["Color"])
        return mat, nt
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
    shade.inputs[1].default_value = 0.22   # (a light touch: the game lights the mesh too)
    shade.inputs[2].default_value = 0.82
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 48
    ao.only_local = True     # (no hard dark rings where one part runs into another)
    ao.inputs["Distance"].default_value = 0.25
    aom = nt.nodes.new("ShaderNodeMath")
    aom.operation = "MULTIPLY_ADD"    # AO 0..1 -> 0.6..1
    nt.links.new(ao.outputs["AO"], aom.inputs[0])
    aom.inputs[1].default_value = 0.2
    aom.inputs[2].default_value = 0.8
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
    fwm.inputs[1].default_value = 1.0     # the face keeps the painting's own colours: no baked light on it
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
    jumps, where = [], []
    for key, sides in by_edge.items():
        if len(sides) != 2:
            continue
        (x0, y0, a0, b0), (x1, y1, a1, b1) = sides
        if (a0 - a1).length < 1e-4 and (b0 - b1).length < 1e-4:
            continue    # not a seam
        c0 = sample(px, x0, y0)
        c1 = sample(px, x1, y1)
        jumps.append(float(np.abs(c0 - c1).max()) * 255)
        where.append((jumps[-1], (o.data.vertices[key[0]].co + o.data.vertices[key[1]].co) / 2))
    where.sort(key=lambda t: -t[0])
    for j, c in where[:4]:
        print("  SEAM JUMP %.0f at (%.2f, %.2f, %.2f)" % (j, c.x, c.y, c.z))
    jumps.sort()
    p99 = jumps[int(len(jumps) * 0.99)] if jumps else 0
    GATES.setdefault("seam", {})[o.name] = {"edges": len(jumps), "p99": round(p99, 1), "max": round(jumps[-1], 1) if jumps else 0}
    print("SEAM", o.name, len(jumps), "seam edges, 99th percentile jump %.1f /255" % p99, "ok" if p99 <= 14 else "FAIL")


def bake_keep(o, size):
    """the face (the front painting's part of the head) as a white-on-black picture in the head's own texture
    layout: the painterly pass keeps it exactly (scripts/archer_paint.py, the pets' _keep.png)"""
    import numpy as np
    # the whole face (where the front painting is used): the painterly pass keeps it as painted; boxes round the
    # marks alone left square patches of two skin tones
    m = np.ones((IH, IW), dtype=np.float32)
    mimg = bpy.data.images.new("marks", IW, IH)
    mimg.pixels.foreach_set(np.dstack([np.flipud(m)] * 3 + [np.ones_like(m)]).astype(np.float32).ravel())
    mat, nt = material(o, image=mimg)
    o.data.materials.clear()
    o.data.materials.append(mat)
    keep = bpy.data.images.new(o.name + "_keep", size, size)
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = keep
    nt.nodes.active = node
    bpy.context.scene.cycles.samples = 4
    bpy.ops.object.bake(type="EMIT")
    bpy.context.scene.cycles.samples = 96
    keep.filepath_raw = os.path.join(OUT, f"{NAME}_head_keep.png")
    keep.file_format = "PNG"
    keep.save()


def bake(o, size):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    o.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(88 if o.name == "Head" else 72), island_margin=0.012, area_weight=0.0, scale_to_bounds=True)
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
    sc.render.bake.margin = 16   # (every island padded well past 8 px)
    bpy.ops.object.bake(type="EMIT")
    path = os.path.join(OUT, f"{NAME}_{o.name.lower()}_paint.png")
    tex.filepath_raw = path
    tex.file_format = "PNG"
    tex.save()
    if o.name == "Head" and SPEC.get("marks"):
        bake_keep(o, size)
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
    # the triangle reduction can turn faces over (the face's recess came out inside-out: Roblox shows only the
    # front of a face, so you looked through his face): every shell's faces outward again
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(o.data)
    bad = len([e for e in bm.edges if len(e.link_faces) != 2])
    # gate: faces that run an edge the same way as their neighbour (turned over), and shells with negative volume
    turned = 0
    for e in bm.edges:
        if len(e.link_loops) == 2:
            l1, l2 = e.link_loops
            if l1.vert == l2.vert:
                turned += 1
    GATES.setdefault("turned", {})[o.name] = turned
    print("FACING (final)", o.name, "ok" if turned == 0 else f"FAIL {turned} edges between turned-over faces")
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
        # high on his back, top over his right shoulder: the feathers show beside the hood from the front (the painting)
        import numpy as np
        from mathutils import Matrix
        co = np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices])
        mean = co.mean(axis=0)
        w, vec = np.linalg.eigh(np.cov((co - mean).T))
        axis = Vector(vec[:, -1])
        proj = (co - mean) @ np.array(axis)
        if co[proj.argmax()][2] < co[proj.argmin()][2]:
            axis = -axis                                      # the end with the feathers up
        length = float(proj.max() - proj.min())
        d = Vector((-0.55, 0.1, 0.83)).normalized()
        rot = axis.rotation_difference(d).to_matrix().to_4x4()
        top = Vector((-0.58, 0, 1.64))
        centre = top - d * (length / 2)
        centre.y = interp(torso_rows, "back", 1.25) + 0.15
        o.matrix_world = Matrix.Translation(centre) @ rot @ Matrix.Translation(-Vector(mean)) @ o.matrix_world
    shutil.copy(os.path.join(os.path.dirname(OLD), f"{NAME}_{base.lower()}_paint.png"), os.path.join(OUT, f"{NAME}_{base.lower()}_paint.png"))

for o, size in zip(objs, (1024, 1024, 512, 512)):
    bake(o, size)

import lib  # noqa: E402
out_fbx = os.path.join(OUT, NAME + ".fbx")
# no vertex colours in the file: Roblox multiplies the texture by them (the build's palette and face-weight layers
# made his face dark green and the hood lime in game)
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        for ca in list(o.data.color_attributes):
            o.data.color_attributes.remove(ca)
lib.export_fbx(out_fbx)
json.dump(GATES, open(os.path.join(OUT, "gates_build.json"), "w"), indent=1)
print("HEIGHT %.2f" % SPEC["height"])
print("EXPORTED", out_fbx)
