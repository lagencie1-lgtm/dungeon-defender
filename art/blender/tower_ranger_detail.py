"""The Ranger at its three levels, built with the tower kit (art/blender/tower_kit.py) to match the Codex pictures
art/ref3d/tower_ranger_l1..l3.png (docs/tower-pipeline.md). Sizes are measured off the pictures (studs; heights 10.4 /
15.65 / 19.45 like the game's LEVEL_LOOKS). P holds every size the shape loop (scripts/tower_fit.py) may tune; its
results live in art/blender/params/tower_ranger_l<level>.json and are read automatically.

Run: blender -b -P tower_ranger_detail.py -- out.fbx <1|2|3> [params.json]
     HTD_FAST=1: outline only (no bake), HTD_PARAMS_ONLY=1: print the sizes and stop."""
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import sculpt as S  # noqa: E402
import tower_kit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, level = args[0], int(args[1])
FRONT = -75  # the door looks at the picture's camera (art/blender/render_match.py az -75); a round tower has no wrong side
rad = math.radians

DEFAULTS = {
    1: dict(foot_r=2.95, foot_h=0.9, leg_half=1.75, leg=0.7, box_z0=3.65, box_h=1.75, box_half=2.2, eave=7.3,
            ridge=9.75, roof_len=5.5, roof_span=5.9, archer_s=1.25, view_turn=-35, foot_n=9),
    2: dict(foot_r=3.95, foot_h=0.9, wall_r0=3.45, wall_r1=2.95, wall_top=6.0, rows=5, per_row=11, foot_n=9,
            door_w=1.6, door_h=2.2, look_r=3.05, look_h=1.85, bays=8, post_r=2.55, post_top=9.85,
            roof_z0=10.1, roof_z1=13.6, roof_r=3.85, tiers=4, per_tier=16, bell=1.15,
            banner_ang=-55, banner_w=1.45, banner_h=1.75, flag_len=3.3, flag_h=1.0,
            archer_s=1.3, archer_x=0.25, archer_y=0.0),
    3: dict(foot_r=5.0, foot_h=1.0, wall_r0=4.65, wall_r1=3.9, band_z=6.5, wall2_r=3.55, wall_top=9.9, rows=4, rows2=3, foot_n=11,
            per_row=13, door_w=2.1, door_h=2.8, look_r=4.35, look_h=1.95, bays=10, post_r=3.9, post_top=14.0,
            roof_z0=14.1, roof_z1=17.2, roof_r=4.85, tiers=4, per_tier=18, bell=1.1, archer_s=1.35),
}

P = dict(DEFAULTS[level])
saved = os.path.join(HERE, "params", f"tower_ranger_l{level}.json")
src = args[2] if len(args) > 2 and os.path.exists(args[2]) else saved
if os.path.exists(src):
    P.update(json.load(open(src)))
if os.environ.get("HTD_PARAMS_ONLY"):
    print("PARAMS " + json.dumps(P), flush=True)
    os._exit(0)
S.start()


def turn_all(deg):
    """the square level is built facing -Y, then turned so its front looks at FRONT"""
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.matrix_world = __import__("mathutils").Matrix.Rotation(rad(deg), 4, "Z") @ o.matrix_world


