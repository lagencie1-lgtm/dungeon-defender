"""Rigs an image-to-3D monster (Tripo .glb) for Roblox: a humanoid skeleton placed from the mesh's own shape,
automatic skin weights cleaned for Roblox (4 bones per vertex, head and weapon rigid), checked in test poses.

Run: blender --background --python art/blender/rig_monster.py -- in.glb out.fbx goblin [height=2.8] [sheets_dir]

What it does
  1 imports the model, joins it into one mesh, applies its transforms, merges split seams, drops vertex colours,
    keeps the UVs and texture (shrunk to 1024 and packed into the FBX), stands it on the ground, Height studs tall.
  2 finds the body's landmarks from the front silhouette and slices of vertices: feet (lowest clusters), crotch
    (where the legs part), hands (furthest-out clusters), armpits (where the gap between arm and body closes),
    neck (narrowest row between shoulders and head), weapon (a separate piece sticking out of a hand, if any).
  3 builds Root, Hips, Spine, Chest, Neck, Head, UpperArm/LowerArm/Hand L+R, UpperLeg/LowerLeg/Foot L+R (+ Weapon).
  4 binds with automatic weights. Cuts welds where an arm's mesh is fused to a leg or the body well below the
    armpit (fingers touching the thigh), then binds again. Each vertex may then only follow the limb its weights
    mostly belong to plus the joint it hangs from (automatic weights leak: belly on the thigh, chest on the arm,
    shoulder pads on the head). Zero-weight vertices get their nearest bone; limits to 4 bones, normalizes, smooths
    once, makes the head (and weapon) rigid.
  5 poses it at the angles monsters really use (arms up 60, swing 100, knees bent 45, head turned 25; RIG_POSES=stress
    for 90 / 120 / 40), measures edge stretch against the rest pose,
    smooths the weights around edges over 1.6x for up to 12 rounds and keeps the round with the fewest visible ones
    (over 1.6x and grown by more than 1% of the height). RIG_DEBUG=1 prints where the worst ones are.
  6 renders each pose from 8 sides, painted and grey, as contact sheets (when sheets_dir is given), exports the FBX
    (armature parent of the mesh, no leaf bones) and prints the numbers.
Front faces -Y (like the other models in art/blender). Left of the monster = +X.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, NAME = os.path.abspath(args[0]), os.path.abspath(args[1]), args[2]
HEIGHT = float(args[3]) if len(args) > 3 else 2.8
SHEETS = os.path.abspath(args[4]) if len(args) > 4 else None
MAX_TRIS = 20000
STRETCH_LIMIT = 1.6
DEBUG = os.environ.get("RIG_DEBUG") == "1"
VISIBLE = 0.01  # x height: an edge over the limit that also grows by more than this is one you can see


def log(*a):
    print("[RIG]", *a, flush=True)


# ---------------------------------------------------------------------------------------------------------------
# 1 import and clean
# ---------------------------------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(SRC)[1].lower()
if ext in (".glb", ".gltf"):
    bpy.ops.import_scene.gltf(filepath=SRC)
elif ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=SRC)
else:
    sys.exit("unknown model format: " + ext)

for o in [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]:
    bpy.data.objects.remove(o)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.active_object
body.name = "Body"  # the game paints the part called Body with paint_<model> (ArtService)
body.data.name = NAME
for mod in list(body.modifiers):
    body.modifiers.remove(mod)
for o in list(bpy.context.scene.objects):
    if o is not body:
        bpy.data.objects.remove(o)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = body.data
for attr in list(me.color_attributes):
    me.color_attributes.remove(attr)
# merge the seams the generator split apart (UVs live on the corners, so they stay)
lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
bm = bmesh.new()
bm.from_mesh(me)
before = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=(hi - lo).length * 1e-5)
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
bm.to_mesh(me)
bm.free()
log("merged seams: %d -> %d vertices" % (before, len(me.vertices)))
tris = len(me.polygons)
if tris > MAX_TRIS:
    dec = body.modifiers.new("dec", "DECIMATE")
    dec.ratio = MAX_TRIS / tris * 0.98
    bpy.ops.object.modifier_apply(modifier="dec")
    tris = len(me.polygons)
# stand on the ground, centred, HEIGHT tall
lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
k = HEIGHT / (hi.z - lo.z)
# centred on where it stands (the lowest tenth: feet), not on its box: a long tail would pull the box back
low = [v.co for v in me.vertices if v.co.z < lo.z + (hi.z - lo.z) * 0.1]
cx_, cy_ = sum(c.x for c in low) / len(low), sum(c.y for c in low) / len(low)
me.transform(Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation((-cx_, -cy_, -lo.z)))
me.update()
H = HEIGHT
P = [v.co.copy() for v in me.vertices]
NV = len(P)
log("triangles %d, vertices %d, height %.2f" % (tris, NV, H))

# texture: shrink to 1024 and pack, so the FBX carries it (and save it beside the FBX for the game's own use)
image = None
for mat in me.materials:
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                image = n.image
if image:
    if image.size[0] > 1024:
        image.scale(1024, 1024)
    image.filepath_raw = OUT[:-4] + "_paint.png"
    image.file_format = "PNG"
    image.save()
    image.pack()
    log("texture", image.filepath_raw, tuple(image.size))

# neighbours, for weight smoothing and islands
NEIGH = [[] for _ in range(NV)]
for e in me.edges:
    a, b = e.vertices
    NEIGH[a].append(b)
    NEIGH[b].append(a)
EDGES = [tuple(e.vertices) for e in me.edges]

# ---------------------------------------------------------------------------------------------------------------
# 2 landmarks
# ---------------------------------------------------------------------------------------------------------------
GX, GZ = 160, 200  # the front silhouette as a grid of cells (x across, z up)
XMAX = max(abs(p.x) for p in P) * 1.02
cell_x, cell_z = 2 * XMAX / GX, H / GZ
grid = [[False] * GX for _ in range(GZ)]


def gx(x):
    return min(GX - 1, max(0, int((x + XMAX) / cell_x)))


def gz(z):
    return min(GZ - 1, max(0, int(z / cell_z)))


def cx(i):
    return -XMAX + (i + 0.5) * cell_x


def cz(j):
    return (j + 0.5) * cell_z


for poly in me.polygons:
    a, b, c = (P[i] for i in poly.vertices[:3])
    span = max((a - b).length, (b - c).length, (c - a).length)
    n = max(2, int(span / min(cell_x, cell_z) * 2) + 1)
    for i in range(n + 1):
        for j in range(n + 1 - i):
            p = a + (b - a) * (i / n) + (c - a) * (j / n)
            grid[gz(p.z)][gx(p.x)] = True

CENTER = gx(0.0)


def slice_verts(z0, z1, pred=None):
    return [p for p in P if z0 <= p.z < z1 and (pred is None or pred(p))]


def mean(ps):
    if not ps:
        return Vector()
    s = Vector()
    for p in ps:
        s += p
    return s / len(ps)


# crotch: the lowest row where the centre column is filled again above the gap between the legs
crotch_row = None
for j in range(GZ):
    if j > 2 and grid[j][CENTER] and not grid[j - 1][CENTER]:
        crotch_row = j
        break
    if j < 2 and grid[j][CENTER]:
        break  # a robe or blob down to the ground: no gap
crotch_z = cz(crotch_row) if crotch_row else 0.3 * H
if not crotch_row:
    log("no gap between the legs found: crotch at 30% of the height")

# feet: lowest clusters per side
feet = {}
for side, s in (("L", 1), ("R", -1)):
    ps = slice_verts(0, 0.06 * H, lambda p: p.x * s > 0)
    feet[side] = mean(ps) if ps else Vector((s * 0.15 * H, 0, 0))

# hands: per side, the lowest part of the outermost reach (below the head): the fist and its fingers
hands = {}
for side, s in (("L", 1), ("R", -1)):
    body_ps = [p for p in P if p.z < 0.6 * H and p.x * s > 0]
    far = max(p.x * s for p in body_ps)
    outer = [p for p in body_ps if p.x * s > far * 0.7]
    bottom = min(p.z for p in outer)
    ps = [p for p in outer if p.z < bottom + 0.11 * H]
    hands[side] = {"c": mean(ps), "top": bottom + 0.11 * H, "bottom": bottom}


def row_gap(j, s, start_i):
    """True if, walking from the arm's column toward the centre in row j, an empty cell comes after the arm."""
    i = start_i
    step = -1 if s > 0 else 1
    seen_fill = False
    while i != CENTER:
        if grid[j][i]:
            if seen_fill is None:
                return True  # filled again after an empty stretch: a gap between arm and body
            seen_fill = True
        elif seen_fill:
            seen_fill = None
        i += step
    return False


