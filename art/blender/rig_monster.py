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
SHEETS = os.path.abspath(args[4]) if len(args) > 4 and args[4] != "-" else None
# the body plan: "humanoid" (legs), "robe" (no legs under a robe or dress: hem bones instead, ghosts and
# sorceresses), "slime" (a blob: a column of body bones and four bulge bones for squash)
KIND = args[5] if len(args) > 5 else "humanoid"
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


# ---------------------------------------------------------------------------------------------------------------
# the rigid body plan: golems and armoured knights are hard pieces, not skin. The model is cut into pieces along
# its own seams (each mesh island stays whole; where an island spans two bones it is cut where the bones' regions
# meet), every piece is closed with a cap painted from its rim and follows exactly one bone. Needs the hand-marked
# key points (art/blender/rig_landmarks/<name>.json).
# ---------------------------------------------------------------------------------------------------------------
if KIND == "rigid":
    import json
    import numpy as np
    OVr = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "rig_landmarks", NAME + ".json")))
    Vr = lambda k: Vector(OVr[k])  # noqa: E731
    arm_data = bpy.data.armatures.new(NAME + "_rig")
    rig = bpy.data.objects.new(NAME + "_rig", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    FWD = Vector((0, -1, 0))

    def rbone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.align_roll(Vector((0, 0, 1)) if name.startswith("Foot") else FWD)
        if parent:
            b.parent = eb[parent]
        return b

    spine_p = Vr("hips").lerp(Vr("chest"), 0.4)
    rbone("Root", (0, 0, 0), (0, 0, 0.12 * H))
    rbone("Hips", Vr("hips"), spine_p, "Root")
    rbone("Spine", spine_p, Vr("chest"), "Hips")
    rbone("Chest", Vr("chest"), Vr("neck") - Vector((0, 0, 0.05 * H)), "Spine")
    rbone("Neck", Vr("neck") - Vector((0, 0, 0.05 * H)), Vr("neck"), "Chest")
    rbone("Head", Vr("neck"), Vr("head_top"), "Neck")
    for s in ("L", "R"):
        rbone("UpperArm." + s, Vr("shoulder_" + s), Vr("elbow_" + s), "Chest")
        rbone("LowerArm." + s, Vr("elbow_" + s), Vr("wrist_" + s), "UpperArm." + s)
        rbone("Hand." + s, Vr("wrist_" + s), Vr("hand_tip_" + s), "LowerArm." + s)
        rbone("UpperLeg." + s, Vr("hip_" + s), Vr("knee_" + s), "Hips")
        rbone("LowerLeg." + s, Vr("knee_" + s), Vr("ankle_" + s), "UpperLeg." + s)
        rbone("Foot." + s, Vr("ankle_" + s), Vr("toe_" + s), "LowerLeg." + s)
    bpy.ops.object.mode_set(mode="OBJECT")
    RB = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm_data.bones}
    # which bones get pieces (Root, Neck and Spine are too small to own any: their share goes to the next)
    OWN = [n for n in RB if n not in ("Root", "Neck")]

    def sdist(p, a, b):
        ab = b - a
        tt = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
        return (a + ab * tt - p).length

    def nearest(p):
        return min(OWN, key=lambda n: sdist(p, *RB[n]))

    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bm.faces.index_update()
    uvl_ = bm.loops.layers.uv.active
    # 1 a label per face (nearest bone to its middle), forced per hand-marked rule (a shield, a sword, a cape)
    lab = {}
    for f in bm.faces:
        c = f.calc_center_median()
        lab[f.index] = nearest(c)
    forced = set()
    # (a box takes whole mesh islands: those with most of their area inside it. Taking single faces left slivers of
    # the shield behind on the leg, and took bits of leg armour along with the shield)
    isl_of, isls = {}, []
    for f in bm.faces:
        if f.index in isl_of:
            continue
        comp, stack = [], [f]
        isl_of[f.index] = len(isls)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in isl_of:
                        isl_of[h.index] = len(isls)
                        stack.append(h)
        isls.append(comp)
    for rule in OVr.get("piece_rules", []):  # {"bone": "Hand.L", "box": [[x0,y0,z0],[x1,y1,z1]]}
        lo_, hi_ = Vector(rule["box"][0]), Vector(rule["box"][1])
        for comp in isls:
            inside = sum(g.calc_area() for g in comp
                         if all(lo_[k] <= g.calc_center_median()[k] <= hi_[k] for k in range(3)))
            if inside >= 0.6 * sum(g.calc_area() for g in comp):
                for g in comp:
                    lab[g.index] = rule["bone"]
                    forced.add(g.index)
    # 2 smooth the labels (3 rounds of the majority of each face's neighbours), so cuts run straight
    for _ in range(3):
        new = {}
        for f in bm.faces:
            votes = {}
            for e in f.edges:
                for g in e.link_faces:
                    votes[lab[g.index]] = votes.get(lab[g.index], 0) + 1
            best = max(votes, key=votes.get)
            new[f.index] = lab[f.index] if f.index in forced else (
                best if votes[best] > votes.get(lab[f.index], 0) else lab[f.index])
        lab = new
    # 3 a mesh island (one rock, one plate) stays whole when most of it is one bone's: pieces are not sliced
    seen = set()
    for f in bm.faces:
        if f.index in seen:
            continue
        comp, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        votes = {}
        for g in comp:
            votes[lab[g.index]] = votes.get(lab[g.index], 0) + g.calc_area()
        best = max(votes, key=votes.get)
        if votes[best] >= sum(votes.values()) * OVr.get("island_whole", 0.8):
            for g in comp:
                lab[g.index] = best
    # 4 cut along the label borders and close every opening with a cap wearing its rim's paint
    bl = bm.faces.layers.int.new("bone")
    names = sorted(set(lab.values()))
    for f in bm.faces:
        f[bl] = names.index(lab[f.index])
    fl = bm.faces.layers.int.new("forced")
    for f in bm.faces:
        f[fl] = 1 if f.index in forced else 0
    # (2026-11-26, round 2: cutting every seam left gaps of 0.6-1.6 studs behind the shoulders; the body's seams now
    # stay joined and their vertices blend between the two bones, like a crack that stretches; only hand-marked
    # pieces, a sword or a shield, are cut loose)
    border = [e for e in bm.edges if len(e.link_faces) == 2 and e.link_faces[0][bl] != e.link_faces[1][bl]
              and (not OVr.get("blend_seams", True) or e.link_faces[0][fl] != e.link_faces[1][fl])]
    bmesh.ops.split_edges(bm, edges=border)
    caps = 0
    for idx in range(len(names)):
        open_edges = [e for e in bm.edges if e.is_boundary and e.link_faces and e.link_faces[0][bl] == idx]
        if not open_edges:
            continue
        filled = bmesh.ops.holes_fill(bm, edges=open_edges, sides=0)["faces"]
        bm.faces.index_update()
        fill_ids = {f.index for f in filled}
        for f in filled:
            f[bl] = idx
            for loop in f.loops:
                src = next((l for l in loop.vert.link_loops if l.face.index not in fill_ids), None)
                if src is not None:
                    loop[uvl_].uv = src[uvl_].uv
        caps += len(filled)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    # every piece is now closed: point all its faces outward (some caps came out facing in: black specks)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.verts.index_update()
    vbone = {}
    vmix = {}  # vertex -> {bone: share of the faces around it}
    for f in bm.faces:
        for v in f.verts:
            vbone[v.index] = names[f[bl]]
            m = vmix.setdefault(v.index, {})
            m[names[f[bl]]] = m.get(names[f[bl]], 0) + 1
    bm.faces.layers.int.remove(bl)
    bm.faces.layers.int.remove(fl)
    bm.to_mesh(me)
    bm.free()
    me.update()
    counts = {}
    for n in vbone.values():
        counts[n] = counts.get(n, 0) + 1
    log("rigid pieces: %d bones own pieces, %d border edges cut, %d cap faces; vertices per bone %s" % (
        len(names), len(border), caps, ", ".join("%s %d" % (n, counts[n]) for n in sorted(counts))))
    # 5 weights: every vertex wholly to its piece's bone
    for n in RB:
        if n != "Root":
            body.vertex_groups.new(name=n)
    for i, m in vmix.items():
        tot = sum(m.values())
        for n, c in sorted(m.items(), key=lambda kv: -kv[1])[:4]:
            body.vertex_groups[n].add([i], c / tot, "REPLACE")
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    body.parent = rig
    zero = sum(1 for v in me.vertices if sum(g.weight for g in v.groups) < 1e-4)
    log("CHECK zero-weight vertices %d, vertices blended between bones (on joined seams) %d" % (
        zero, sum(1 for v in me.vertices if len([g for g in v.groups if g.weight > 1e-4]) > 1)))
    # 6 the gaps at the cuts: the same seam point on the two pieces, apart in a pose
    rest = [v.co.copy() for v in me.vertices]
    seam = {}
    for i, c in enumerate(rest):
        seam.setdefault((round(c.x, 4), round(c.y, 4), round(c.z, 4)), []).append(i)
    pairs = [g for g in seam.values() if len(g) > 1]
    EDG = [tuple(e.vertices) for e in me.edges]
    RL = [(rest[a] - rest[b]).length for a, b in EDG]
    TA = OVr.get("test_angles", {})
    POSES_R = {
        "rest": [],
        "arms_up": [("UpperArm.L", (0, 1, 0), -TA.get("arms", 60)), ("UpperArm.R", (0, 1, 0), TA.get("arms", 60))],
        "swing": [("Chest", (0, 0, 1), 15), ("UpperArm.R", (1, 0, 0), -TA.get("swing", 100)), ("LowerArm.R", (1, 0, 0), -40)],
        "knees_45": [("UpperLeg.L", (1, 0, 0), -25), ("LowerLeg.L", (1, 0, 0), 45), ("UpperLeg.R", (1, 0, 0), -25),
                     ("LowerLeg.R", (1, 0, 0), 45)],
        "head_turn": [("Head", (0, 0, 1), TA.get("head", 25))],
    }

    def rpose(turns):
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        for name, axis, deg in turns:
            pb = rig.pose.bones[name]
            head = pb.head.copy()
            pb.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, Vector(axis)) @ Matrix.Translation(-head) @ pb.matrix
            bpy.context.view_layer.update()
    for pname, turns in POSES_R.items():
        if pname == "rest":
            continue
        rpose(turns)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = body.evaluated_get(dg)
        m = ev.to_mesh()
        Q = [v.co.copy() for v in m.vertices]
        ev.to_mesh_clear()
        ratios = [((Q[a] - Q[b]).length / r0) for (a, b), r0 in zip(EDG, RL) if r0 > 1e-6]
        over = sum(1 for r in ratios if r > STRETCH_LIMIT)
        log("CHECK pose %-9s joined seams: max edge stretch %.2fx, edges over %.1fx: %d" % (
            pname, max(ratios), STRETCH_LIMIT, over))
        worst, wpair = 0.0, None
        open_ = 0
        for g in pairs:
            d = max((Q[a] - Q[b]).length for a in g for b in g)
            if d > worst:
                worst, wpair = d, g
            if d > 0.3:  # (studs: the target is no gap over 0.3 at the angles the monster uses)
                open_ += 1
        where = ""
        if wpair:
            where = " (worst between %s, at %s)" % ("/".join(sorted({vbone[i] for i in wpair})),
                                                   tuple(round(c, 2) for c in rest[wpair[0]]))
        log("CHECK pose %-9s widest gap at a cut %.3f studs; cut points opening more than 0.30 studs: %d of %d%s" % (
            pname, worst, open_, len(pairs), where))
    rpose([])
    log("BONES (rest, studs, front -Y, left +X):")
    for b in arm_data.bones:
        h, tl = b.head_local, b.tail_local
        log("  %-11s parent %-11s head (%5.2f %5.2f %5.2f) tail (%5.2f %5.2f %5.2f)" % (
            b.name, b.parent.name if b.parent else "-", h.x, h.y, h.z, tl.x, tl.y, tl.z))
    if SHEETS:
        os.makedirs(SHEETS, exist_ok=True)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.light = "STUDIO"
        sc.render.resolution_x = sc.render.resolution_y = 320
        sc.world = bpy.data.worlds.new("w")
        sc.world.color = (0.08, 0.08, 0.09)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
        wmax = max(max(abs(c.x), abs(c.y)) for c in rest)
        cam.data.ortho_scale = max(H, wmax * 2) * 1.3
        rig.hide_render = True
        R = 320
        for pname, turns in POSES_R.items():
            rpose(turns)
            rows = []
            for look in ("TEXTURE", "SINGLE"):
                sc.display.shading.color_type = look
                sc.display.shading.single_color = (0.6, 0.6, 0.6)
                tiles = []
                for kk in range(8):
                    a = math.radians(-90 + kk * 45)
                    cam.location = (3 * H * math.cos(a), 3 * H * math.sin(a), H * 0.55)
                    d = Vector((0, 0, H * 0.5)) - cam.location
                    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
                    path = os.path.join(SHEETS, "_f.png")
                    sc.render.filepath = path
                    bpy.ops.render.render(write_still=True)
                    img = bpy.data.images.load(path)
                    px = np.empty(R * R * 4, dtype=np.float32)
                    img.pixels.foreach_get(px)
                    tiles.append(px.reshape(R, R, 4))
                    bpy.data.images.remove(img)
                rows.append(np.concatenate(tiles, axis=1))
            sheet = np.concatenate(rows[::-1], axis=0)
            out = bpy.data.images.new("sheet_" + pname, sheet.shape[1], sheet.shape[0])
            out.pixels.foreach_set(sheet.ravel())
            out.filepath_raw = os.path.join(SHEETS, "%s_%s.png" % (NAME, pname))
            out.file_format = "PNG"
            out.save()
        os.remove(os.path.join(SHEETS, "_f.png"))
        log("sheets in", SHEETS)
    rpose([])
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, apply_unit_scale=True, global_scale=1.0,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", object_types={"ARMATURE", "MESH"},
                             add_leaf_bones=False, use_armature_deform_only=True, bake_anim=False,
                             path_mode="COPY", embed_textures=True)
    log("EXPORTED", OUT, os.path.getsize(OUT), "bytes")
    sys.exit(0)

