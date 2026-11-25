"""The Flame Cannon at its three levels, built with the tower kit (art/blender/tower_kit.py) to match
art/ref3d/tower_flame_l1..l3.png (docs/tower-pipeline.md). Part list from the pictures:
  level 1  stone ring footing, a wooden cradle (two side frames with cross timbers, brass bolts), an iron mortar
           tilted up to the front, a thick banded rim with rivets, fire inside
  level 2  the footing, a round wooden drum with a brass band, brass trunnion arms and a big brass hub, a bronze
           barrel with brass bands, a coal hopper (brass-rimmed box of glowing coal) behind
  level 3  the footing, a tall wooden drum with brass bands, rivets and glowing arched vents, a brass collar, a turret
           with twin bronze barrels, a little chimney
The barrel(s) are their own part ("Skin_barrel"): the game kicks it back on every shot. The fire in the mouths is
a glowing part (Neon). FRONT (the barrel's aim) looks at the picture's camera.
Run: blender -b -P tower_flame_detail.py -- out.fbx <1|2|3> [params.json]"""
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
IRON = (0.42, 0.42, 0.45)
IRON_DARK = (0.28, 0.28, 0.31)
BRONZE = (0.62, 0.34, 0.2)
FIRE = (1.0, 0.55, 0.12)
COAL = (0.16, 0.15, 0.16)

DEFAULTS = {
    1: dict(foot_r=3.2, foot_h=0.9, foot_n=10, cradle=2.2, barrel_r=1.15, barrel_len=3.0, tilt=38, barrel_z=2.4, aim=55),
    2: dict(foot_r=3.2, foot_h=0.9, foot_n=10, drum_r=2.3, drum_h=1.7, barrel_r=1.05, barrel_len=3.6, tilt=30, barrel_z=3.6, aim=55),
    3: dict(foot_r=3.4, foot_h=0.9, foot_n=10, drum_r=2.8, drum_h=3.4, barrel_r=0.8, barrel_len=3.6, tilt=22, barrel_z=5.6, aim=55),
}
P = dict(DEFAULTS[level])
saved = os.path.join(HERE, "params", f"tower_flame_l{level}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()
K.SIZES["barrel"] = 512
K.GOLD_SMOOTH = True   # (the gold-trim rule, coordinator 2026-11-25)


def aim_frame(z, tilt, side=0.0):
    """a frame at height z that looks along the barrel: forward toward FRONT, tilted up by `tilt` degrees"""
    a = rad(FRONT + P["aim"])   # the pictures aim it to the front right
    fwd = Vector((math.cos(a), math.sin(a), 0))
    m = Matrix.Translation((math.cos(a + rad(90)) * side, math.sin(a + rad(90)) * side, z))
    rot = fwd.to_track_quat("Z", "Y").to_matrix().to_4x4()
    # (a turn about the left-hand axis by -tilt lifts the muzzle)
    tilt_m = Matrix.Rotation(rad(-tilt), 4, Vector((-math.sin(a), math.cos(a), 0)))
    return m @ tilt_m @ rot


def barrel(name, frame, r, length, color, bands=3, rivets=True, fire=True):
    """a cannon barrel along its own +Z: a slightly tapering tube, a thick banded mouth, bands, a rivet row, the
    fire inside the mouth (a glowing disc)"""
    with K.atlas("barrel"):
        prof = [(r * 0.85, -length * 0.35), (r * 1.0, -length * 0.25), (r * 0.92, length * 0.45), (r * 0.95, length * 0.6)]
        # (open at the mouth: a closed cap hid the fire and read as the back of the barrel)
        # (round 2, 2026-11-24: smooth metal, no texture pattern: the brass pattern read as wicker on the barrels)
        o = K.lathe(name, prof, color, key=None, verts=24, tile=1.0, cap=False)
        o.matrix_world = frame
        mouth = K.lathe(name + "Mouth", [(r * 0.75, length * 0.6), (r * 1.18, length * 0.6), (r * 1.22, length * 0.82), (r * 1.08, length * 0.9), (r * 0.8, length * 0.88)],
                        IRON_DARK if color == IRON else K.BRASS, key=None, verts=24, cap=False)
        # the closed back end of the barrel
        back = K.lathe(name + "Breech", [(0.01, -length * 0.42), (r * 0.6, -length * 0.4), (r * 0.85, -length * 0.35)], color, key=None, verts=24, cap=False)
        back.matrix_world = frame
        mouth.matrix_world = frame
        for k in range(bands):   # a few broad gold bands
            zb = -length * 0.2 + k * length * 0.32
            b = K.lathe(f"{name}Band{k}", [(r * 1.02, zb), (r * 1.1, zb + 0.05), (r * 1.1, zb + 0.32), (r * 1.02, zb + 0.37)], K.BRASS, key=None, verts=24)
            b.matrix_world = frame
        if rivets:
            for k in range(10):
                ang = 2 * math.pi * k / 10
                rv = K.ball(f"{name}Rivet{k}", (math.cos(ang) * r * 1.12, math.sin(ang) * r * 1.12, -length * 0.02), 0.09, K.BRASS, seg=6)
                rv.matrix_world = frame @ rv.matrix_world
    if fire:
        import bmesh
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=True, segments=16, radius=r * 0.78)
        bmesh.ops.translate(bm, vec=(0, 0, length * 0.8), verts=bm.verts)
        mesh = bpy.data.meshes.new(name + "Fire")
        bm.to_mesh(mesh)
        bm.free()
        g = bpy.data.objects.new(name + "Fire", mesh)
        bpy.context.scene.collection.objects.link(g)
        g.matrix_world = frame
        S.glow(g, FIRE)
        # (round 2: a small flame glowing inside the bore, not a flat disc: a short cone just inside the mouth)
        tongue = K.cone(name + "Flame", (0, 0, length * 0.72), r * 0.6, length * 0.22, (1.0, 0.75, 0.2), verts=10)
        tongue.matrix_world = frame @ tongue.matrix_world
        S.glow(tongue, (1.0, 0.72, 0.2))


