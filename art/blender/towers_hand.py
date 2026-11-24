"""The five defenders, rebuilt by hand with the sculpt kit and the painted textures (Lemp 2026-11-19: "do it with
this workflow for the other pets and towers but put a lot of effort in it"). One tower per run. Sizes are in studs;
the front (where it shoots) faces -Y. Run: blender -b -P towers_hand.py -- out.fbx <kind>
kinds: ranger flame frost storm ballista"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sculpt as S  # noqa: E402
from sculpt import ball, cone, cyl, limb, chain, rad, glow_ball, box  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, kind = args[0], args[1]
S.start()
W = (1, 1, 1)


def tcone(name, pos, r, h, key, tint=W, top=None, verts=16, rot=(0, 0, 0), tile=2.0, scale=(1, 1, 1)):
    """A textured cylinder (top=None) or cone / tapered drum (top = the upper radius)."""
    if top is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=pos, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=top, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = min(0.08, r * 0.1)
    mod.segments = 2
    mod.limit_method = "ANGLE"
    mod.angle_limit = rad(50)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return S.textured(o, key, tint, tile)


def stone_base(r=2.9, h=0.9, tint=(0.82, 0.8, 0.78)):
    """The round stone footing every defender stands on, with a brass ring: one family."""
    tcone("Base", (0, 0, h / 2), r, h, "stone", tint, top=r * 0.94, verts=20, tile=2.4)
    tcone("BaseRing", (0, 0, h + 0.08), r * 0.9, 0.16, "brass", tile=1.2, verts=20)
    for i in range(6):  # a few loose stones and grass tufts around the foot, so it sits in the world
        a = rad(i * 60 + 20)
        if i % 2 == 0:
            ball(f"Pebble{i}", (math.cos(a) * (r + 0.15), math.sin(a) * (r + 0.15), 0.14), 0.24, (0.6, 0.6, 0.58), (1.2, 1, 0.7), seg=6)
        else:
            for k in range(3):
                cone(f"Grass{i}{k}", (math.cos(a) * (r + 0.1) + (k - 1) * 0.12, math.sin(a) * (r + 0.1), 0.22), 0.07, 0.5,
                     (0.36, 0.62, 0.22), (rad((k - 1) * 12), rad((k - 1) * 14), 0), verts=4)


def person(x, y, z, cloak, hood, skin=(0.98, 0.80, 0.64), s=1.0):
    """A little hooded figure (archer, engineer), about 2.3 studs tall at s=1."""
    ball("Legs", (x, y, z + 0.4 * s), 0.34 * s, (0.36, 0.24, 0.16), (1, 0.9, 1.3), seg=10)
    cone("Cloak", (x, y, z + 1.1 * s), 0.62 * s, 1.3 * s, cloak, top=0.3 * s, verts=12)
    ball("Head", (x, y - 0.04 * s, z + 1.95 * s), 0.36 * s, skin, seg=14)
    ball("Hood", (x, y + 0.08 * s, z + 2.02 * s), 0.42 * s, hood, (1.0, 1.0, 1.02), seg=14)
    cone("HoodTip", (x, y + 0.3 * s, z + 2.42 * s), 0.2 * s, 0.4 * s, hood, (rad(-40), 0, 0), verts=8)
    for e in (-1, 1):
        ball(f"Eye{e}", (x + e * 0.13 * s, y - 0.36 * s, z + 1.98 * s), 0.05 * s, S.BLACK, seg=6)


# ---------------------------------------------------------------------------------------------------------------
if kind == "ranger":
    stone_base()
    # the round stone tower: tapering wall, a band of darker stones, an arched door, two slit windows with shutters
    tcone("Tower", (0, 0, 3.4), 2.45, 5.2, "stone", top=2.05, verts=20, tile=2.6)
    tcone("Band", (0, 0, 2.2), 2.38, 0.3, "stone", (0.7, 0.68, 0.66), top=2.34, verts=20)
    tcone("Crown", (0, 0, 6.15), 2.1, 0.5, "stone", (0.76, 0.74, 0.72), top=2.7, verts=20)
    for i in range(10):
        a = rad(i * 36 + 18)
        box(f"Corbel{i}", (math.cos(a) * 2.42, math.sin(a) * 2.42, 5.9), (0.5, 0.5, 0.5), (0.8, 0.78, 0.76), rot=(0, 0, a), key="stone", tile=1.5)
    box("Door", (0, -2.34, 1.9), (1.3, 0.3, 2.1), W, rot=(rad(-4), 0, 0), bevel=0.1, key="wood_dark", tile=1.6)
    tcone("DoorArch", (0, -2.3, 2.95), 0.65, 0.3, "wood_dark", verts=14, rot=(rad(90), 0, 0))
    tcone("DoorFrame", (0, -2.24, 2.95), 0.86, 0.3, "stone", (0.66, 0.64, 0.62), verts=14, rot=(rad(90), 0, 0))
    for k in (-0.4, 0.4):
        box(f"Hinge{k}", (0, -2.52, 1.9 + k * 1.6), (1.2, 0.06, 0.14), W, key="iron", bevel=0.02)
    ball("Knob", (0.4, -2.56, 1.9), 0.09, (1.0, 0.76, 0.2), seg=8)
    for i, a in enumerate((70, 200, 320)):
        ar = rad(a)
        x, y = math.cos(ar) * 2.2, math.sin(ar) * 2.2
        box(f"Slit{i}", (x, y, 4.2), (0.32, 0.5, 1.0), (0.1, 0.08, 0.08), rot=(0, 0, ar), bevel=0.04)
        box(f"Sill{i}", (x * 1.04, y * 1.04, 3.62), (0.5, 0.7, 0.14), (0.7, 0.68, 0.66), rot=(0, 0, ar), key="stone", tile=1.0)
    # ivy creeping up one side
    for i in range(9):
        a = rad(125 + i * 5)
        rr = 2.42 - i * 0.045
        ball(f"Ivy{i}", (math.cos(a) * rr, math.sin(a) * rr, 1.2 + i * 0.5), 0.3 - i * 0.015, (0.24, 0.5, 0.2) if i % 2 else (0.34, 0.62, 0.26), (1, 0.5, 1.1), seg=6)
    # the wooden lookout: floor, posts, railing with a gap at the front, a hanging lantern
    tcone("Floor", (0, 0, 6.6), 3.0, 0.36, "wood", verts=20, tile=2.2)
    tcone("FloorRim", (0, 0, 6.42), 3.06, 0.14, "brass", verts=20, tile=1.4)
    for i in range(8):
        a = rad(i * 45 + 90)
        x, y = math.cos(a) * 2.72, math.sin(a) * 2.72
        box(f"Post{i}", (x, y, 8.3), (0.3, 0.3, 3.2), W, rot=(0, 0, a), bevel=0.05, key="wood_dark", tile=2.0)
        b = rad(i * 45 + 112.5)
        if abs(i * 45 + 112.5 - 270) > 30:  # open at the front (270 degrees = -Y)
            ln = 2 * 2.72 * math.sin(rad(22.5))
            box(f"Rail{i}", (math.cos(b) * 2.6, math.sin(b) * 2.6, 7.7), (ln, 0.16, 0.18), W, rot=(0, 0, b + rad(90)), bevel=0.04, key="wood", tile=2.0)
            box(f"Panel{i}", (math.cos(b) * 2.63, math.sin(b) * 2.63, 7.2), (ln - 0.2, 0.1, 0.8), (0.9, 0.86, 0.82), rot=(0, 0, b + rad(90)), bevel=0.03, key="wood", tile=1.6)
    limb("LanternArm", (2.72, 0, 9.6), (3.5, 0, 9.5), 0.06, 0.05, (0.2, 0.2, 0.22), verts=6)
    box("Lantern", (3.5, 0, 9.05), (0.36, 0.36, 0.5), W, key="iron", bevel=0.04)
    glow_ball("LanternGlow", (3.5, 0, 9.05), 0.2, (1.0, 0.8, 0.35), seg=8)
    # the roof: a tall shingled cone with a wide eave, a brass finial and a pennant
    tcone("Eave", (0, 0, 10.0), 3.85, 0.26, "wood_dark", top=3.6, verts=20)
    tcone("Roof", (0, 0, 11.9), 3.7, 3.8, "roof", top=0.12, verts=20, tile=1.9)
    ball("Finial", (0, 0, 13.95), 0.3, (1.0, 0.76, 0.2), seg=10)
    limb("Pole", (0, 0, 14.0), (0, 0, 15.6), 0.06, 0.05, (0.3, 0.2, 0.14), verts=6)
    S.membrane("Pennant", [(0, 0, 15.5), (1.5, 0.1, 15.25), (0, 0, 14.9), (0.7, 0.05, 15.2)], [(0, 1, 3), (3, 1, 2), (0, 3, 2)], (0.36, 0.72, 0.3), 0.04)
    # the archer at the front gap, bow drawn; a quiver and a barrel of arrows beside them
    person(0, -1.4, 6.78, (0.34, 0.62, 0.3), (0.26, 0.5, 0.24))
    chain("Bow", [(0.5, -2.0, 7.4), (0.62, -2.15, 7.95), (0.62, -2.15, 8.55), (0.5, -2.0, 9.1)], [0.05, 0.06, 0.06, 0.05], (0.36, 0.22, 0.12), seg=6)
    limb("Arrow", (0.5, -1.3, 8.25), (0.5, -2.7, 8.25), 0.025, 0.025, (0.92, 0.88, 0.74), verts=4, end=False)
    cone("ArrowHead", (0.5, -2.8, 8.25), 0.07, 0.22, (0.75, 0.76, 0.8), (rad(90), 0, 0), verts=4)
    tcone("Barrel", (-1.6, 1.3, 7.3), 0.5, 1.0, "wood", verts=12, tile=1.4)
    for k in range(4):
        limb(f"Spare{k}", (-1.6 + (k - 1.5) * 0.14, 1.3, 7.7), (-1.6 + (k - 1.5) * 0.2, 1.36, 8.6), 0.02, 0.02, (0.92, 0.88, 0.74), verts=4, end=False)
    # cream banners with a green stripe hanging under the lookout
    for i, a in enumerate((30, 150)):
        ar = rad(a)
        box(f"Banner{i}", (math.cos(ar) * 2.78, math.sin(ar) * 2.78, 5.3), (1.2, 0.06, 1.8), (0.95, 0.9, 0.78), rot=(0, 0, ar + rad(90)), bevel=0.02, key="cloth", tile=1.5)
        box(f"Stripe{i}", (math.cos(ar) * 2.82, math.sin(ar) * 2.82, 5.3), (0.4, 0.06, 1.8), (0.36, 0.7, 0.3), rot=(0, 0, ar + rad(90)), bevel=0.02)
    S.finish("tower_ranger", out, triangles=6500)

elif kind == "flame":
    stone_base(2.95, 1.0)
    tcone("Deck", (0, 0, 1.3), 2.5, 0.5, "stone", top=2.4, verts=20, tile=2.2)
    # the carriage: two wooden cheeks with brass caps, an axle, big spoked wheels with iron tyres
    for s in (-1, 1):
        box(f"Cheek{s}", (s * 1.05, 0.15, 2.5), (0.5, 3.0, 1.9), W, bevel=0.12, key="wood", tile=1.8)
        box(f"CheekCap{s}", (s * 1.05, 0.15, 3.48), (0.58, 3.1, 0.16), W, bevel=0.04, key="brass", tile=1.0)
        tcone(f"Wheel{s}", (s * 1.5, 0.7, 2.1), 1.0, 0.3, "wood_dark", verts=18, rot=(0, rad(90), 0), tile=1.4)
        tcone(f"Tyre{s}", (s * 1.52, 0.7, 2.1), 1.06, 0.2, "iron", verts=18, rot=(0, rad(90), 0), tile=1.2)
        tcone(f"Hub{s}", (s * 1.6, 0.7, 2.1), 0.28, 0.4, "brass", verts=10, rot=(0, rad(90), 0), tile=0.8)
        for k in range(6):
            a = rad(k * 60)
            limb(f"Spoke{s}{k}", (s * 1.66, 0.7, 2.1), (s * 1.66, 0.7 + math.cos(a) * 0.9, 2.1 + math.sin(a) * 0.9), 0.06, 0.05, (0.5, 0.34, 0.2), verts=5, end=False)
    tcone("Axle", (0, 0.7, 2.1), 0.16, 3.3, "iron", verts=10, rot=(0, rad(90), 0), tile=1.0)
    # the barrel: fat at the breech, flaring at the muzzle, three brass bands, a dragon-mouth muzzle with teeth
    tilt = rad(68)
    axis = (0, -math.sin(tilt), math.cos(tilt))

    def along(t, lift=0.0):
        return (0, -0.5 + axis[1] * t, 3.5 + axis[2] * t + lift)

    tcone("Barrel", along(0), 0.95, 4.4, "iron", top=0.78, verts=20, rot=(tilt + rad(180), 0, 0), tile=1.8)
    ball("Breech", along(-2.2), 1.0, (0.3, 0.31, 0.36), seg=16)
    ball("Cascabel", along(-3.3), 0.3, (1.0, 0.76, 0.2), seg=10)
    for i, t in enumerate((-1.4, 0.1, 1.5)):
        tcone(f"Band{i}", along(t), 0.98 - i * 0.05, 0.3, "brass", verts=20, rot=(tilt, 0, 0), tile=1.0)
    tcone("Muzzle", along(2.35), 0.8, 0.6, "brass", top=1.12, verts=20, rot=(tilt + rad(180), 0, 0), tile=1.0)
    for k in range(8):  # teeth round the muzzle, pointing forward
        a = rad(k * 45)
        m = along(2.78)
        u, v = math.cos(a) * 0.95, math.sin(a) * 0.95
        cone(f"Tooth{k}", (u, m[1] + v * math.cos(tilt), m[2] + v * math.sin(tilt)), 0.13, 0.4, (0.98, 0.94, 0.84), (tilt, 0, 0), verts=5)
    m = along(2.6)
    glow_ball("Fire", m, 0.74, (1.0, 0.5, 0.12), (1, 0.5, 1), rot=(tilt - rad(90), 0, 0), seg=12)
    # a touch-hole fuse glowing on top, cannonballs stacked in a pyramid, a powder keg and a ramrod
    glow_ball("Fuse", along(-1.9, 0.95), 0.12, (1.0, 0.8, 0.3), seg=6)
    for i, (x, y, z) in enumerate(((1.9, -1.2, 2.0), (2.25, -0.75, 2.0), (1.75, -0.65, 2.0), (1.97, -0.87, 2.42))):
        ball(f"Shot{i}", (x, y, z), 0.32, (0.2, 0.2, 0.24), seg=10)
    tcone("Keg", (-1.95, -0.9, 2.15), 0.5, 1.1, "wood", verts=12, tile=1.3)
    for z in (1.8, 2.5):
        tcone(f"KegHoop{z}", (-1.95, -0.9, z), 0.52, 0.1, "iron", verts=12, tile=1.0)
    limb("Ramrod", (-2.1, 0.6, 1.6), (-1.5, 1.9, 3.6), 0.07, 0.07, (0.5, 0.34, 0.2), verts=6)
    ball("RamHead", (-1.5, 1.9, 3.6), 0.22, (0.9, 0.86, 0.74), seg=8)
    S.finish("tower_flame", out, triangles=6000)

elif kind == "frost":
    ICE, ICE_L, ICE_D, SNOW = (0.55, 0.82, 1.0), (0.84, 0.95, 1.0), (0.32, 0.62, 0.95), (0.95, 0.98, 1.0)
    stone_base(2.95, 0.9, (0.78, 0.82, 0.9))
    # a carved rune pedestal dusted with snow, icicles hanging from its rim
    tcone("Pedestal", (0, 0, 1.45), 2.2, 1.1, "rune_stone", (0.9, 0.95, 1.1), top=1.9, verts=8, tile=2.0)
    tcone("PedestalRim", (0, 0, 2.05), 2.1, 0.24, "stone", (0.82, 0.88, 1.0), verts=8)
    for i in range(8):
        a = rad(i * 45 + 22.5)
        ball(f"Snow{i}", (math.cos(a) * 1.6, math.sin(a) * 1.6, 2.2), 0.5, SNOW, (1.2, 1.2, 0.36), seg=8)
        cone(f"Icicle{i}", (math.cos(a) * 2.02, math.sin(a) * 2.02, 1.72), 0.1, 0.5 + (i % 3) * 0.14, ICE_L, (rad(180), 0, 0), verts=5)
        glow_ball(f"Rune{i}", (math.cos(a + rad(22.5)) * 2.08, math.sin(a + rad(22.5)) * 2.08, 1.45), 0.11, (0.5, 0.9, 1.0), (1, 1, 1.6), seg=6)

    def crystal(name, x, y, z, r, h, tilt_x=0.0, tilt_y=0.0, color=ICE, glow=False):
        """A six-sided crystal with a pointed top and a short pointed foot."""
        rot = (tilt_x, tilt_y, 0)
        parts = [cone(name, (x, y, z + h / 2), r, h, color, rot, top=r * 0.86, verts=6),
                 cone(name + "Tip", (x + math.sin(tilt_y) * (h / 2 + r * 0.9), y - math.sin(tilt_x) * (h / 2 + r * 0.9), z + h + r * 0.75), r * 0.86, r * 1.9, color, rot, verts=6)]
        for o in parts:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.shade_flat()
            if glow:
                S.paint.glow(o, color)
            else:
                S.paint.paint(o, "ice", (color[0] * 1.5, color[1] * 1.15, color[2]), 2.2)

    crystal("Main", 0, 0, 2.1, 1.05, 4.4)
    crystal("Core", 0.0, -0.98, 2.6, 0.24, 3.0, glow=True, color=(0.6, 0.95, 1.0))
    for i in range(7):
        a = rad(i * 51.4 + 12)
        h = 1.5 + (i * 37 % 5) * 0.42
        crystal(f"Side{i}", math.cos(a) * 1.25, math.sin(a) * 1.25, 2.1, 0.42 + (i % 2) * 0.1, h, -math.sin(a) * 0.38, math.cos(a) * 0.38,
                ICE_D if i % 3 == 0 else ICE_L if i % 3 == 1 else ICE)
    # shards floating around the tip, and a frozen ring of mist at the foot
    for i in range(5):
        a = rad(i * 72)
        o = cone(f"Float{i}", (math.cos(a) * 1.9, math.sin(a) * 1.9, 6.4 + (i % 2) * 0.5), 0.16, 0.6, ICE_L, (rad(180 * (i % 2)), rad(20), a), verts=4)
        S.paint.glow(o, (0.75, 0.95, 1.0))
    S.finish("tower_frost", out, triangles=4500)

elif kind == "storm":
    ORB, RUNE = (0.72, 0.45, 1.0), (0.78, 0.6, 1.0)
    stone_base(2.95, 0.9, (0.78, 0.76, 0.84))
    tcone("Plinth", (0, 0, 1.4), 2.1, 1.0, "rune_stone", top=1.7, verts=4, rot=(0, 0, rad(45)), tile=2.0)
    # the obelisk: a tall four-sided rune stone, brass bands, glowing rune strips on every face
    tcone("Obelisk", (0, 0, 5.9), 1.42, 8.0, "rune_stone", (1.1, 1.05, 1.2), top=0.78, verts=4, rot=(0, 0, rad(45)), tile=2.6)
    for z, r in ((2.6, 1.42), (5.4, 1.2), (8.6, 0.93)):
        tcone(f"Band{z}", (0, 0, z), r + 0.1, 0.34, "brass", top=r + 0.06, verts=4, rot=(0, 0, rad(45)), tile=1.0)
    for i in range(4):
        a = rad(i * 90)
        x, y = math.cos(a), math.sin(a)
        for k, (z, ln) in enumerate(((3.9, 1.7), (7.0, 1.6))):
            d = 0.94 - (z - 2) * 0.047
            o = box(f"Rune{i}{k}", (x * d, y * d, z), (0.16, 0.1, ln), RUNE, rot=(-y * 0.08, x * 0.08, a + rad(90)), bevel=0.02)
            S.paint.glow(o, RUNE)
        # a brass lightning rod leaning out at each corner of the plinth
        ca = rad(i * 90 + 45)
        limb(f"Rod{i}", (math.cos(ca) * 1.6, math.sin(ca) * 1.6, 1.9), (math.cos(ca) * 2.3, math.sin(ca) * 2.3, 4.0), 0.07, 0.04, (1.0, 0.76, 0.2), verts=6)
        glow_ball(f"RodTip{i}", (math.cos(ca) * 2.3, math.sin(ca) * 2.3, 4.05), 0.13, ORB, seg=8)
    # the cap, four claws and the storm orb, with two tilted brass rings turning round it
    tcone("Cap", (0, 0, 10.2), 1.0, 0.8, "brass", top=0.45, verts=4, rot=(0, 0, rad(45)), tile=1.0)
    for i in range(4):
        a = rad(i * 90 + 45)
        chain(f"Claw{i}", [(math.cos(a) * 0.55, math.sin(a) * 0.55, 10.5), (math.cos(a) * 1.05, math.sin(a) * 1.05, 11.2),
                           (math.cos(a) * 0.8, math.sin(a) * 0.8, 12.0)], [0.14, 0.11, 0.05], (1.0, 0.76, 0.2), seg=6)
    glow_ball("Orb", (0, 0, 11.75), 0.95, ORB, seg=16)
    for i, (rx, ry) in enumerate(((rad(64), 0), (rad(-58), rad(30)))):
        bpy.ops.mesh.primitive_torus_add(major_radius=1.42, minor_radius=0.06, major_segments=24, minor_segments=6, location=(0, 0, 11.75), rotation=(rx, ry, 0))
        S.textured(bpy.context.active_object, "brass", W, 1.0)
    for i, (x, y, z) in enumerate(((1.5, 0.4, 12.4), (-1.3, -0.8, 11.2), (0.3, -1.5, 12.7))):
        glow_ball(f"Spark{i}", (x, y, z), 0.1, (0.9, 0.8, 1.0), seg=6)
    S.finish("tower_storm", out, triangles=4500)

elif kind == "ballista":
    ROPE = (0.86, 0.76, 0.56)
    stone_base(2.95, 0.9)
    tcone("Turntable", (0, 0, 1.25), 2.3, 0.5, "wood_dark", verts=18, tile=2.0)
    tcone("TurnRing", (0, 0, 1.52), 2.0, 0.1, "iron", verts=18, tile=1.4)
    # the stand: an A-frame on each side, cross-braced, with an iron axle
    for s in (-1, 1):
        for k in (-1, 1):
            limb(f"Leg{s}{k}", (s * 1.0, k * 0.9, 1.5), (s * 0.85, 0, 4.0), 0.2, 0.16, (0.62, 0.42, 0.24), verts=8, end=False)
        box(f"Brace{s}", (s * 0.93, 0, 2.5), (0.16, 1.5, 0.2), W, bevel=0.04, key="wood_dark", tile=1.2)
    tcone("Axle", (0, 0, 4.0), 0.2, 2.4, "iron", verts=10, rot=(0, rad(90), 0), tile=1.0)
    # the stock, tipped up a little, with brass bands, a trigger box and a winch at the back
    tilt = rad(-7)
    box("Stock", (0, -0.4, 4.42), (0.95, 6.6, 0.6), W, rot=(tilt, 0, 0), bevel=0.1, key="wood", tile=2.0)
    box("Groove", (0, -0.9, 4.74), (0.3, 5.2, 0.06), (0.3, 0.2, 0.14), rot=(tilt, 0, 0), bevel=0.02)
    for i, y in enumerate((-3.4, -1.2, 1.2, 2.6)):
        box(f"StockBand{i}", (0, y, 4.42 - y * math.sin(tilt)), (1.06, 0.3, 0.7), W, rot=(tilt, 0, 0), bevel=0.04, key="brass", tile=1.0)
    box("Trigger", (0, 1.9, 4.0), (0.5, 0.9, 0.5), W, rot=(tilt, 0, 0), bevel=0.06, key="iron", tile=1.0)
    tcone("Winch", (0, 2.9, 4.5), 0.34, 1.5, "wood_dark", verts=10, rot=(0, rad(90), 0), tile=1.0)
    for s in (-1, 1):
        for k in range(4):
            a = rad(k * 90 + 30)
            limb(f"Handle{s}{k}", (s * 0.86, 2.9, 4.5), (s * 0.86, 2.9 + math.cos(a) * 0.6, 4.5 + math.sin(a) * 0.6), 0.06, 0.05, (0.36, 0.22, 0.12), verts=5)
    # the bow: two thick swept-back arms with iron tips, and the taut string drawn to the bolt's tail
    for s in (-1, 1):
        chain(f"Arm{s}", [(s * 0.3, -2.9, 4.9), (s * 1.5, -2.75, 4.9), (s * 2.7, -2.3, 4.9), (s * 3.5, -1.6, 4.9)], [0.26, 0.24, 0.19, 0.13], (0.36, 0.22, 0.12), seg=8)
        tcone(f"ArmTip{s}", (s * 3.56, -1.52, 4.9), 0.2, 0.36, "iron", verts=8, rot=(0, rad(90), rad(s * 40)), tile=0.8)
        limb(f"String{s}", (s * 3.5, -1.55, 4.9), (0, 1.3, 4.86), 0.035, 0.035, ROPE, verts=4, end=False)
        tcone(f"Skein{s}", (s * 0.42, -2.9, 4.9), 0.28, 0.9, "cloth", (0.86, 0.76, 0.56), verts=10, tile=0.6)
        # shield plates that cover the crew
        box(f"Shield{s}", (s * 1.75, -2.0, 3.3), (1.7, 0.16, 2.2), W, rot=(0, 0, rad(s * -14)), bevel=0.08, key="iron", tile=1.6)
        ball(f"ShieldBoss{s}", (s * 1.75, -2.12, 3.4), 0.24, (1.0, 0.76, 0.2), seg=8)
        limb(f"ShieldArm{s}", (s * 0.9, -0.3, 3.2), (s * 1.6, -1.9, 3.2), 0.08, 0.08, (0.36, 0.22, 0.12), verts=5, end=False)
    # the loaded bolt: a heavy shaft, an iron head and three fletchings
    limb("Bolt", (0, 1.3, 4.9), (0, -4.0, 5.55), 0.09, 0.09, (0.36, 0.22, 0.12), verts=8, end=False)
    cone("BoltHead", (0, -4.5, 5.61), 0.26, 1.0, (0.78, 0.8, 0.86), (rad(90) + tilt, 0, 0), verts=4)
    for k in range(3):  # three small fins at the tail
        a = rad(k * 120 + 90)
        cone(f"Fletch{k}", (math.cos(a) * 0.14, 1.0, 4.94 + math.sin(a) * 0.14), 0.16, 0.6, (0.95, 0.9, 0.78), (rad(90) + tilt, 0, 0), verts=3, scale=(0.25, 1, 1))
    # spare bolts in a rack on the side
    box("Rack", (2.0, 1.2, 1.9), (0.6, 0.9, 0.9), W, bevel=0.05, key="wood", tile=1.2)
    for k in range(3):
        limb(f"Spare{k}", (1.85 + k * 0.15, 1.2, 2.0), (1.85 + k * 0.15, 1.2 + (k - 1) * 0.08, 3.9), 0.06, 0.06, (0.36, 0.22, 0.12), verts=5, end=False)
        cone(f"SpareHead{k}", (1.85 + k * 0.15, 1.2 + (k - 1) * 0.08, 4.1), 0.14, 0.45, (0.78, 0.8, 0.86), verts=4)
    S.finish("tower_ballista", out, triangles=6000)

else:
    raise SystemExit("unknown tower kind: " + kind)