# ---------------------------------------------------------------------------------------------------------------
# the slime body plan: a blob has no limbs. A column of body bones (Root, Body1-3, Top) and four bulge bones
# (Bulge F/B/L/R) at its widest: squash = the column sinks while the bulges push out (no scale, bones only)
# ---------------------------------------------------------------------------------------------------------------
if KIND == "slime":
    import numpy as np
    arm_data = bpy.data.armatures.new(NAME + "_rig")
    rig = bpy.data.objects.new(NAME + "_rig", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def sbone(name, head, tail, parent=None, connect=False):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.align_roll(Vector((0, -1, 0)) if abs((b.tail - b.head).normalized().z) > 0.9 else Vector((0, 0, 1)))
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        return b

    def centre(z):
        ps = [p for p in P if abs(p.z - z) < 0.05 * H]
        return Vector((sum(p.x for p in ps) / len(ps), sum(p.y for p in ps) / len(ps), z)) if ps else Vector((0, 0, z))

    sbone("Root", (0, 0, 0), (0, 0, 0.1 * H))
    levels = [0.05, 0.35, 0.65, 0.9]
    names = ["Body1", "Body2", "Body3", "Top"]
    parent = "Root"
    for n in range(4):
        head = centre(levels[n] * H)
        tail = centre(levels[n + 1] * H) if n < 3 else Vector((head.x, head.y, H))
        sbone(names[n], head, tail, parent, n > 0)
        parent = names[n]
    # the widest ring, and the four bulges from the middle of it out to its edge
    best = None
    for z in np.linspace(0.1, 0.6, 11):
        ps = [p for p in P if abs(p.z - z * H) < 0.04 * H]
        if ps:
            w = max(abs(p.x) for p in ps)
            if best is None or w > best[0]:
                best = (w, z * H)
    wz = best[1]
    ring = [p for p in P if abs(p.z - wz) < 0.05 * H]
    c = centre(wz)
    for k, pick in (("F", lambda p: -p.y), ("B", lambda p: p.y), ("L", lambda p: p.x), ("R", lambda p: -p.x)):
        tip = max(ring, key=pick)
        sbone("Bulge." + k, c, Vector((tip.x, tip.y, wz)), "Body1")
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    if "Root" in body.vertex_groups:
        body.vertex_groups.remove(body.vertex_groups["Root"])
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=2)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    zero = sum(1 for v in me.vertices if sum(g.weight for g in v.groups) < 1e-4)
    over = sum(1 for v in me.vertices if len([g for g in v.groups if g.weight > 1e-4]) > 4)
    log("CHECK zero-weight vertices %d, over 4 bones %d" % (zero, over))
    EDGES_S = [tuple(e.vertices) for e in me.edges]
    REST_S = [(P[a] - P[b]).length for a, b in EDGES_S]
    # the poses MonsterAnim uses: squash on landing, stretch at the top of a hop, a wobble
    SQ = 0.22  # how far the column sinks in the squash (share of height)
    POSES_S = {
        "rest": {},
        "squash": {"Body2": (0, 0, -SQ * 0.35), "Body3": (0, 0, -SQ * 0.3), "Top": (0, 0, -SQ * 0.35),
                   "Bulge.F": "out", "Bulge.B": "out", "Bulge.L": "out", "Bulge.R": "out"},
        "stretch": {"Body2": (0, 0, SQ * 0.25), "Body3": (0, 0, SQ * 0.2), "Top": (0, 0, SQ * 0.25),
                    "Bulge.F": "in", "Bulge.B": "in", "Bulge.L": "in", "Bulge.R": "in"},
        "wobble": {"Body3": ("rot", (0, 1, 0), 12), "Top": ("rot", (0, 1, 0), 12)},
    }

    def spose(spec):
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        for name, v in spec.items():
            pb = rig.pose.bones[name]
            if v in ("out", "in"):
                d = (pb.tail - pb.head).normalized() * (0.12 if v == "out" else -0.06) * H
                pb.matrix = Matrix.Translation(d) @ pb.matrix
            elif v[0] == "rot":
                head = pb.head.copy()
                pb.matrix = (Matrix.Translation(head) @ Matrix.Rotation(math.radians(v[2]), 4, Vector(v[1]))
                             @ Matrix.Translation(-head) @ pb.matrix)
            else:
                pb.matrix = Matrix.Translation(Vector(v) * H) @ pb.matrix
            bpy.context.view_layer.update()

    def sstretch():
        dg = bpy.context.evaluated_depsgraph_get()
        ev = body.evaluated_get(dg)
        m = ev.to_mesh()
        Q = [v.co.copy() for v in m.vertices]
        ev.to_mesh_clear()
        ratios = [((Q[a] - Q[b]).length / r0) for (a, b), r0 in zip(EDGES_S, REST_S) if r0 > 1e-6]
        return (max(ratios), min(ratios), sum(1 for r in ratios if r > STRETCH_LIMIT),
                sum(1 for r in ratios if r < 1 / STRETCH_LIMIT), min(q.z for q in Q))
    for name, spec in POSES_S.items():
        if name == "rest":
            continue
        spose(spec)
        mx, mn, over_n, under_n, lowest = sstretch()
        log("CHECK pose %-8s max edge stretch %.2fx (over %.1fx: %d), most squeezed %.2fx (under 1/%.1f: %d), lowest point %.3f" % (
            name, mx, STRETCH_LIMIT, over_n, mn, STRETCH_LIMIT, under_n, lowest))
    spose({})
    log("BONES (rest, studs, front -Y, left +X):")
    for b in arm_data.bones:
        h, tl = b.head_local, b.tail_local
        log("  %-8s parent %-6s head (%5.2f %5.2f %5.2f) tail (%5.2f %5.2f %5.2f)" % (
            b.name, b.parent.name if b.parent else "-", h.x, h.y, h.z, tl.x, tl.y, tl.z))
    if SHEETS:
        os.makedirs(SHEETS, exist_ok=True)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.light = "STUDIO"
        sc.render.resolution_x = sc.render.resolution_y = 320
        sc.world = bpy.data.worlds.new("w")
        sc.world.color = (0.08, 0.08, 0.09)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
        wmax = max(max(abs(p.x), abs(p.y)) for p in P)
        cam.data.ortho_scale = max(H, wmax * 2) * 1.35
        rig.hide_render = True
        R = 320
        for name, spec in POSES_S.items():
            spose(spec)
            rows = []
            for look in ("TEXTURE", "SINGLE"):
                sc.display.shading.color_type = look
                sc.display.shading.single_color = (0.6, 0.6, 0.6)
                tiles = []
                for kk in range(8):
                    a = math.radians(-90 + kk * 45)
                    cam.location = (3 * H * math.cos(a), 3 * H * math.sin(a), H * 0.55)
                    d = Vector((0, 0, H * 0.5)) - cam.location
                    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
                    path = os.path.join(SHEETS, "_f.png")
                    sc.render.filepath = path
                    bpy.ops.render.render(write_still=True)
                    img = bpy.data.images.load(path)
                    px = np.empty(R * R * 4, dtype=np.float32)
                    img.pixels.foreach_get(px)
                    tiles.append(px.reshape(R, R, 4))
                    bpy.data.images.remove(img)
                rows.append(np.concatenate(tiles, axis=1))
            sheet = np.concatenate(rows[::-1], axis=0)
            out = bpy.data.images.new("sheet_" + name, sheet.shape[1], sheet.shape[0])
            out.pixels.foreach_set(sheet.ravel())
            out.filepath_raw = os.path.join(SHEETS, "%s_%s.png" % (NAME, name))
            out.file_format = "PNG"
            out.save()
        os.remove(os.path.join(SHEETS, "_f.png"))
        log("sheets in", SHEETS)
    spose({})
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, apply_unit_scale=True, global_scale=1.0,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", object_types={"ARMATURE", "MESH"},
                             add_leaf_bones=False, use_armature_deform_only=True, bake_anim=False,
                             path_mode="COPY", embed_textures=True)
    log("EXPORTED", OUT, os.path.getsize(OUT), "bytes")
    sys.exit(0)

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