def footing():
    K.stone_ring("Foot", 0, P["foot_r"], P["foot_h"], P["foot_n"], depth=1.1)
    K.lathe("FootCore", [(P["foot_r"] - 0.9, 0), (P["foot_r"] - 0.9, P["foot_h"] - 0.02)], K.MORTAR)
    K.grass(P["foot_r"] - 0.05, 22, h=0.75)


def drum(z0, r, h, vents=False, bands=1, taper=1.0):
    """a round wooden drum of upright planks with brass bands and rivets; taper < 1 narrows it to the top (level 3's
    tall cone-shaped boiler, round 2)"""
    n = 16
    for i in range(n):
        a = rad(i * 360 / n)
        rm = r * (1 + taper) / 2
        lean = math.atan2(r - r * taper, h)
        K.block(f"Stave{z0:.1f}_{i}", K.at(a, rm - 0.15, z0 + h / 2), (2 * math.pi * rm / n * 1.04, 0.34, h / math.cos(lean)),
                K.WOOD if i % 2 else K.WOOD_DARK, (-lean, 0, a + rad(90)), key="wood", tile=1.2, bevel=0.08)
    K.lathe(f"DrumCore{z0:.1f}", [(r - 0.3, z0), (r * taper - 0.3, z0 + h)], K.WOOD_DARK, key="wood_dark")
    for k in range(bands):
        zb = z0 + h * (0.25 + 0.5 * k / max(1, bands - 1)) if bands > 1 else z0 + h * 0.55
        rb = r + (r * taper - r) * (zb - z0) / h
        K.brass_band(f"DrumBand{z0:.1f}_{k}", zb, rb + 0.02, 0.42, 14)
    if vents:   # glowing arched windows round the front (round 2: three tall arches, as painted)
        for s in (-1, 0, 1):
            a = rad(FRONT + s * 34)
            zc = z0 + h * 0.32
            rr = r + (r * taper - r) * 0.32 + 0.04
            p = Vector(K.at(a, rr, zc))
            t = Vector((-math.sin(a), math.cos(a), 0))
            for j in range(2):
                q = p + t * ((j - 0.5) * 0.36)
                K.ball(f"Arch{s}{j}", tuple(q + Vector((0, 0, 0.35))), 0.15, FIRE, (1, 0.6, 1), seg=8)
                bpy.ops.mesh.primitive_cube_add(size=1, location=q)
                g = bpy.context.active_object
                g.scale = (0.3, 0.16, 0.7)
                g.rotation_euler = (0, 0, a + rad(90))
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
                S.glow(g, FIRE)
            K.block(f"ArchFrame{s}", tuple(p + Vector((0, 0, 0.62))), (1.0, 0.25, 0.2), K.BRASS, (0, 0, a + rad(90)), key=None, tile=0.6)