# armpits: going up from the hand, the first row where the gap between arm and body closes
shoulders, armpit_z, arm_inner_pit = {}, {}, {}
for side, s in (("L", 1), ("R", -1)):
    hc = hands[side]["c"]
    j0 = gz(hands[side]["top"])
    pit = None
    for j in range(j0, gz(0.85 * H)):
        # the arm's outer edge in this row
        cols = [i for i in range(GX) if grid[j][i] and (cx(i) * s > 0)]
        if not cols:
            continue
        outer = max(cols) if s > 0 else min(cols)
        if not row_gap(j, s, outer):
            pit = j
            break
    if pit is None:
        pit = gz(hands[side]["top"] + 0.15 * H)
    armpit_z[side] = cz(pit)
    # the arm in the row just below the armpit: from its outer edge inward to the gap
    j = max(0, pit - 2)
    cols = [i for i in range(GX) if grid[j][i] and cx(i) * s > 0]
    outer_i = max(cols) if s > 0 else min(cols)
    inner_i = outer_i
    step = -1 if s > 0 else 1
    while inner_i != CENTER and grid[j][inner_i + step]:
        inner_i += step
    outer_x, inner_x = abs(cx(outer_i)), abs(cx(inner_i))
    arm_inner_pit[side] = inner_x
    arm_w = max(0.04 * H, outer_x - inner_x)
    sx = (outer_x + inner_x) / 2
    sz = armpit_z[side] + arm_w * 0.35
    near = [p for p in P if abs(p.z - sz) < 0.04 * H and abs(p.x * s - sx) < arm_w * 0.6]
    shoulders[side] = Vector((sx * s, mean(near).y if near else 0.0, sz))