# hand-marked key points (art/blender/rig_landmarks/<name>.json, studs, as this script places the model: front -Y,
# left +X, standing on the ground) for models whose cape, club, crown or sleeves fool the automatic landmarks.
# They replace the automatic ones; "chains" adds cloth chains (cape, sleeves) that trail and sway.
OV = None
_ov_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rig_landmarks", NAME + ".json")
if os.path.exists(_ov_path):
    import json
    OV = json.load(open(_ov_path))
    V = lambda k: Vector(OV[k])  # noqa: E731
    crotch_z, hip_z, chest_z, neck_z = OV["crotch"][2], OV["hips"][2], OV["chest"][2], OV["neck"][2]
    spine_z = hip_z + (chest_z - hip_z) * 0.4
    shoulders = {"L": V("shoulder_L"), "R": V("shoulder_R")}
    shoulder_z = (shoulders["L"].z + shoulders["R"].z) / 2
    armpit_z = {s: shoulders[s].z - 0.06 * H for s in ("L", "R")}
    arm_inner_pit = {s: abs(shoulders[s].x) - 0.05 * H for s in ("L", "R")}
    for s in ("L", "R"):
        wr, tip = V("wrist_" + s), V("hand_tip_" + s)
        hands[s] = {"c": (wr + tip) / 2, "top": max(wr.z, tip.z), "bottom": min(wr.z, tip.z)}
        if "ankle_" + s in OV:
            feet[s] = V("ankle_" + s)
    log("hand-marked key points from", _ov_path)
