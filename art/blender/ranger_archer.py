"""The Ranger's archer as its own character asset (coordinator 2026-11-23; Lemp rated the tower archers 2/10), built
with the pet kit (art/blender/petkit.py: soft shapes melted into one skin, the face as crisp "keep" paint that later
painting leaves alone) to match art/ref3d/archer/ranger_archer.png (chibi, head about 40% of the height).

Two models that fit together, so the game can move the arms:
  ranger_archer       head in a big pointed hood, tunic, belt, legs and boots, quiver of white-fletched arrows
  ranger_archer_arms  both arms with bracers and hands, the bow and the drawn arrow (pivot: between the shoulders)
The archer faces -Y (towards the camera), the arrow points along +X (to his left), like the picture: the game turns
the whole archer so his left side faces the target. Units: 2.4 tall; the game scales it.

Run: blender -b -P ranger_archer.py -- out.fbx <body|arms> [params.json]"""
import json
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import petkit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, part = args[0], args[1]
rad = math.radians

P = dict(head_z=1.62, head_r=0.41, hood_r=0.62, opening=58, tip=0.68, body_z=1.04, body_r=0.4, legs=0.3, boot=0.22,
         shoulder_z=1.32, arm=0.15, bow_x=0.82, bow_h=1.6, look=12)
if len(args) > 2 and os.path.exists(args[2]):
    P.update(json.load(open(args[2])))

GREEN = (0.42, 0.62, 0.2)
GREEN_DARK = (0.27, 0.45, 0.13)
LINING = (0.92, 0.86, 0.6)
SKIN = (0.98, 0.72, 0.52)
SKIN_SHADE = (0.9, 0.62, 0.45)
HAIR = (0.45, 0.27, 0.14)
LEATHER = (0.55, 0.32, 0.16)
LEATHER_DARK = (0.4, 0.22, 0.11)
TROUSERS = (0.4, 0.27, 0.16)
BRASS = (0.92, 0.7, 0.24)
WOOD = (0.62, 0.36, 0.17)
FLETCH = (0.96, 0.93, 0.84)
IRON = (0.78, 0.78, 0.8)


def hood_shell(center, r, scale, opening):
    """the hood as a real shell: a ball with the front cut open round the face (opening = degrees from the front),
    given thickness. It stays a crisp piece of its own (a melted ball would swallow the face)."""
    import bmesh
    import bpy
    from mathutils import Vector
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    cut = [v for v in bm.verts if Vector((v.co.x, v.co.y, v.co.z * 0.9)).normalized().dot(Vector((0, -1, -0.12)).normalized()) > math.cos(rad(opening))]
    bmesh.ops.delete(bm, geom=cut, context="VERTS")
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.07)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    mesh = bpy.data.meshes.new("Hood")
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new("Hood", mesh)
    bpy.context.scene.collection.objects.link(o)
    return K._finish_piece(o, "Hood", GREEN, "hard", GREEN_DARK)


K.start()
hz, hr = P["head_z"], P["head_r"]
sz = P["shoulder_z"]