shoulder_z = (shoulders["L"].z + shoulders["R"].z) / 2


# neck: the narrowest row of the silhouette (the run of cells touching the centre) between shoulders and the top
def row_width(j):
    if not grid[j][CENTER]:
        return 0
    a = b = CENTER
    while a > 0 and grid[j][a - 1]:
        a -= 1
    while b < GX - 1 and grid[j][b + 1]:
        b += 1
    return (b - a + 1) * cell_x


# the chin: going up from the shoulders, the first row where the front of the middle of the body jumps forward
# (the face sticks out past the neck); the neck joint sits just under it
chin_z = None
prev = None
for j in range(gz(shoulder_z - 0.05 * H), gz(0.9 * H)):
    z0, z1 = j * cell_z, (j + 1) * cell_z
    mid = [p for p in P if z0 <= p.z < z1 and abs(p.x) < 0.06 * H]
    if not mid:
        continue
    front = min(p.y for p in mid)
    if prev is not None and front < prev - 0.06 * H and z0 > shoulder_z - 0.02 * H:
        chin_z = z0
        break
    prev = front if prev is None else max(front, prev * 0.5 + front * 0.5)
if chin_z is None:
    # no chin found: the narrowest row between the shoulders and the head's widest row (ears and all)
    widest = max(range(gz(shoulder_z + 0.08 * H), gz(H * 0.95)), key=row_width)
    best = None
    for j in range(gz(shoulder_z + 0.02 * H), widest):
        w = row_width(j)
        if w > 0 and (best is None or w < best[0]):
            best = (w, j)
    chin_z = cz(best[1]) if best else shoulder_z + 0.08 * H
    log("no chin found: neck at the narrowest row")
neck_z = max(chin_z - 0.01 * H, shoulder_z + 0.03 * H)


def spine_y(z):
    ps = [p for p in P if abs(p.z - z) < 0.03 * H and abs(p.x) < 0.12 * H]
    return mean(ps).y if ps else 0.0


hip_z = crotch_z + 0.04 * H
chest_z = hip_z + (shoulder_z - hip_z) * 0.55
spine_z = hip_z + (shoulder_z - hip_z) * 0.15
log("landmarks: crotch %.2f hips %.2f chest %.2f shoulders %.2f neck %.2f top %.2f" % (
    crotch_z, hip_z, chest_z, shoulder_z, neck_z, H))
for side in ("L", "R"):
    log("  %s hand %s shoulder %s foot %s" % (side, tuple(round(v, 2) for v in hands[side]["c"]),
                                             tuple(round(v, 2) for v in shoulders[side]),
                                             tuple(round(v, 2) for v in feet[side])))

# weapon: a separate piece of mesh near the right hand that reaches well past it
weapon = None
seen = [False] * NV
islands = []
for v in range(NV):
    if seen[v]:
        continue
    stack, comp = [v], []
    seen[v] = True
    while stack:
        a = stack.pop()
        comp.append(a)
        for b in NEIGH[a]:
            if not seen[b]:
                seen[b] = True
                stack.append(b)
    islands.append(comp)
hr = hands["R"]["c"]
for comp in islands:
    if len(comp) < 20 or len(comp) > NV * 0.4:
        continue
    pts = [P[i] for i in comp]
    near = min((p - hr).length for p in pts)
    reach = max((p - hr).length for p in pts)
    if near < 0.05 * H and reach > 0.3 * H:
        weapon = comp
        log("weapon found: %d vertices, reaching %.2f from the right hand" % (len(comp), reach))
        break
if not weapon:
    log("no weapon: nothing reaches out of the right hand")