VCOL = None
if OV and OV.get("cloth_colors") and image:
    # the colour of each vertex, from the texture (a red cape, its fur hem): cloth is told from arms by colour too
    import numpy as np
    wimg, himg = image.size
    px = np.empty(wimg * himg * 4, dtype=np.float32)
    image.pixels.foreach_get(px)
    px = px.reshape(himg, wimg, 4)
    uvl = me.uv_layers.active.data
    acc = [[0.0, 0.0, 0.0, 0] for _ in range(NV)]
    for loop in me.loops:
        u, v = uvl[loop.index].uv
        c = px[min(himg - 1, max(0, int(v * himg))), min(wimg - 1, max(0, int(u * wimg)))]
        a = acc[loop.vertex_index]
        a[0] += c[0]; a[1] += c[1]; a[2] += c[2]; a[3] += 1
    VCOL = [(a[0] / a[3] * 255, a[1] / a[3] * 255, a[2] / a[3] * 255) if a[3] else (0, 0, 0) for a in acc]


def cloth_color(i):
    """True when vertex i has one of the hand-marked cloth colours (a red cape, its fur) and is below the neck."""
    if not VCOL or i >= len(VCOL) or P[i].z >= OV["neck"][2]:
        return False
    tol = OV.get("cloth_color_tolerance", 60)
    return any(sum((VCOL[i][k] - c[k]) ** 2 for k in range(3)) ** 0.5 < tol for c in OV.get("cloth_colors", []))