fz = P["foot_h"]
footing()
if level == 1:
    # the wooden cradle: two side frames (legs and a cross timber) either side of the barrel, brass bolts
    a = rad(FRONT + P["aim"])
    side = Vector((-math.sin(a), math.cos(a), 0))
    fwd = Vector((math.cos(a), math.sin(a), 0))
    for s in (-1, 1):
        c = side * (s * P["cradle"] * 0.55)
        for f in (-1, 1):
            leg = c + fwd * (f * 0.9)
            K.block(f"Post{s}{f}", (leg.x, leg.y, fz + 0.95), (0.55, 0.55, 1.9), K.WOOD, (0, 0, a), key="wood", tile=1.2, bevel=0.1)
        K.block(f"Rail{s}", (c.x, c.y, fz + 1.55), (2.6, 0.5, 0.5), K.WOOD_DARK, (0, 0, a), key="wood_dark", tile=1.2, bevel=0.1)
        K.block(f"Brace{s}", (c.x, c.y, fz + 0.75), (2.4, 0.42, 0.42), K.WOOD, (0, rad(18) * s, a), key="wood", tile=1.2, bevel=0.08)
        bolt = c + side * (s * 0.3)
        K.ball(f"Bolt{s}", (bolt.x, bolt.y, fz + 1.55), 0.2, K.BRASS, (1, 1, 1), seg=10, key="brass", tile=0.6)
    K.block("Deck", (0, 0, fz + 0.15), (3.4, 3.4, 0.3), K.WOOD_DARK, (0, 0, a), key="wood_dark", tile=1.4)
    barrel("Barrel", aim_frame(P["barrel_z"], P["tilt"]), P["barrel_r"], P["barrel_len"], IRON)
    muzzle_frame = aim_frame(P["barrel_z"], P["tilt"])
    muzzles = [muzzle_frame @ Vector((0, 0, P["barrel_len"] * 0.85))]