# ---------------------------------------------------------------------------------------------------------------
# 3 armature
# ---------------------------------------------------------------------------------------------------------------
arm_data = bpy.data.armatures.new(NAME + "_rig")
rig = bpy.data.objects.new(NAME + "_rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones
bones = {}


def bone(name, head, tail, parent=None, connect=False, roll_up=None):
    b = eb.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    if parent:
        b.parent = bones[parent]
        b.use_connect = connect
    if roll_up is not None:
        b.align_roll(Vector(roll_up))
    bones[name] = b
    return b


FWD = Vector((0, -1, 0))
neck_y = spine_y(neck_z)
bone("Root", (0, 0, 0), (0, 0, 0.12 * H), roll_up=FWD)
bone("Hips", (0, spine_y(hip_z), hip_z), (0, spine_y(spine_z), spine_z), "Root", roll_up=FWD)
bone("Spine", (0, spine_y(spine_z), spine_z), (0, spine_y(chest_z), chest_z), "Hips", True, FWD)
bone("Chest", (0, spine_y(chest_z), chest_z), (0, neck_y, shoulder_z + 0.01 * H), "Spine", True, FWD)
bone("Neck", (0, neck_y, shoulder_z + 0.01 * H), (0, neck_y, neck_z), "Chest", True, FWD)
bone("Head", (0, neck_y, neck_z), (0, neck_y, H), "Neck", True, FWD)
for side, s in (("L", 1), ("R", -1)):
    sh = shoulders[side]
    hc = hands[side]["c"]
    wrist = Vector((hc.x * 0.92 + sh.x * 0.08, hc.y, hands[side]["top"] - (hands[side]["top"] - hc.z) * 0.35))
    elbow = (sh + wrist) / 2 + Vector((0, 0.03 * H, 0))  # elbows sit a little back, so they bend the right way
    tip = Vector((hc.x, hc.y, hands[side]["bottom"] + 0.01 * H))
    bone("UpperArm." + side, sh, elbow, "Chest", roll_up=FWD)
    bone("LowerArm." + side, elbow, wrist, "UpperArm." + side, True, FWD)
    bone("Hand." + side, wrist, tip, "LowerArm." + side, True, FWD)
    f = feet[side]
    # the middle of the leg halfway down (below skirts and tunics, above the boot's flare)
    mid_leg = slice_verts(crotch_z * 0.35, crotch_z * 0.65, lambda p: p.x * s > 0 and p.x * s < abs(hands[side]["c"].x) * 0.7)
    hx = mean(mid_leg).x if mid_leg else f.x
    hip = Vector((hx, spine_y(hip_z), crotch_z))
    ankle = Vector((f.x, f.y + 0.02 * H, max(0.05 * H, crotch_z * 0.22)))
    knee = (hip + ankle) / 2 + Vector((0, -0.03 * H, 0))  # knees a little forward
    toe = Vector((f.x, min(p.y for p in slice_verts(0, 0.05 * H, lambda p: p.x * s > 0)), 0.01 * H))
    bone("UpperLeg." + side, hip, knee, "Hips", roll_up=FWD)
    bone("LowerLeg." + side, knee, ankle, "UpperLeg." + side, True, FWD)
    bone("Foot." + side, ankle, toe, "LowerLeg." + side, True, Vector((0, 0, 1)))
# a tail: mesh well behind the hips, low down (a devil's tail); a chain of 3 bones from the root out
def behind_back(z):
    ps = [p for p in P if abs(p.z - z) < 0.04 * H and abs(p.x) < 0.12 * H]
    return max(p.y for p in ps) if ps else 0.0


TAIL_V, WING_V = [], {"L": [], "R": []}
# (the back is measured at the chest, where no tail hangs; the tail lies low behind it)
back_ref = behind_back(chest_z)
for i, p in enumerate(P):
    if p.z < chest_z and p.y > back_ref + 0.1 * H and abs(p.x) < 0.3 * H:
        TAIL_V.append(i)
if len(TAIL_V) < 20:
    TAIL_V = []
# wings: out past the shoulders, from the armpits up (arms hang below; wings spread out at shoulder height)
for i, p in enumerate(P):
    s = "L" if p.x > 0 else "R"
    if i not in TAIL_V and armpit_z[s] - 0.02 * H < p.z < neck_z + 0.15 * H             and abs(p.x) > abs(shoulders[s].x) + 0.06 * H and p.y > shoulders[s].y - 0.02 * H:
        WING_V[s].append(i)
for s in ("L", "R"):
    if len(WING_V[s]) < 20:
        WING_V[s] = []
TAIL_SET = set(TAIL_V)
WING_SET = set(WING_V["L"]) | set(WING_V["R"])
if TAIL_V:
    pts = [P[i] for i in TAIL_V]
    # the chain starts at the base of the spine (where the tail leaves the body), not at the first tail vertex
    base = Vector((0, back_ref, hip_z))
    root = min(pts, key=lambda p: (p - base).length)
    far = sorted(pts, key=lambda p: (p - root).length)
    joints = [base]
    for q in (0.33, 0.66, 1.0):
        sel = far[int(len(far) * (q - 0.33)):max(int(len(far) * q), 1)]
        joints.append(mean(sel[-max(1, len(sel) // 4):]))
    parent = "Hips"
    for n in range(3):
        bone("Tail%d" % (n + 1), joints[n], joints[n + 1], parent, n > 0, Vector((0, 0, 1)))
        parent = "Tail%d" % (n + 1)
    log("tail: %d vertices, 3 bones" % len(TAIL_V))
for s in ("L", "R"):
    if WING_V[s]:
        pts = [P[i] for i in WING_V[s]]
        rootp = min(pts, key=lambda p: abs(p.x))
        tip = max(pts, key=lambda p: (p - rootp).length)
        bone("Wing." + s, rootp, tip, "Chest", roll_up=Vector((0, 0, 1)))
        log("wing %s: %d vertices" % (s, len(pts)))

if weapon:
    wp = [P[i] for i in weapon]
    far = max(wp, key=lambda p: (p - hr).length)
    w_head = bones["Hand.R"].tail.copy()
    bone("Weapon", w_head, far, "Hand.R", roll_up=FWD)
bpy.ops.object.mode_set(mode="OBJECT")
BONES = [b.name for b in arm_data.bones]
REST = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm_data.bones}

# ---------------------------------------------------------------------------------------------------------------
# 4 bind and clean the weights
# ---------------------------------------------------------------------------------------------------------------
GROUP = {}
for n in BONES:
    if n.startswith(("UpperArm", "LowerArm", "Hand")):
        GROUP[n] = "arm" + n[-1]
    elif n.startswith(("UpperLeg", "LowerLeg", "Foot")):
        GROUP[n] = "leg" + n[-1]
    elif n in ("Head", "Neck"):
        GROUP[n] = "head"
    elif n == "Weapon":
        GROUP[n] = "weapon"
    elif n.startswith("Tail"):
        GROUP[n] = "tail"
    elif n.startswith("Wing"):
        GROUP[n] = "wing" + n[-1]
    else:
        GROUP[n] = "torso"


def bind():
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def group_of(w):
    sums = {}
    for k, v in w.items():
        g = GROUP.get(k)
        if g:
            sums[g] = sums.get(g, 0) + v
    return max(sums, key=sums.get) if sums else "torso"


def mesh_tables():
    global P, NV, NEIGH, EDGES
    P = [v.co.copy() for v in me.vertices]
    NV = len(P)
    NEIGH = [[] for _ in range(NV)]
    for e in me.edges:
        a, b = e.vertices
        NEIGH[a].append(b)
        NEIGH[b].append(a)
    EDGES = [tuple(e.vertices) for e in me.edges]


neck_half = max(0.06 * H, row_width(gz(neck_z)) / 2)
# a first binding shows which limb each vertex belongs to; where an arm's mesh is fused to the leg or body
# below the armpit (fingers touching the thigh: the generator welds them), cut the mesh there, so the arm can
# move away without dragging the thigh along. Nothing visible changes: the cut edges just get their own vertices.
bind()
total_cut = 0
for _pass in range(3):  # a cut changes the next binding a little: look again until nothing is left to cut
    first = [dict() for _ in range(NV)]
    gnames = {g.index: g.name for g in body.vertex_groups}
    for v in me.vertices:
        for g in v.groups:
            if g.weight > 1e-6:
                first[v.index][gnames[g.group]] = g.weight
    groups = [group_of(w) for w in first]
    cut = []
    for e in me.edges:
        a, b = e.vertices
        ga, gb = groups[a], groups[b]
        if ga == gb:
            continue
        arm = ga if ga.startswith("arm") else gb if gb.startswith("arm") else None
        other = gb if arm == ga else ga
        # (well below the armpit only: higher up the vest and shoulder pads belong to both, and cutting them
        # opened holes when the arms rose)
        if arm and (other.startswith("leg") or other == "torso"):
            if max(P[a].z, P[b].z) < armpit_z[arm[-1]] - 0.15 * H:
                cut.append(e.index)
        # a wing welded to the arm next to it (a wing grows from the back, never from the arm)
        elif arm and other.startswith("wing"):
            cut.append(e.index)
        # (the jaw welded to the shoulder pads is NOT cut: tried 2026-11-25, it opened holes between the pads and
        # the vest collar when the arms rose; the head mask in allowed() keeps the pads off the head instead)
    if not cut:
        break
    total_cut += len(cut)
    body.parent = None
    for mod in list(body.modifiers):
        body.modifiers.remove(mod)
    body.vertex_groups.clear()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    bmesh.ops.split_edges(bm, edges=[bm.edges[i] for i in cut])
    bm.to_mesh(me)
    bm.free()
    me.update()
    mesh_tables()
    bind()
log("cut %d welded edges (arms to legs or body well below the armpits)" % total_cut)
for g in BONES:
    if g not in body.vertex_groups:
        body.vertex_groups.new(name=g)
GI = {body.vertex_groups[n].index: n for n in BONES}
GIDX = {n: body.vertex_groups[n].index for n in BONES}
if "Root" in GIDX:
    pass


def read_weights():
    W = [dict() for _ in range(NV)]
    for v in me.vertices:
        for g in v.groups:
            n = GI.get(g.group)
            if n and g.weight > 1e-6:
                W[v.index][n] = g.weight
    return W


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (a + ab * t - p).length


SKIN_BONES = [n for n in BONES if n != "Root"]


def nearest_bone(p):
    return min(SKIN_BONES, key=lambda n: seg_dist(p, *REST[n]))


HEAD_V = set(i for i in range(NV) if P[i].z > neck_z + 0.02 * H and abs(P[i].x) < max(abs(shoulders["L"].x),
                                                                                       abs(shoulders["R"].x)) * 3)
WEAPON_V = set(weapon or [])


def allowed(i):
    """The bones vertex i may follow: the limb its automatic weights mostly belong to, plus the joint it hangs
    from. Automatic weights leak (belly on the thigh, chest on the arm, shoulder pads on the head): the limb
    group only counts where that limb can be (legs below the crotch, arms below the shoulder, head above the neck)."""
    p = P[i]
    side = "L" if p.x > 0 else "R"
    if i in WEAPON_V:
        return {"Weapon"}
    if i in TAIL_SET:
        return {"Hips", "Tail1", "Tail2", "Tail3"}
    if i in WING_SET:
        return {"Chest", "Wing." + ("L" if P[i].x > 0 else "R")}
    if i in HEAD_V:
        return {"Head"}
    g = GROUPS[i]
    if g.startswith("arm") and p.z < shoulders[g[-1]].z + 0.03 * H:
        s = g[-1]
        bones_ = {"UpperArm." + s, "LowerArm." + s, "Hand." + s}
        if p.z > armpit_z[s] - 0.05 * H:
            bones_.add("Chest")
        return bones_
    if g.startswith("leg") and p.z < crotch_z + 0.03 * H:
        s = g[-1]
        bones_ = {"UpperLeg." + s, "LowerLeg." + s, "Foot." + s}
        if p.z > crotch_z - 0.08 * H:
            bones_.add("Hips")
        return bones_
    if g == "head" and p.z > neck_z - 0.04 * H and abs(p.x) < NECK_HALF * 1.4:
        return {"Head", "Neck", "Chest"}
    bones_ = {"Hips", "Spine", "Chest"}
    if p.z > neck_z - 0.08 * H and abs(p.x) < NECK_HALF * 1.4:
        bones_ |= {"Neck", "Head"}
    if p.z > armpit_z[side] - 0.04 * H and abs(p.x) > arm_inner_pit[side] - 0.08 * H:
        bones_.add("UpperArm." + side)
    if p.z < crotch_z + 0.1 * H:
        bones_.add("UpperLeg." + side)
    return bones_


ALLOWED = None


def mask(W):
    out = []
    for i, w in enumerate(W):
        ok = ALLOWED[i]
        m = {k: v for k, v in w.items() if k in ok}
        if sum(m.values()) < 1e-4:
            m = {min(ok, key=lambda n: seg_dist(P[i], *REST[n])): 1.0}
        out.append(limit(m))
    return out


def clean(W, smooth_rounds=1):
    zero = 0
    for i in range(NV):
        if sum(W[i].values()) < 1e-4:
            W[i] = {nearest_bone(P[i]): 1.0}
            zero += 1
        W[i].pop("Root", None)
        if not W[i]:
            W[i] = {nearest_bone(P[i]): 1.0}
    W = mask(W)
    for _ in range(smooth_rounds):
        W = mask(smooth(W, range(NV), 0.5))
    for i in range(NV):
        if i in WEAPON_V:
            W[i] = {"Weapon": 1.0}
        elif i in HEAD_V:
            W[i] = {"Head": 1.0}
        W[i] = limit(W[i])
    return W, zero


def limit(w, n=4):
    top = sorted(w.items(), key=lambda kv: -kv[1])[:n]
    s = sum(v for _, v in top)
    return {k: v / s for k, v in top} if s > 0 else w


def smooth(W, verts, factor):
    new = list(W)
    for i in verts:
        if i in HEAD_V or i in WEAPON_V:
            continue
        acc = {}
        nb = NEIGH[i]
        if not nb:
            continue
        for j in nb:
            for k, v in W[j].items():
                acc[k] = acc.get(k, 0) + v / len(nb)
        mixed = {}
        for k in set(acc) | set(W[i]):
            mixed[k] = W[i].get(k, 0) * (1 - factor) + acc.get(k, 0) * factor
        new[i] = limit({k: v for k, v in mixed.items() if v > 1e-4})
    return new


def write_weights(W):
    for g in body.vertex_groups:
        g.remove(range(NV))
    for i, w in enumerate(W):
        for k, v in w.items():
            body.vertex_groups[k].add([i], v, "REPLACE")


W = read_weights()
GROUPS = [group_of(w) for w in W]
# the rigid head: above the neck AND mostly the head's by the automatic weights (shoulder pads that reach up
# beside the jaw stay with the chest, or they were dragged up when the head turned)
HEAD_V = set(i for i in HEAD_V if GROUPS[i] == "head")
NECK_HALF = neck_half
ALLOWED = [allowed(i) for i in range(NV)]
auto_zero = sum(1 for w in W if sum(w.values()) < 1e-4)
W, zero = clean(W)
write_weights(W)
log("automatic weights: %d vertices had no weight (given their nearest bone)" % auto_zero)

# ---------------------------------------------------------------------------------------------------------------
# 5 test poses and stretch
# ---------------------------------------------------------------------------------------------------------------
# each turn: (bone, world axis, degrees) applied parent first, about the bone's head
# the angles a monster really uses (src/shared/MonsterMoves.luau: arms up to 60, head up to 25, knees 45, the
# attack's wind-up); RIG_POSES=stress tests the extremes instead (arms 90, head 40, swing 120)
STRESS = os.environ.get("RIG_POSES") == "stress"
A, HD, SW = (90, 40, 120) if STRESS else (60, 25, 100)
POSES = {
    "rest": [],
    "arms_up": [("UpperArm.L", (0, 1, 0), -A), ("UpperArm.R", (0, 1, 0), A)],
    "swing": [("Chest", (0, 0, 1), 25 if STRESS else 15), ("UpperArm.R", (1, 0, 0), -SW),
              ("LowerArm.R", (1, 0, 0), -40), ("UpperArm.L", (1, 0, 0), 35 if STRESS else 25)],
    "knees_45": [("Hips", (0, 0, 1), 0), ("UpperLeg.L", (1, 0, 0), -25), ("LowerLeg.L", (1, 0, 0), 45),
                 ("UpperLeg.R", (1, 0, 0), -25), ("LowerLeg.R", (1, 0, 0), 45)],
    "head_turn": [("Head", (0, 0, 1), HD)],
}
log("test poses: %s (arms %d, head %d, swing %d)" % ("stress" if STRESS else "real use", A, HD, SW))
if weapon:
    POSES["swing"].append(("Hand.R", (1, 0, 0), -30))


def set_pose(turns):
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for name, axis, deg in turns:
        pb = rig.pose.bones.get(name)
        if not pb:
            continue
        head = pb.head.copy()
        rot = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, Vector(axis)) @ Matrix.Translation(-head)
        pb.matrix = rot @ pb.matrix
        bpy.context.view_layer.update()


REST_LEN = [(P[a] - P[b]).length for a, b in EDGES]


def stretch():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    m = ev.to_mesh()
    Q = [v.co.copy() for v in m.vertices]
    ev.to_mesh_clear()
    worst, bad, wk, seen = 1.0, [], None, []
    for k, (a, b) in enumerate(EDGES):
        r0 = REST_LEN[k]
        if r0 < 1e-6:
            continue
        r = (Q[a] - Q[b]).length / r0
        if r > worst:
            worst, wk = r, k
        if r > STRETCH_LIMIT:
            bad.append(k)
            if (Q[a] - Q[b]).length - r0 > VISIBLE * H:
                seen.append(k)
    if DEBUG and wk is not None:
        a, b = EDGES[wk]
        log("   b at %s" % (tuple(round(v, 2) for v in P[b]),))
        log("   worst edge %d-%d rest %.3f at %s: %s | %s" % (a, b, REST_LEN[wk], tuple(round(v, 2) for v in P[a]),
            {k: round(v, 2) for k, v in W[a].items()}, {k: round(v, 2) for k, v in W[b].items()}))
    return worst, bad, seen


def check_all(label):
    res = {}
    for name, turns in POSES.items():
        if name == "rest":
            continue
        set_pose(turns)
        res[name] = stretch()
    set_pose([])
    log(label + ": " + ", ".join("%s max %.2fx (%d edges over %.1fx, %d of them visible)" % (
        n, r[0], len(r[1]), STRETCH_LIMIT, len(r[2])) for n, r in res.items()))
    return res


def score(res):
    return (sum(len(r[2]) for r in res.values()), sum(len(r[1]) for r in res.values()))


first = check_all("stretch after binding")
best = (score(first), [dict(w) for w in W])
res = first
for rnd in range(1, 13):
    bad_verts = set()
    for _, (_, bad, _) in res.items():
        for k in bad:
            bad_verts.update(EDGES[k])
    if not bad_verts:
        break
    # smooth the weights around every stretched edge (two rings out), a few passes; keep whichever round
    # stretched least
    ring = set(bad_verts)
    for _ in range(2):
        ring |= {j for i in list(ring) for j in NEIGH[i]}
    for _ in range(3):
        W = mask(smooth(W, ring, 0.6))
    write_weights(W)
    res = check_all("round %d" % rnd)
    if score(res) < best[0]:
        best = (score(res), [dict(w) for w in W])
W = best[1]
write_weights(W)
final = check_all("final (best round)")

# ---------------------------------------------------------------------------------------------------------------
# numbers
# ---------------------------------------------------------------------------------------------------------------
W = read_weights()
zero_now = sum(1 for w in W if sum(w.values()) < 1e-4)
over4 = sum(1 for w in W if len(w) > 4)
head_wrong = sum(1 for i in HEAD_V if max(W[i], key=W[i].get) != "Head")
weapon_wrong = sum(1 for i in WEAPON_V if max(W[i], key=W[i].get) != "Weapon")
log("CHECK zero-weight vertices %d, over 4 bones %d, head vertices on another bone %d of %d, weapon vertices on another bone %s" % (
    zero_now, over4, head_wrong, len(HEAD_V), ("%d of %d" % (weapon_wrong, len(WEAPON_V))) if weapon else "n/a (no weapon)"))
for n, (w, bad, seen) in final.items():
    if seen and DEBUG:
        zs = sorted(round((P[EDGES[k][0]].z) / H, 2) for k in seen)
        xs = sorted(round(abs(P[EDGES[k][0]].x) / H, 2) for k in seen)
        gs = sorted(set(GROUPS[EDGES[k][0]] + "/" + GROUPS[EDGES[k][1]] for k in seen))
        log("   %s visible stretch at height (x H) %s..%s median %s, |x| %s..%s, groups %s" % (
            n, zs[0], zs[-1], zs[len(zs) // 2], xs[0], xs[-1], gs))
    log("CHECK pose %-9s max edge stretch %.2fx, edges over %.1fx: %d, of them grown more than %.2f studs: %d" % (
        n, w, STRETCH_LIMIT, len(bad), VISIBLE * H, len(seen)))
log("BONES (rest, studs, front -Y, left +X):")
for n in BONES:
    h, t = REST[n]
    parent = arm_data.bones[n].parent
    log("  %-11s parent %-11s head (%5.2f %5.2f %5.2f) tail (%5.2f %5.2f %5.2f)" % (
        n, parent.name if parent else "-", h.x, h.y, h.z, t.x, t.y, t.z))

# ---------------------------------------------------------------------------------------------------------------
# 6 sheets and export
# ---------------------------------------------------------------------------------------------------------------
if SHEETS:
    os.makedirs(SHEETS, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.render.resolution_x = sc.render.resolution_y = 320
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.08, 0.08, 0.09)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = H * 1.35
    rig.hide_render = True
    frames = []
    for pname, turns in POSES.items():
        set_pose(turns)
        for look in ("TEXTURE", "SINGLE"):
            sc.display.shading.color_type = look
            sc.display.shading.single_color = (0.6, 0.6, 0.6)
            for k in range(8):
                a = math.radians(-90 + k * 45)  # 0 = front (camera on -Y)
                cam.location = (3 * H * math.cos(a), 3 * H * math.sin(a), H * 0.55)
                d = Vector((0, 0, H * 0.5)) - cam.location
                cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
                path = os.path.join(SHEETS, "_f_%s_%s_%d.png" % (pname, look, k))
                sc.render.filepath = path
                bpy.ops.render.render(write_still=True)
                frames.append((pname, look, k, path))
    set_pose([])
    # one sheet per pose: painted on top, grey below, 8 sides from the front round to the left (numpy: Blender
    # has no PIL)
    import numpy as np
    R = 320
    for pname in POSES:
        rows = []
        for look in ("TEXTURE", "SINGLE"):
            tiles = []
            for (n, lk, k, path) in frames:
                if n == pname and lk == look:
                    img = bpy.data.images.load(path)
                    px = np.empty(R * R * 4, dtype=np.float32)
                    img.pixels.foreach_get(px)
                    tiles.append(px.reshape(R, R, 4))
                    bpy.data.images.remove(img)
            rows.append(np.concatenate(tiles, axis=1))
        sheet = np.concatenate(rows[::-1], axis=0)  # (Blender's rows run bottom up: painted ends on top)
        out = bpy.data.images.new("sheet_" + pname, sheet.shape[1], sheet.shape[0])
        out.pixels.foreach_set(sheet.ravel())
        out.filepath_raw = os.path.join(SHEETS, "%s_%s.png" % (NAME, pname))
        out.file_format = "PNG"
        out.save()
    for (_, _, _, path) in frames:
        os.remove(path)
    log("sheets in", SHEETS)

set_pose([])
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
rig.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, apply_unit_scale=True, global_scale=1.0,
                         axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", object_types={"ARMATURE", "MESH"},
                         add_leaf_bones=False, use_armature_deform_only=True, bake_anim=False,
                         path_mode="COPY", embed_textures=True)
log("EXPORTED", OUT, os.path.getsize(OUT), "bytes")
