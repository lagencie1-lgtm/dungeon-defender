"""The Ballista at its three levels, built with the tower kit to match art/ref3d/tower_ballista_l1..l3.png.
Part list from the pictures:
  level 1  stone ring footing; a wooden trestle (two A-frame legs with cross timbers and brass bolts); a turntable hub;
           the weapon: a thick stock, a curved wooden bow with rope wrappings and its string, a big bolt with an iron
           head and red fletching
  level 2  as level 1, heavier: iron-shod leg feet, iron bow arms with brass caps, a brass crank wheel on the side
  level 3  a round stone bastion with crenellations and three red banners; two level-2 ballistae on top
The weapons are their own part ("Skin_barrel": the game kicks it back on every shot). Front = the bolt's aim.
Run: blender -b -P tower_ballista_detail.py -- out.fbx <1|2|3> [params.json]"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import sculpt as S  # noqa: E402
import tower_kit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, level = args[0], int(args[1])
FRONT = -75
rad = math.radians
IRON = (0.47, 0.42, 0.45)
ROPE = (0.93, 0.86, 0.68)
RED = (0.78, 0.16, 0.16)
CRIMSON = (0.7, 0.14, 0.17)
# round 4: the weapon's own colours, measured off the paintings' weapons (the stock's dark warm wood about 120, 62, 30;
# its darker rail and bolt; the iron arms of levels 2 and 3 a warm grey): the repaint leaves the weapon alone
# (weapon gate, round 4: the rendered weapon came out 7-12 L* darker and a little more saturated (b* 32 against 25)
# than the painting's weapon: lighter and a touch greyer)
WEAPON_WOOD = (0.58, 0.38, 0.27)
WEAPON_DARK = (0.42, 0.27, 0.19)
# (round 5 weapon gate: level 1's wooden bow is a warm mid brown in the painting, the weapon came out greyer and
# darker (Lab 34.5 15 21 against 38.8 24 28) with dark-wood arms)
BOW_WOOD = (0.66, 0.34, 0.16)
LAYOUT = []
BOWLINES = []
# round 2 (2026-11-24): the paintings' wood is a warm mid-dark brown (about 130, 72, 38), not the kit's pale pine
K.WOOD = (0.55, 0.32, 0.17)
K.WOOD_DARK = (0.38, 0.21, 0.11)

DEFAULTS = {
    1: dict(foot_r=2.9, foot_h=0.8, foot_n=10, leg_h=2.2, leg_spread=1.2, bow_w=4.4, stock=4.6, aim=40, pitch=14, bend=1.0, thick=1.3, roll=65),
    2: dict(foot_r=3.0, foot_h=0.8, foot_n=10, leg_h=2.4, leg_spread=1.3, bow_w=4.8, stock=5.0, aim=40, pitch=14, bend=1.0, thick=1.3, roll=65),
    # level 3: a wide squat crenellated bastion, two big ballistae side by side on it (coordinator 2026-11-24)
    3: dict(foot_r=4.4, foot_h=0.8, foot_n=12, wall_r=3.6, wall_h=2.5, bow_w=4.0, stock=4.2, aim=40, pitch=10, gap=1.9, bend=1.0, thick=1.2, roll=65),
}
P = dict(DEFAULTS[level])
saved = os.path.join(HERE, "params", f"tower_ballista_l{level}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
# round 4 (coordinator 2026-11-24, from the paintings): the weapon is the biggest thing, the stock about 1.3 times the
# trestle's height, tilted up about 15 degrees (level 3's sit nearly level on their cradles)
if level in (1, 2):
    P["stock"] = round(1.3 * (P["leg_h"] + 0.75), 3)
    P["pitch"] = float(os.environ.get("HTD_PITCH", P.get("pitch_fixed", 15)))   # (HTD_PITCH: the pitch sweep in tools/bal_cover.sh)
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()
K.SIZES["barrel"] = 512
A = rad(FRONT + P["aim"])
FWD = Vector((math.cos(A), math.sin(A), 0))
SIDE = Vector((-math.sin(A), math.cos(A), 0))


def place_all(objs, m):
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def weapon(name, base, iron=False, scale=1.0):
    """stock, bow, string and bolt, built at the origin pointing along +Y, then turned to the aim and tilted up.
    Round 2 (coordinator 2026-11-24, "a real bow with two arms, a string and a bolt on every level"): the bow is a big
    C at the FRONT of the stock (its middle ahead of the stock's nose, both arms sweeping back to the stock's middle),
    as thick as the paintings draw it; the string runs from both tips back to the notch at the stock's rear; the bolt
    lies on top, iron head out front, red fletching at the back"""
    before = set(bpy.context.scene.objects)
    st = P["stock"] * scale
    span = st * 0.9   # (round 4: the bow spans about 0.9 of the stock)
    # round 5 (coordinator 2026-11-24): the stock is a long slender beam (width about 0.12 of its length) with a groove
    # on top and the bolt lying in it, gold bands, a trigger block at the rear; small red fletching on the bolt's tail
    sw, sh = 0.12 * st, 0.11 * st
    ztop = sh / 2 + 0.04 * st          # top of the groove's rails
    with K.atlas("barrel"):
        K.block(name + "Stock", (0, 0, 0), (sw, st, sh), WEAPON_WOOD, key=None, tile=1.2, bevel=0.04 * st)
        for e in (-1, 1):   # the groove: two rails along the top
            K.block(name + f"Rail{e}", (e * sw * 0.36, st * 0.02, sh / 2 + 0.02 * st), (sw * 0.28, st * 0.92, 0.05 * st), WEAPON_DARK, key=None, tile=1.0, bevel=0.01 * st)
        for k in (-0.3, 0.12, 0.42):   # gold bands round the stock
            K.block(name + f"Band{k}", (0, st * k, 0.01 * st), (sw * 1.18, 0.05 * st, sh * 1.22), K.BRASS, key=None, tile=0.6, bevel=0.01 * st)
        K.block(name + "Trigger", (0, -st * 0.45, -0.02 * st), (sw * 1.3, 0.12 * st, sh * 1.45), WEAPON_DARK, key=None, tile=0.8, bevel=0.02 * st)
        K.block(name + "TriggerPlate", (0, -st * 0.45, sh * 0.55), (sw * 1.34, 0.06 * st, 0.03 * st), K.BRASS, key=None, tile=0.6, bevel=0.005 * st)
        # round 5: the bow lies FLAT (the layout gate stays) but deeply curved, as painted: each arm leaves the stock's
        # nose sideways and sweeps back in a strong arc, the whole bow close to a half circle seen from above (arc
        # depth from the nose to the tips at least 0.4 of the span); arms thick at the centre (about 0.12 of the
        # span), tapering to the tips; the string from tip to tip, drawn back to the notch
        nose = st * 0.5
        # (a C a little past a half circle, +-100 degrees, like the paintings' bows: a flat arc cut at +-80 degrees reads
        # as an arc (sagitta >= 0.3 chord) from only 10 of 16 directions at 32 degrees, even drawn as a thin line)
        R = span / (2 * math.sin(rad(100)))
        pts = []
        for k in range(17):
            th_ = rad(-100 + 200 * k / 16)
            pts.append(Vector((R * math.sin(th_), nose - R * (1 - math.cos(th_)), ztop)))
        depth = nose - pts[0].y
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            d = p1 - p0
            mid = (p0 + p1) / 2
            taper = 1.0 - 0.55 * abs(mid.x) / (span / 2)
            yaw = math.atan2(d.y, d.x)
            w_ = 0.12 * span * taper
            if iron:   # flat, tapered iron
                K.block(name + f"Arm{i}", tuple(mid), (d.length * 1.1, w_, w_ * 0.6), IRON, (0, 0, yaw), key=None, tile=0.8, bevel=0.02 * span)
            else:      # squared timber
                K.block(name + f"Arm{i}", tuple(mid), (d.length * 1.1, w_, w_ * 0.9), BOW_WOOD, (0, 0, yaw), key=None, tile=0.8, bevel=0.02 * span)
        K.block(name + "BowBlock", (0, nose, ztop), (0.2 * span, 0.12 * span, 0.13 * span), K.BRASS if iron else WEAPON_DARK, key=None, bevel=0.02 * span)
        notch = (0, -st * 0.38, ztop + 0.01 * st)
        for tip in (pts[0], pts[-1]):
            if iron:
                K.block(name + f"Cap{tip.x:.1f}", tuple(tip), (0.1 * span, 0.1 * span, 0.08 * span), K.BRASS, key=None, tile=0.6, bevel=0.015 * span)
            else:
                K.block(name + f"Lash{tip.x:.1f}", tuple(tip), (0.085 * span, 0.09 * span, 0.09 * span), ROPE, key=None, bevel=0.015 * span)
            K.limb(name + f"String{tip.x:.1f}", tuple(tip), notch, 0.012 * st, 0.012 * st, ROPE, verts=6, end=False)
        # the bolt in the groove, iron head out front, small red fletching at its tail
        zb = sh / 2 + 0.03 * st
        K.limb(name + "Bolt", (0, -st * 0.38, zb), (0, st * 0.6, zb), 0.025 * st, 0.025 * st, WEAPON_DARK, verts=6, end=False)
        K.cone(name + "Head", (0, st * 0.66, zb), 0.06 * st, 0.14 * st, IRON, rot=(rad(-90), 0, 0), verts=4)
        for s_ in (-1, 1):
            K.block(name + f"Fletch{s_}", (s_ * 0.03 * st, -st * 0.3, zb + 0.035 * st), (0.012 * st, 0.13 * st, 0.07 * st), RED, (0, s_ * rad(32), 0), key=None, bevel=0.0)
    # the layout gate (docs/tower-pipeline.md "pose against the object's layout"): the bow's tips level with each
    # other and with the stock's top (within 15 degrees of its plane), mirror images left and right
    lt, rt = pts[0], pts[-1]
    plane = math.degrees(math.atan2(abs(lt.z - rt.z), abs(lt.x - rt.x)))
    sym = abs(lt.x + rt.x) + abs(lt.y - rt.y) + abs(lt.z - rt.z)
    LAYOUT.append({"weapon": name, "bow_plane_deg": round(plane, 1), "asymmetry": round(sym, 3), "span_over_stock": round(span / st, 2),
                   "arc_depth_over_span": round(depth / span, 2)})
    made = [o for o in set(bpy.context.scene.objects) - before]
    m = Matrix.Translation(base) @ Matrix.Rotation(A - rad(90), 4, "Z") @ Matrix.Rotation(rad(P["pitch"]), 4, "X")
    place_all(made, m)
    BOWLINES.append([list(m @ q) for q in pts])   # (the bow's centre line in the world, for scripts/bow_gate.py)
    return m @ Vector((0, st * 0.72, zb))   # (the bolt's iron head)


def trestle(base_z, h, spread, iron=False, scale=1.0):
    """round 5 (coordinator 2026-11-24, from the painting): two A-frames, one each side of the weapon, each of two square
    legs splayed fore and aft and meeting under the hub, a cross brace across the A low down, gold bolts at the
    joints; a top beam and a low tie join the two A-frames; a turntable hub on top"""
    side = spread * 0.75
    for s in (-1, 1):
        c = SIDE * (s * side)
        tops = []
        for f in (-1, 1):
            foot = c + FWD * (f * spread * 1.05)
            top = c + FWD * (f * 0.18 * scale)
            tops.append(top)
            K.limb(f"Leg{s}{f}{base_z:.1f}", (foot.x, foot.y, base_z), (top.x, top.y, base_z + h), 0.42 * scale, 0.38 * scale, K.WOOD, verts=4, end=False)   # (square beams, as painted)
            if iron:
                K.block(f"Shoe{s}{f}{base_z:.1f}", (foot.x, foot.y, base_z + 0.25), (0.6 * scale, 0.6 * scale, 0.5 * scale), IRON, key=None, tile=0.8, bevel=0.06)
        # the cross brace across the A, a third of the way up, with gold bolts at both legs
        t = 0.33
        q = [Vector((c.x, c.y, base_z)) + FWD * (f * spread * 1.05) for f in (-1, 1)]
        q = [qq.lerp(Vector((tp.x, tp.y, base_z + h)), t) for qq, tp in zip(q, tops)]
        mid = (q[0] + q[1]) / 2
        K.block(f"Cross{s}{base_z:.1f}", tuple(mid), ((q[1] - q[0]).length + 0.5 * scale, 0.34 * scale, 0.3 * scale), K.WOOD_DARK,
                (0, 0, A), key="wood_dark", tile=1.0, bevel=0.06)
        for qq in q:
            K.ball(f"Bolt{s}{qq.x:.1f}{base_z:.1f}", tuple(qq + SIDE * (s * 0.24 * scale)), 0.13 * scale, K.BRASS, seg=8)
        K.ball(f"TopBolt{s}{base_z:.1f}", tuple(c + SIDE * (s * 0.24 * scale) + Vector((0, 0, base_z + h * 0.88))), 0.14 * scale, K.BRASS, seg=8)
    # top beam and low tie between the two A-frames
    K.block(f"TopBeam{base_z:.1f}", (0, 0, base_z + h - 0.15 * scale), (0.4 * scale, side * 2 + 0.5 * scale, 0.32 * scale), K.WOOD_DARK,
            (0, 0, A), key="wood_dark", tile=1.0, bevel=0.06)
    K.block(f"Tie{base_z:.1f}", (0, 0, base_z + h * 0.2), (0.3 * scale, side * 2, 0.26 * scale), K.WOOD_DARK,
            (0, 0, A), key="wood_dark", tile=1.0, bevel=0.05)
    K.lathe(f"Hub{base_z:.1f}", [(0.9 * scale, base_z + h - 0.1), (0.95 * scale, base_z + h + 0.2), (0.6 * scale, base_z + h + 0.35)], K.WOOD_DARK, key="wood_dark", verts=16)
    for s in (-1, 1):
        K.block(f"Cheek{s}{base_z:.1f}", tuple(SIDE * (s * 0.45 * scale) + Vector((0, 0, base_z + h + 0.55 * scale))), (0.25 * scale, 0.7 * scale, 0.75 * scale),
                IRON if iron else K.WOOD_DARK, (0, 0, A + rad(90)), key=None, tile=0.8, bevel=0.08)
    return base_z + h + 0.75 * scale


K.stone_ring("Foot", 0, P["foot_r"], P["foot_h"], P["foot_n"], depth=1.1)
K.lathe("FootCore", [(P["foot_r"] - 0.9, 0), (P["foot_r"] - 0.9, P["foot_h"] - 0.02)], K.MORTAR)
K.grass(P["foot_r"] - 0.05, 22, h=0.75)
fz = P["foot_h"]
muzzles = []
if level in (1, 2):
    if level == 2:   # (coordinator 2026-11-24: level 2 stands on a raised timber platform, so it reads apart from level 1)
        # (round 4: 1.2 tall, not 0.6: at 0.6 levels 1 and 2 were the same height and overlapped 84 % on the phone)
        K.block("Platform", (0, 0, fz + 0.6), (3.6, 3.6, 1.2), K.WOOD_DARK, (0, 0, A), key="wood_dark", tile=1.2, bevel=0.1)
        for k in range(4):
            q = FWD * (1.55 * (1 if k % 2 else -1)) + SIDE * (1.55 * (1 if k < 2 else -1))
            K.block(f"PlatformCap{k}", (q.x, q.y, fz + 1.22), (0.5, 0.5, 0.14), K.BRASS, (0, 0, A), key=None, bevel=0.03)
        fz += 1.2
    top = trestle(fz, P["leg_h"], P["leg_spread"], iron=(level == 2))
    muzzles.append(weapon("W", Vector((0, 0, top)), iron=(level == 2)))
    if level == 2:
        # round 5 (coordinator 2026-11-24, as painted): a small gold gear with teeth beside the stock's pivot, about a
        # third of the trestle's height across, on the side the camera sees, with two crank handles on its axle
        r = (P["leg_h"] + 0.75) / 6
        c = -SIDE * (P["leg_spread"] * 0.75 + 0.45) - FWD * 0.15 + Vector((0, 0, top - 0.45))   # (outside the A-frame on that side)
        ax = Matrix.Translation(c) @ Matrix.Rotation(rad(90), 4, Vector((FWD.x, FWD.y, 0)))
        g = K.lathe("Gear", [(0.0, -0.12), (r, -0.12), (r, 0.12), (0.0, 0.12)], K.BRASS, key="brass", verts=24)
        g.matrix_world = ax
        for k in range(12):   # the teeth
            a_ = k * math.pi / 6
            d = FWD * math.cos(a_) + Vector((0, 0, math.sin(a_)))
            K.block(f"Tooth{k}", tuple(c + d * (r + 0.07)), (0.16, 0.22, 0.16), K.BRASS, (0, 0, 0), key="brass", tile=0.5, bevel=0.03)
        K.ball("GearHub", tuple(c - SIDE * 0.14), r * 0.35, K.BRASS, seg=10)
        K.limb("Axle", tuple(c + SIDE * 0.5), tuple(c - SIDE * 0.55), 0.08, 0.08, IRON, verts=8)
        e = c - SIDE * 0.55
        bar0, bar1 = e + Vector((0, 0, r * 1.1)), e - Vector((0, 0, r * 1.1))
        K.limb("CrankBar", tuple(bar0), tuple(bar1), 0.07, 0.07, IRON, verts=6)
        for q in (bar0, bar1):   # the two handles
            K.limb(f"Handle{q.z:.1f}", tuple(q), tuple(q - SIDE * 0.3), 0.06, 0.06, IRON, verts=6)
            K.ball(f"Knob{q.z:.1f}", tuple(q - SIDE * 0.36), 0.13, K.BRASS, seg=8)
else:
    # the bastion: cut stone wall, crenellations, a wooden deck, three red banners
    K.stone_wall("Wall", fz, fz + P["wall_h"], P["wall_r"] * 1.18, P["wall_r"], 4, 13, depth=0.5)   # (wide at the foot, as painted)
    top = fz + P["wall_h"]
    K.lathe("Deck", [(P["wall_r"] - 0.3, top - 0.05), (P["wall_r"] - 0.3, top + 0.15)], K.WOOD_DARK, key="wood_dark", verts=24)
    for i in range(8):
        a = rad(FRONT + 22.5 + i * 45)
        K.block(f"Merlon{i}", K.at(a, P["wall_r"] - 0.1, top + 0.45), (1.2, 0.7, 0.95), K.STONE, (0, 0, a + rad(90)), key=None, tile=1.2, bevel=0.14)
    for k, da in enumerate((-40, 0, 40)):
        K.banner(FRONT + da, P["wall_r"] + 0.05, top - 0.05, 1.1 if da else 1.4, 1.8 if da else 2.4, field=CRIMSON, trim=K.BRASS, mark=K.BRASS)
    for s in (-1, 1):
        base = SIDE * (s * P["gap"]) + Vector((0, 0, top + 0.15))
        before = set(bpy.context.scene.objects)
        t2 = trestle(top + 0.15, 1.3, 0.55, iron=True, scale=0.8)   # (round 4: raised so stocks and bows clear the merlons)
        place_all([o for o in set(bpy.context.scene.objects) - before], Matrix.Translation((base.x, base.y, 0)))
        for e in (-1, 1):   # the gold arched cradle each weapon sits in
            q = Vector((base.x, base.y, t2 - 0.35)) + SIDE * (e * 0.42)
            K.block(f"Cradle{s}{e}", tuple(q), (0.22, 0.9, 1.1), K.BRASS, (0, 0, A), key="brass", tile=0.6, bevel=0.1)
        muzzles.append(weapon(f"W{s}", Vector((base.x, base.y, t2)), iron=True, scale=1.4))

for g in LAYOUT:
    ok = (g["bow_plane_deg"] <= 15 and g["asymmetry"] < 0.02 and 0.8 <= g["span_over_stock"] <= 1.0
          and g["arc_depth_over_span"] >= 0.4)   # (round 5: a deep arc, close to a half circle)
    print("LAYOUT %s %s" % ("ok" if ok else "FAIL", g))
    if not ok:
        raise SystemExit("ballista layout gate failed: %s" % g)
json.dump(BOWLINES, open(os.path.abspath(out)[:-4] + "_bow.json", "w"))
for m in muzzles:
    print("MUZZLE Vector3.new(%.2f, %.2f, %.2f)" % (-m.x, m.z, m.y))
if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_ballista_l{level}", out, budget=9000)