# the cloth mask by colour, cleaned: a vertex is cloth when most of its neighbourhood is (paint noise made single
# vertices flip, and a cut along a noisy edge shredded the cape)
CLOTH_MASK = None
if VCOL:
    m = [cloth_color(i) for i in range(NV)]
    for _ in range(3):
        m = [(sum(m[j] for j in NEIGH[i]) + m[i]) * 2 > len(NEIGH[i]) + 1 for i in range(NV)]
    CLOTH_MASK = m
    log("cloth by colour: %d vertices" % sum(m))

# a cape made its own piece ("separate_cloth" in the key-points file): the cloth faces are split off the body, the
# hole they leave in the body is closed with a patch painted from the body around it, and the cape gets a back
# face (a thin shell), so arms can rise in front of it instead of dragging it
CAPE_V = None
if CLOTH_MASK and OV.get("separate_cloth"):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    uvl_ = bm.loops.layers.uv.active
    capel = bm.faces.layers.int.new("cape")  # (marks the cape's faces through the operations below)
    for f in bm.faces:
        f[capel] = 1 if all(CLOTH_MASK[v.index] for v in f.verts) else 0
    cape_faces = [f for f in bm.faces if f[capel]]
    bmesh.ops.split(bm, geom=cape_faces)
    # the body's open edges where the cape was: fill them
    body_open = [e for e in bm.edges if e.is_boundary and e.link_faces and not e.link_faces[0][capel]]
    filled = bmesh.ops.holes_fill(bm, edges=body_open, sides=0)["faces"]
    fill_set = set(filled)
    for f in filled:
        f[capel] = 0
        for loop in f.loops:
            src = next((l for l in loop.vert.link_loops if l.face not in fill_set and not l.face[capel]), None)
            if src is not None:
                loop[uvl_].uv = src[uvl_].uv  # (the patch wears the body paint at its rim)
    if filled:
        bmesh.ops.triangulate(bm, faces=filled)
    # the cape's back face: a thin shell, its inside wearing the same paint
    cape_now = [f for f in bm.faces if f[capel]]
    solid = bmesh.ops.solidify(bm, geom=cape_now, thickness=OV.get("cloth_thickness", 0.012) * H)
    for g in solid["geom"]:
        if isinstance(g, bmesh.types.BMFace):
            g[capel] = 1
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    CAPE_V = set()
    bm.verts.index_update()
    for f in bm.faces:
        if f[capel]:
            CAPE_V.update(v.index for v in f.verts)
    bm.faces.layers.int.remove(capel)
    bm.to_mesh(me)
    bm.free()
    me.update()
    P = [v.co.copy() for v in me.vertices]
    NV = len(P)
    NEIGH = [[] for _ in range(NV)]
    for e in me.edges:
        a, b = e.vertices
        NEIGH[a].append(b)
        NEIGH[b].append(a)
    EDGES = [tuple(e.vertices) for e in me.edges]
    log("cape made its own piece: %d cape vertices (with its back face), %d patch faces closing the body" % (
        len(CAPE_V), len(filled)))
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
WEAPON_SIDE = "R"
hr = hands["R"]["c"]
for comp in islands:
    if weapon or len(comp) < 20 or len(comp) > NV * 0.4:
        continue
    pts = [P[i] for i in comp]
    for side in ("R", "L"):  # (a club can be in either hand: the Goblin King holds his in the left)
        hc = hands[side]["c"]
        near = min((p - hc).length for p in pts)
        reach = max((p - hc).length for p in pts)
        # (and it must stick out of the body: a cloak piece next to the hand reaches far too, but stays inside the
        # body's outline; a club or a sword leaves it)
        outside = max(Vector((p.x, p.y - spine_y(p.z), 0)).length for p in pts) > abs(hc.x) + 0.15 * H
        if near < 0.05 * H and reach > 0.3 * H and outside:
            weapon, WEAPON_SIDE, hr = comp, side, hc
            log("weapon found: %d vertices, reaching %.2f from the %s hand" % (len(comp), reach,
                                                                            "right" if side == "R" else "left"))
            break