elif level == 2:
    drum(fz, P["drum_r"], P["drum_h"], bands=1)
    top = fz + P["drum_h"]
    K.lathe("DrumLid", [(P["drum_r"] + 0.15, top - 0.1), (P["drum_r"] + 0.15, top + 0.15), (P["drum_r"] - 0.3, top + 0.2)], K.BRASS, key="brass", verts=32)
    a = rad(FRONT + P["aim"])
    side = Vector((-math.sin(a), math.cos(a), 0))
    for s in (-1, 1):
        c = side * (s * (P["barrel_r"] + 0.35))
        K.block(f"Arm{s}", (c.x, c.y, top + 0.85), (0.9, 0.35, 1.8), K.BRASS, (0, 0, a), key="brass", tile=0.6, bevel=0.1)
        hub = c + side * (s * 0.22)
        K.lathe(f"Hub{s}", [(0.0, -0.18), (0.55, -0.18), (0.6, 0.0), (0.55, 0.18), (0.0, 0.2)], K.BRASS, key="brass", verts=20).matrix_world = \
            Matrix.Translation((hub.x, hub.y, P["barrel_z"])) @ Matrix.Rotation(rad(90), 4, Vector((math.cos(a), math.sin(a), 0)))
    # the coal hopper behind: a brass-rimmed box of glowing coal
    back = Vector((-math.cos(a), -math.sin(a), 0)) * 1.4 + side * 0.9
    K.block("Hopper", (back.x, back.y, top + 1.4), (1.5, 1.3, 1.1), K.WOOD_DARK, (0, 0, a), key="wood_dark", tile=1.0, bevel=0.08)
    K.block("HopperRim", (back.x, back.y, top + 1.95), (1.7, 1.5, 0.18), K.BRASS, (0, 0, a), key="brass", tile=0.6)
    for k in range(6):
        c_ = K.ball(f"Coal{k}", (back.x + ((k % 3) - 1) * 0.42, back.y + (k // 3 - 0.5) * 0.45, top + 2.1), 0.26, COAL, (1, 1, 0.8), seg=7)
        if k % 2:
            S.glow(c_, FIRE)   # (glowing coals among the dark ones)
    barrel("Barrel", aim_frame(P["barrel_z"], P["tilt"]), P["barrel_r"], P["barrel_len"], BRONZE)
    muzzles = [aim_frame(P["barrel_z"], P["tilt"]) @ Vector((0, 0, P["barrel_len"] * 0.85))]
else:
    drum(fz, P["drum_r"], P["drum_h"], vents=True, bands=2, taper=0.72)
    top = fz + P["drum_h"]
    rt = P["drum_r"] * 0.72
    K.brass_band("Collar", top + 0.15, rt - 0.1, 0.55, 16)
    K.lathe("TurretBase", [(rt - 0.1, top + 0.4), (rt - 0.35, top + 1.4), (1.0, top + 1.6)], K.WOOD_DARK, key="wood_dark", verts=8)   # (an eight-sided housing)
    a = rad(FRONT + P["aim"])
    side = Vector((-math.sin(a), math.cos(a), 0))
    for s in (-1, 1):
        c = side * (s * 0.7)
        K.block(f"Cheek{s}", (c.x + side.x * s * 0.6, c.y + side.y * s * 0.6, top + 1.6), (1.1, 0.3, 1.2), K.BRASS, (0, 0, a), key="brass", tile=0.6, bevel=0.08)
    chim = Vector((-math.cos(a), -math.sin(a), 0)) * 1.2 - side * 0.8
    K.lathe("Chimney", [(0.32, top + 1.0), (0.32, top + 2.6), (0.42, top + 2.65), (0.42, top + 2.85), (0.28, top + 2.85)], IRON_DARK, key=None, verts=12).matrix_world = \
        Matrix.Translation((chim.x, chim.y, 0))
    with K.atlas("props"):   # the picture's puff of smoke over the chimney (part of its outline)
        for k, (dx, dz, r) in enumerate(((0.0, 3.2, 0.36), (0.25, 3.55, 0.32), (-0.05, 3.85, 0.3), (0.28, 4.1, 0.26))):
            K.ball(f"Smoke{k}", (chim.x + dx, chim.y, top + dz), r, (0.92, 0.9, 0.86), seg=10)
    muzzles = []
    for s in (-1, 1):
        fr = aim_frame(P["barrel_z"], P["tilt"], side=s * P["barrel_r"] * 1.3)   # (two barrels side by side with a gap, not one)
        barrel(f"Barrel{s}", fr, P["barrel_r"], P["barrel_len"], BRONZE, bands=2, rivets=False)
        muzzles.append(fr @ Vector((0, 0, P["barrel_len"] * 0.85)))

for m in muzzles:   # Blender (x, y, z) -> the game's (-x, z, y)
    print("MUZZLE Vector3.new(%.2f, %.2f, %.2f)" % (-m.x, m.z, m.y))
if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_flame_l{level}", out, budget=9000)