if level == 1:
    # a wooden watch post on a stone ring: four braced legs, a plank box with brass corners, posts, a shingled gable
    # roof with brass caps, a ladder at the front right; built facing -Y, then turned
    K.stone_ring("Foot", 0, P["foot_r"], P["foot_h"], P["foot_n"], depth=1.0)
    K.lathe("FootCore", [(P["foot_r"] - 0.6, 0), (P["foot_r"] - 0.6, P["foot_h"] - 0.05)], K.MORTAR, key="stone")
    L, B = P["leg_half"], P["box_half"]
    z0, z1 = P["foot_h"], P["box_z0"]
    for x in (-L, L):
        for y in (-L, L):
            K.block(f"Leg{x}{y}", (x, y, (z0 + z1) / 2), (P["leg"], P["leg"], z1 - z0), K.WOOD_DARK, key="wood_dark", tile=1.4)
            K.corner_plate(f"Foot{x}{y}", (x + math.copysign(P["leg"] / 2, x), y + math.copysign(P["leg"] / 2, y), z0 + 0.4),
                           math.atan2(y, x) - rad(45), 0.55)
    for side in range(4):
        a = rad(side * 90)
        ca, sa = round(math.cos(a)), round(math.sin(a))
        for s in (-1, 1):   # X braces between the legs
            p0 = (ca * L + (-sa) * L * s, sa * L + ca * L * s, z0 + 0.3)
            p1 = (ca * L - (-sa) * L * s, sa * L - ca * L * s, z1 - 0.2)
            K.limb(f"XBrace{side}{s}", p0, p1, 0.2, 0.2, K.WOOD, verts=4, end=False)
        K.block(f"Tie{side}", (ca * L, sa * L, z0 + 0.35), (0.3 if ca else 2 * L, 2 * L if ca else 0.3, 0.3), K.WOOD_DARK, key="wood_dark", tile=1.2)
    K.block("Floor", (0, 0, z1 - 0.1), (2 * B + 0.2, 2 * B + 0.2, 0.3), K.WOOD, key="wood", tile=1.4)
    corners = [(-B, -B), (B, -B), (B, B), (-B, B)]
    for k in range(4):
        K.plank_wall(f"BoxWall{k}", corners[k] + (0,), corners[(k + 1) % 4] + (0,), z1, z1 + P["box_h"], boards=2, thick=0.28)
    for x, y in corners:
        K.block(f"BoxPost{x}{y}", (x, y, z1 + P["box_h"] / 2), (0.42, 0.42, P["box_h"] + 0.25), K.WOOD_DARK, key="wood_dark", tile=1.0)
        K.corner_plate(f"Box{x}{y}", (x + math.copysign(0.21, x), y + math.copysign(0.21, y), z1 + P["box_h"] * 0.55),
                       math.atan2(y, x) - rad(45), 0.75)
        K.block(f"RoofPost{x}{y}", (x * 0.85, y * 0.85, (z1 + P["box_h"] + P["eave"]) / 2), (0.6, 0.6, P["eave"] - z1 - P["box_h"] + 0.2),
                K.WOOD_DARK, key="wood_dark", tile=1.2)
    for k in range(4):   # lintels under the eave: the picture's openings are framed, not open to the roof
        a = rad(k * 90)
        ca, sa = round(math.cos(a)), round(math.sin(a))
        K.block(f"Lintel{k}", (ca * B * 0.85, sa * B * 0.85, P["eave"] - 0.35), (0.4 if ca else 2 * B * 0.85 + 0.6, 2 * B * 0.85 + 0.6 if ca else 0.4, 0.55),
                K.WOOD_DARK, key="wood_dark", tile=1.2)
    for k in range(4):   # a mid tie round the legs (the picture's legs are a heavy braced frame)
        a = rad(k * 90)
        ca, sa = round(math.cos(a)), round(math.sin(a))
        K.block(f"MidTie{k}", (ca * L, sa * L, (z0 + z1) / 2 + 0.3), (0.32 if ca else 2 * L, 2 * L if ca else 0.32, 0.35), K.WOOD, key="wood", tile=1.2)
    K.block("TopRail", (0, 0, z1 + P["box_h"] + 0.1), (2 * B + 0.3, 2 * B + 0.3, 0.12), K.WOOD, key="wood", tile=1.2)
    before = set(bpy.context.scene.objects)
    K.gable_roof("Roof", P["roof_len"], P["roof_span"], P["eave"], P["ridge"], rows=4, cols=6)
    for o in set(bpy.context.scene.objects) - before:   # the ridge runs front to back: a gable end looks at the front
        o.matrix_world = __import__("mathutils").Matrix.Rotation(rad(90), 4, "Z") @ o.matrix_world
    K.ladder("Ladder", (B + 1.15, -B + 1.2, z0), (B + 0.15, -B + 1.2, z1 + P["box_h"] + 0.1), width=1.0, rungs=5,
             across=(0, 1, 0))   # on the side the picture shows on the right, near the front, leaning out
    K.grass(P["foot_r"] - 0.1, 30, h=0.8)
    K.pebbles(P["foot_r"] + 0.25, 8)
    K.archer(-0.2, -B + 0.9, z1 + 0.1, 1.75, face=-90 + 35)   # big in the window, like the picture
    # the picture sees the post from its front right (the front gable shows on the left, the box's right side shows)
    turn_all(FRONT + 90 + P["view_turn"])