if weapon:
    # the spikes, studs and bands on a club are often separate little pieces: take every small piece that lies inside
    # the weapon's box too (they stayed behind, floating, when only the main piece swung)
    wpts = [P[i] for i in weapon]
    blo = Vector([min(p[k] for p in wpts) - 0.03 * H for k in range(3)])
    bhi = Vector([max(p[k] for p in wpts) + 0.03 * H for k in range(3)])
    extra = 0
    wset = set(weapon)
    for comp in islands:
        if len(comp) < NV * 0.05 and not (set(comp) & wset) and all(
                blo.x <= P[i].x <= bhi.x and blo.y <= P[i].y <= bhi.y and blo.z <= P[i].z <= bhi.z for i in comp):
            weapon = weapon + comp
            extra += len(comp)
    if extra:
        log("weapon: %d more vertices in small pieces on it (spikes, bands)" % extra)
if not weapon:
    log("no weapon: nothing reaches out of either hand")

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
    if KIND == "robe":
        continue
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
if OV:
    V = lambda k: Vector(OV[k])  # noqa: E731
    spine_p = V("hips").lerp(V("chest"), 0.4)
    place = {
        "Hips": (V("hips"), spine_p), "Spine": (spine_p, V("chest")), "Chest": (V("chest"), V("neck") - Vector((0, 0, 0.05 * H))),
        "Neck": (V("neck") - Vector((0, 0, 0.05 * H)), V("neck")), "Head": (V("neck"), V("head_top")),
    }
    for s in ("L", "R"):
        place["UpperArm." + s] = (V("shoulder_" + s), V("elbow_" + s))
        place["LowerArm." + s] = (V("elbow_" + s), V("wrist_" + s))
        place["Hand." + s] = (V("wrist_" + s), V("hand_tip_" + s))
        if "hip_" + s in OV:
            place["UpperLeg." + s] = (V("hip_" + s), V("knee_" + s))
            place["LowerLeg." + s] = (V("knee_" + s), V("ankle_" + s))
            place["Foot." + s] = (V("ankle_" + s), V("toe_" + s))
    for name, (hd, tl) in place.items():
        if name in eb:
            eb[name].use_connect = False
            eb[name].head, eb[name].tail = hd, tl
            eb[name].align_roll(Vector((0, 0, 1)) if name.startswith("Foot") else FWD)
    # cloth chains: a list of joints each, hanging from the chest (a cape) or a forearm (a sleeve)
    CHAINS = {}
    for cname, spec in OV.get("chains", {}).items():
        parent = spec.get("parent", "Chest")
        pts = [Vector(q) for q in spec["points"]]
        names = []
        for n in range(len(pts) - 1):
            bn = "%s%d" % (cname, n + 1)
            bone(bn, pts[n], pts[n + 1], parent, n > 0, Vector((0, 0, 1)) if abs((pts[n + 1] - pts[n]).normalized().z) < 0.9 else FWD)
            parent = bn
            names.append(bn)
        CHAINS[cname] = names
        log("cloth chain %s: %d bones" % (cname, len(names)))