if part == "body":
    # head: a real head (skull, low cheeks, small jaw); the face looks a little towards the aim (+X) like the picture
    TURN = rad(P.get("look", 24))

    def d(x, y, z):   # a direction from the head centre, turned towards the aim
        return (x * math.cos(TURN) - y * math.sin(TURN), x * math.sin(TURN) + y * math.cos(TURN), z)
    head = K.head("Head", (0, -0.14, hz), hr, SKIN, wide=1.0, cheeks=0.4, cheek_drop=0.45, jaw=0.55, brow=0.0, back=0.2)   # a boy's face with a chin, not a round pet head
    # the face: big clear eyes with a white shine, short determined brows, a small smile, a nose
    for sd in (-1, 1):
        # the picture's eyes: a dark outline, a big dark-brown iris and pupil, ONE small shine (two big shines read as a
        # cute pet / anime face, Gemini 2026-11-23)
        e = d(sd * 0.34, -1, 0.02)
        K.patch(head, e, hr * 0.21, K.INK, (0.9, 1.22), sd * 4, 0.016, name=f"EyeRim{sd}", lit=False, keep=True)
        K.patch(head, e, hr * 0.185, (0.98, 0.96, 0.92), (0.9, 1.2), sd * 4, 0.02, name=f"EyeWhite{sd}", lit=False, keep=True)
        K.patch(head, d(sd * 0.34 + 0.03, -1, -0.01), hr * 0.13, (0.42, 0.24, 0.1), (0.85, 1.1), 0, 0.024, name=f"EyeIris{sd}", lit=False, keep=True)
        K.patch(head, d(sd * 0.34 + 0.03, -1, -0.01), hr * 0.075, (0.08, 0.05, 0.03), (0.9, 1.1), 0, 0.028, name=f"EyePupil{sd}", lit=False, keep=True)
        K.patch(head, d(sd * 0.34 - 0.01, -1, 0.06), hr * 0.04, (1, 1, 1), (1, 1), 0, 0.034, name=f"EyeShine{sd}", lit=False, keep=True)
        K.patch(head, d(sd * 0.36, -1, 0.36), hr * 0.25, (0.33, 0.18, 0.08), (1.0, 0.24), sd * -14, 0.03, name=f"Brow{sd}", lit=False, keep=True)   # a little lowered at the middle: determined
    for sd in (-1, 1):
        K.patch(head, d(0.05 + sd * 0.1, -1, -0.45), hr * 0.13, (0.36, 0.16, 0.1), (1.0, 0.22), sd * 16, 0.02, name="Smile", lit=False, keep=True)
    K.patch(head, d(0.02, -1, -0.12), hr * 0.11, SKIN_SHADE, (1.0, 0.9), name="Nose", role="soft", bulge=0.9)
    # hair: a brown fringe under the hood rim
    # (painted, big: the picture's fringe covers the top third of the face, with two locks at the sides)
    # hair: real strands (soft cones melted into the head) swept across the forehead and down the sides
    for i, (x, z, tx, tz) in enumerate(((-0.5, 0.75, -0.62, 0.2), (-0.2, 0.86, -0.32, 0.42), (0.1, 0.88, -0.02, 0.45),
                                         (0.4, 0.8, 0.36, 0.35), (0.66, 0.62, 0.72, 0.12), (-0.7, 0.5, -0.76, -0.05))):
        p0, _ = K.on(head, d(x, -0.62, z))
        p1, n1 = K.on(head, d(tx, -0.8, tz))
        K.limb(f"Hair{i}", tuple(p0), tuple(p1 + n1 * 0.02), hr * 0.17, hr * 0.03, HAIR)
    # the hood: a big shell behind and over the head (the face stays in front of it), a cream lining rope framing the
    # face and a long pointed tip falling back
    hood_shell((0, 0.1, hz + 0.12), P["hood_r"], (1.04, 1.0, 1.16), P["opening"])
    rim = []   # exactly on the cut edge of the hood's opening (it also hides the cut's steps)
    from mathutils import Vector
    op = rad(P["opening"])
    ax = Vector((0, -1, -0.12)).normalized()
    u = Vector((1, 0, 0))
    v = ax.cross(u).normalized()
    hc, hs = Vector((0, 0.1, hz + 0.12)), (1.04, 1.0, 1.16)
    for i in range(21):
        a = rad(-125 + i * 250 / 20)
        p = ax * math.cos(op) + (u * math.cos(a) + v * math.sin(a)) * math.sin(op)
        p = p * P["hood_r"] * 0.99
        rim.append(tuple(hc + Vector((p.x * hs[0], p.y * hs[1], p.z * hs[2]))))
    K.rope("Lining", rim, [0.065] * len(rim), LINING)
    tip0 = (0, 0.22, hz + 0.6)
    K.limb("HoodTip", tip0, (-0.34, tip0[1] + P["tip"] * 0.8, tip0[2] + P["tip"] * 0.15), 0.3, 0.05, GREEN, color2=GREEN_DARK, role="hard")   # the peak falls back, a little to his right (the picture's left)
    K.ball("HoodCape", (0, 0.06, sz - 0.02), 0.36, GREEN, (1.25, 0.95, 0.5), color2=GREEN_DARK)
    # tunic, belt with a brass buckle, a cream hem, a cross strap for the quiver
    K.ball("Tunic", (0, 0, P["body_z"]), P["body_r"], GREEN, (1.08, 0.86, 1.1), color2=GREEN_DARK)
    K.cone("Skirt", (0, 0, P["body_z"] - 0.32), P["body_r"] * 1.32, 0.36, GREEN, top=P["body_r"] * 0.95, verts=24)
    K.limb("Hem", (0, 0, P["body_z"] - 0.51), (0, 0, P["body_z"] - 0.44), P["body_r"] * 1.36, P["body_r"] * 1.31, LINING, cap=False)
    K.limb("Belt", (0, 0, P["body_z"] - 0.16), (0, 0, P["body_z"] - 0.05), P["body_r"] * 1.02, P["body_r"] * 1.02, LEATHER, cap=False)
    K.rock("Buckle", (0, -P["body_r"] * 0.98, P["body_z"] - 0.105), 0.075, BRASS, (1.2, 0.5, 1.0))
    K.rope("Strap", [(-0.3, -0.25, sz - 0.1), (0, -0.33, P["body_z"] - 0.02), (0.3, -0.24, P["body_z"] - 0.2)], [0.045, 0.05, 0.045], LEATHER_DARK)
    # legs and big boots
    for s in (-1, 1):
        K.limb(f"Leg{s}", (s * 0.14, 0, P["body_z"] - 0.42), (s * 0.3, 0, P["boot"] + 0.12), 0.14, 0.13, TROUSERS)
        K.ball(f"Boot{s}", (s * 0.31, -0.07, P["boot"] * 0.75), P["boot"], LEATHER, (1.0, 1.45, 0.95))
        K.limb(f"BootTop{s}", (s * 0.3, 0, P["boot"] + 0.02), (s * 0.3, 0, P["boot"] + 0.28), 0.16, 0.18, LEATHER_DARK, cap=False)
    # quiver on the back with white-fletched arrows (hard: crisp shapes)
    q0, q1 = (0.12, 0.36, P["body_z"] - 0.28), (-0.24, 0.4, sz + 0.18)   # over his right shoulder, as the picture shows it
    K.limb("Quiver", q0, q1, 0.16, 0.19, LEATHER, role="hard")
    K.limb("QuiverRim", (q1[0] - 0.01, q1[1], q1[2] - 0.05), (q1[0] + 0.01, q1[1], q1[2] + 0.02), 0.2, 0.2, LEATHER_DARK, role="hard", cap=False)
    for k in range(4):
        x = q1[0] - 0.08 + k * 0.05
        K.limb(f"Shaft{k}", (x, q1[1], q1[2]), (x + 0.03 + k * 0.01, q1[1] + 0.02, q1[2] + 0.28), 0.018, 0.018, WOOD, role="hard")
        for f in (-1, 1):
            base = (x + 0.03 + k * 0.01, q1[1] + 0.02, q1[2] + 0.2)
            K.sheet(f"Fletch{k}{f}", [base, (base[0] + f * 0.07, base[1], base[2] + 0.02), (base[0] + f * 0.05, base[1], base[2] + 0.14), (base[0], base[1], base[2] + 0.12)],
                    [(0, 1, 2), (0, 2, 3)], FLETCH, thickness=0.012)
    K.finish("ranger_archer", out, triangles=10000, size=1024, voxel=0.02, melt=5)