elif level == 2:
    # a round warm-stone tower with ivy, an arched door and a banner, a timber lookout with brass corners, a shingled
    # bell roof with a brass finial and a green pennant
    r_of = lambda z: P["wall_r0"] + (P["wall_r1"] - P["wall_r0"]) * (z - P["foot_h"]) / (P["wall_top"] - P["foot_h"])  # noqa: E731
    K.stone_ring("Foot", 0, P["foot_r"], P["foot_h"], P["foot_n"], depth=max(0.8, P["foot_r"] - P["wall_r0"] + 0.35), skip=[(FRONT, 22)])
    K.lathe("FootCore", [(P["foot_r"] - 0.5, 0), (P["foot_r"] - 0.5, P["foot_h"]), (P["wall_r0"] - 0.1, P["foot_h"] + 0.01)], K.MORTAR, key="stone")
    K.stone_wall("Wall", P["foot_h"], P["wall_top"], P["wall_r0"], P["wall_r1"], P["rows"], P["per_row"],
                 gaps=[(FRONT, 22, P["foot_h"] + P["door_h"] + 0.5)])
    K.arched_door(FRONT, r_of(P["foot_h"] + 1), P["foot_h"] + 0.05, P["door_w"], P["door_h"], steps=2)
    K.balcony(P["wall_top"], P["look_r"], P["look_h"], P["bays"], FRONT + 22.5)
    K.roof_posts(P["wall_top"] + P["look_h"], P["post_top"], P["post_r"], 6, FRONT)
    K.lathe("LookInside", [(P["look_r"] - 0.3, P["wall_top"] + 0.3), (P["look_r"] - 0.3, P["wall_top"] + 0.32)], K.WOOD_DARK, key="wood")
    K.shingle_roof("Roof", P["roof_z0"], P["roof_z1"], P["roof_r"], P["tiers"], P["per_tier"], P["bell"])
    top = K.finial(P["roof_z1"] - 0.15, cup=0.6, pole=1.0, knob=0.32)
    K.wavy_flag(top + 0.2, P["flag_len"], P["flag_h"])
    K.banner(P["banner_ang"], P["wall_r1"] + 0.05, P["wall_top"] - 0.25, P["banner_w"], P["banner_h"],
             field=K.GREEN, trim=K.CREAM, mark=K.CREAM)   # the level 2 picture's banner: green with cream
    K.ivy("IvyL", r_of, FRONT - 62, P["foot_h"] + 0.9, P["wall_top"] + 0.2, leaves=12, sway=9)
    K.ivy("IvyR", r_of, FRONT + 66, P["foot_h"] + 0.5, P["wall_top"] - 1.0, leaves=12, sway=10)
    K.grass(P["foot_r"] + 0.05, 34, h=0.8, skip=[(FRONT, 25)])
    K.pebbles(P["foot_r"] + 0.2, 7, skip=[(FRONT, 30)])
    K.archer((P["look_r"] - 1.0) * math.cos(rad(FRONT + 4)), (P["look_r"] - 1.0) * math.sin(rad(FRONT + 4)), P["wall_top"] + 0.3, 1.85, face=FRONT + 35)