# a robe: four hem bones from the hips down to the hem's front, back and sides (it sways and trails)
HEM = {}
if KIND == "robe":
    low = [p for p in P if p.z < hip_z * 0.4]
    base = Vector((0, spine_y(hip_z), hip_z))
    HEM = {"F": min(low, key=lambda p: p.y), "B": max(low, key=lambda p: p.y),
           "L": max(low, key=lambda p: p.x), "R": min(low, key=lambda p: p.x)}
    for k, tip in HEM.items():
        bone("Hem." + k, base, Vector((tip.x, tip.y, max(tip.z, 0.02 * H))), "Hips", roll_up=Vector((0, 0, 1)) if k in "FB" else FWD)
    log("robe: 4 hem bones from the hips (%.2f) to the hem" % hip_z)


# a tail: mesh well behind the hips, low down (a devil's tail); a chain of 3 bones from the root out
def behind_back(z):
    ps = [p for p in P if abs(p.z - z) < 0.04 * H and abs(p.x) < 0.12 * H]
    return max(p.y for p in ps) if ps else 0.0


TAIL_V, WING_V = [], {"L": [], "R": []}
# (the back is measured at the chest, where no tail hangs; the tail lies low behind it)
back_ref = behind_back(chest_z)
for i, p in enumerate(P):
    if not OV and p.z < chest_z and p.y > back_ref + 0.1 * H and abs(p.x) < 0.3 * H:
        TAIL_V.append(i)
if len(TAIL_V) < 20:
    TAIL_V = []