else:
    # arms: the bow arm (his left, +X) straight out to the bow, the string arm bent with the hand at the cheek
    sh_l, sh_r = (0.36, -0.02, sz), (-0.36, -0.02, sz)
    bow_x = P["bow_x"]
    hand_l = (bow_x - 0.06, -0.08, sz + 0.02)
    hand_r = (0.18, -0.16, sz + 0.08)
    elbow_r = (-0.44, -0.02, sz + 0.02)
    K.limb("ArmL", sh_l, hand_l, P["arm"], P["arm"] * 0.9, GREEN, color2=GREEN_DARK)
    K.limb("CuffL", (0.36, -0.02, sz), (0.42, -0.03, sz + 0.003), P["arm"] * 1.35, P["arm"] * 1.3, LINING, cap=False)
    K.limb("BracerL", (bow_x - 0.36, -0.06, sz + 0.01), (bow_x - 0.17, -0.07, sz + 0.02), P["arm"] * 1.25, P["arm"] * 1.2, LEATHER)
    K.ball("HandL", hand_l, 0.12, SKIN, (1.0, 1.0, 1.15))
    K.limb("ArmR1", sh_r, elbow_r, P["arm"], P["arm"] * 0.95, GREEN, color2=GREEN_DARK)
    K.limb("ArmR2", elbow_r, hand_r, P["arm"] * 0.95, P["arm"] * 0.85, SKIN)
    K.limb("BracerR", (-0.2, -0.1, sz + 0.05), (0.02, -0.14, sz + 0.07), P["arm"] * 1.2, P["arm"] * 1.15, LEATHER)
    K.ball("HandR", hand_r, 0.115, SKIN)
    # the bow: a recurve in the X-Z plane at the left hand, string to the drawing hand, the arrow along +X
    h = P["bow_h"]
    pts = []
    for t in (-1.0, -0.75, -0.4, 0.0, 0.4, 0.75, 1.0):
        x = bow_x + 0.12 * (1 - t * t) - (0.06 * (abs(t) ** 3) if abs(t) > 0.7 else 0)
        pts.append((x, -0.08, sz + 0.02 + t * h * 0.5))
    K.chain("Bow", pts, [0.035, 0.05, 0.065, 0.07, 0.065, 0.05, 0.035], WOOD, role="hard")
    K.limb("Grip", (bow_x + 0.11, -0.08, sz - 0.06), (bow_x + 0.11, -0.08, sz + 0.1), 0.055, 0.055, LEATHER_DARK, role="hard")
    for end in (pts[0], pts[-1]):
        K.limb("String", end, hand_r, 0.008, 0.008, FLETCH, role="hard", cap=False)
    tip = (bow_x + 0.42, -0.1, sz + 0.06)
    K.limb("Arrow", hand_r, tip, 0.016, 0.016, WOOD, role="hard", cap=False)
    K.cone("ArrowHead", (tip[0] + 0.06, tip[1], tip[2]), 0.045, 0.14, IRON, rot=(0, rad(90), 0), verts=4, role="hard")
    for f in (-1, 1):
        b = (hand_r[0] + 0.04, hand_r[1], hand_r[2] - 0.003)
        K.sheet(f"ArrowFletch{f}", [b, (b[0] + 0.16, b[1], b[2]), (b[0] + 0.12, b[1], b[2] + f * 0.06), (b[0] + 0.02, b[1], b[2] + f * 0.05)],
                [(0, 1, 2), (0, 2, 3)], FLETCH, thickness=0.01)
    print("MUZZLE_LOCAL %.3f %.3f %.3f" % (tip[0] + 0.12, tip[1], tip[2]))
    print("PIVOT %.3f %.3f %.3f" % (0, -0.02, sz))
    K.finish("ranger_archer_arms", out, triangles=5000, size=512, voxel=0.018, melt=4)