else:
    # the keep: two stone storeys parted by a riveted brass band, arched windows, two side banners, a wide lookout with
    # a banner and green swags, two archers, a shingled roof with brass ribs, a brass crown and the glowing gem
    f0, z1, zb, z2 = P["foot_h"], P["band_z"], P["band_z"], P["wall_top"]
    r_low = lambda z: P["wall_r0"] + (P["wall_r1"] - P["wall_r0"]) * (z - f0) / (zb - f0)  # noqa: E731
    r_up = lambda z: P["wall_r1"] * 0.97 + (P["wall2_r"] - P["wall_r1"] * 0.97) * (z - zb) / (z2 - zb)  # noqa: E731
    K.stone_ring("Foot", 0, P["foot_r"], f0, P["foot_n"], depth=max(0.9, P["foot_r"] - P["wall_r0"] + 0.35), skip=[(FRONT, 18)])
    K.lathe("FootCore", [(P["foot_r"] - 0.6, 0), (P["foot_r"] - 0.6, f0), (P["wall_r0"] - 0.1, f0 + 0.01)], K.MORTAR, key="stone")
    K.stone_wall("Wall", f0, zb - 0.25, P["wall_r0"], P["wall_r1"], P["rows"], P["per_row"],
                 gaps=[(FRONT, 20, f0 + P["door_h"] + 0.6)])
    K.stone_wall("Upper", zb + 0.25, z2, P["wall_r1"] * 0.97, P["wall2_r"], P["rows2"], P["per_row"] - 1,
                 gaps=[(FRONT - 28, 11, z2 - 0.6), (FRONT + 28, 11, z2 - 0.6)])
    K.brass_band("Band", zb, P["wall_r1"], 0.6, 18)
    for s in (-1, 1):
        K.window(f"Win{s}", FRONT + s * 28, r_up(zb + 1.4), zb + 1.35, 0.85, 1.05)
    K.arched_door(FRONT, r_low(f0 + 1.2), f0 + 0.05, P["door_w"], P["door_h"], steps=2)
    for s in (-1, 1):
        K.banner(FRONT + s * 47, r_low(f0 + 4.2) + 0.05, zb - 0.45, 1.9, 2.9)
    K.balcony(z2, P["look_r"], P["look_h"], P["bays"], FRONT + 18)
    K.lathe("LookInside", [(P["look_r"] - 0.3, z2 + 0.3), (P["look_r"] - 0.3, z2 + 0.32)], K.WOOD_DARK, key="wood")
    for k in range(-2, 2):
        K.swag(f"Swag{k}", FRONT + k * 36 + 6, FRONT + (k + 1) * 36 - 6, P["look_r"] + 0.25, z2 + P["look_h"] - 0.1, drop=0.7)
    K.banner(FRONT, P["look_r"] + 0.3, z2 + P["look_h"] + 0.15, 1.85, 1.9)
    K.roof_posts(z2 + P["look_h"], P["post_top"], P["post_r"], 8, FRONT - 22.5)   # one post behind the banner, like the picture
    K.shingle_roof("Roof", P["roof_z0"], P["roof_z1"], P["roof_r"], P["tiers"], P["per_tier"], P["bell"])
    K.roof_ribs("Rib", P["roof_z0"], P["roof_z1"], P["roof_r"], P["bell"], 8, FRONT + 22.5)
    ctop = K.crown(P["roof_z1"] - 0.2, 0.75)
    K.gem(ctop + 0.05, 0.75)
    K.ivy("IvyL", r_low, FRONT - 78, f0 + 1.0, z2 - 0.5, leaves=12, sway=10)
    K.ivy("IvyR", r_low, FRONT + 70, f0 + 0.6, zb + 0.6, leaves=9, sway=10)
    K.grass(P["foot_r"] + 0.05, 40, h=0.9, skip=[(FRONT, 22)])
    K.pebbles(P["foot_r"] + 0.25, 8, skip=[(FRONT, 25)])
    for s in (-1, 1):
        a = rad(FRONT + s * 25)   # between the roof posts, either side of the banner like the picture
        # big, at the rail, leaning over it like the picture's archers (they are what makes level 3 read)
        K.archer(math.cos(a) * (P["look_r"] - 0.95), math.sin(a) * (P["look_r"] - 0.95), z2 + 0.3, 1.9, face=FRONT + s * 12 + 25)

if not os.environ.get("HTD_FAST"):
    K.cull_hidden()
K.finish_check()
if os.environ.get("HTD_FAST"):   # outline only (the shape loop): no bake, no paint file
    import lib
    lib.export_fbx(os.path.abspath(out))
    print("EXPORTED", out)
else:
    K.bake_atlases(f"tower_ranger_l{level}", out, budget=16000)   # body, roof, props and archer textures