# wings: out past the shoulders, from the armpits up (arms hang below; wings spread out at shoulder height)
for i, p in enumerate(P):
    s = "L" if p.x > 0 else "R"
    if not OV and i not in TAIL_V and armpit_z[s] - 0.02 * H < p.z < neck_z + 0.15 * H             and abs(p.x) > abs(shoulders[s].x) + 0.06 * H and p.y > shoulders[s].y - 0.02 * H:
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
    w_head = bones["Hand." + WEAPON_SIDE].tail.copy()
    bone("Weapon", w_head, far, "Hand." + WEAPON_SIDE, roll_up=FWD)
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
    elif n.startswith("Hem"):
        GROUP[n] = "hem"
    elif OV and any(n.startswith(c) for c in OV.get("chains", {})):
        GROUP[n] = "cloth"
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
        # a wing welded to the arm next to it (a wing grows from the back, never from the arm), and a cape welded to
        # the arm it hangs beside (the cape flapped out with the raised arm)
        elif arm and (other.startswith("wing") or (other == "cloth" and (not OV or OV.get("cut_arm_cloth", True)))):
            cut.append(e.index)  # (not for sleeves: they belong to the arm; "cut_arm_cloth": false in the file)
        # (cutting the arm from the cape by raw colour shredded the cape's front edge, 2026-11-25; see below)
    # a cape is its own garment: cut it off the body all along its edge (the cleaned colour mask), so arms and legs
    # move under it instead of dragging it
    if CLOTH_MASK and _pass == 0 and OV.get("cut_cloth_edge"):  # (off by default: on the King it shredded the cape)
        for e in me.edges:
            a, b = e.vertices
            if a < NV and b < NV and CLOTH_MASK[a] != CLOTH_MASK[b] and e.index not in cut:
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
    if i in CLOTH_OF:
        if CAPE_V is not None:
            # (a separate cape: the chest and the cape's chains only, blended across them; one chain each tore the
            # cape's thin shell apart where two chains met)
            return {"Chest"} | {b for names in CHAINS.values() for b in names}
        return {"Chest", "Spine", "Hips"} | set(CHAINS[CLOTH_OF[i]])
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
    if KIND == "robe" and p.z < hip_z + 0.03 * H:
        return {"Hips", "Hem.F", "Hem.B", "Hem.L", "Hem.R"}
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
# cloth: vertices behind or beside the body that lie nearer a chain bone than any body bone (a cape, a sleeve)
CLOTH_OF = {}
if OV and OV.get("chains"):
    chain_bones = {bn: c for c, names in CHAINS.items() for bn in names}
    body_bones = [b for b in BONES if b not in chain_bones and b != "Root"]
    cols = OV.get("cloth_colors", [])
    tol = OV.get("cloth_color_tolerance", 60)
    for i in range(NV):
        if i in HEAD_V or i in WEAPON_V:
            continue
        if (i in CAPE_V) if CAPE_V is not None else (CLOTH_MASK[i] if CLOTH_MASK and i < len(CLOTH_MASK) else cloth_color(i)):
            CLOTH_OF[i] = chain_bones[min((seg_dist(P[i], *REST[b]), b) for b in chain_bones)[1]]
            continue
        if CAPE_V is not None:
            continue  # (a separate cape: the body keeps everything that is not the cape)
        dc = min((seg_dist(P[i], *REST[b]), b) for b in chain_bones)
        db = min(seg_dist(P[i], *REST[b]) for b in body_bones)
        reach = OV["chains"][chain_bones[dc[1]]].get("radius")  # (a sleeve only takes cloth close to it)
        if dc[0] < db * OV.get("cloth_bias", 1.0) and (reach is None or dc[0] < reach):
            CLOTH_OF[i] = chain_bones[dc[1]]
    log("cloth vertices: %d" % len(CLOTH_OF))
ALLOWED = [(allowed(i) & set(BONES)) or {"Hips"} for i in range(NV)]  # (only bones this rig has)
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
if OV and OV.get("test_angles") and not STRESS:
    # (a monster whose moves stay small: the key-points file sets the angles it really uses)
    A, SW, HD = OV["test_angles"].get("arms", A), OV["test_angles"].get("swing", SW), OV["test_angles"].get("head", HD)
POSES = {
    "rest": [],
    "arms_up": [("UpperArm.L", (0, 1, 0), -A), ("UpperArm.R", (0, 1, 0), A)],
    "swing": [("Chest", (0, 0, 1), 25 if STRESS else 15), ("UpperArm.R", (1, 0, 0), -SW),
              ("LowerArm.R", (1, 0, 0), -40), ("UpperArm.L", (1, 0, 0), 35 if STRESS else 25)],
    "knees_45": [("Hips", (0, 0, 1), 0), ("UpperLeg.L", (1, 0, 0), -25), ("LowerLeg.L", (1, 0, 0), 45),
                 ("UpperLeg.R", (1, 0, 0), -25), ("LowerLeg.R", (1, 0, 0), 45)],
    "head_turn": [("Head", (0, 0, 1), HD)],
}
if KIND == "robe":
    # no legs: the hem swings back as it glides forward, and sways to a side
    del POSES["knees_45"]
    POSES["hem_sway"] = [("Hem.F", (1, 0, 0), 25), ("Hem.B", (1, 0, 0), 25), ("Hem.L", (0, 1, 0), 15),
                         ("Hem.R", (0, 1, 0), 15)]
log("test poses: %s (arms %d, head %d, swing %d)" % ("stress" if STRESS else "real use", A, HD, SW))
if weapon:
    POSES["swing"].append(("Hand.R", (1, 0, 0), -30))
    if WEAPON_SIDE == "L":
        # the swing is made with the weapon hand: mirror it to the left arm
        POSES["swing"] = [((n[:-1] + "L") if n.endswith(".R") else (n[:-1] + "R") if n.endswith(".L") else n, a, d)
                          for n, a, d in POSES["swing"]]


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
