"""The painted enemies, one model per run: goblin, imp, knight, slime, golem, shade. Front faces -Y.
Each has painted gear plus one flat "skin" part named c_0_255_0 that the game colours per enemy type
(Goblin green, Runner yellow, Brute dark green...). Run: blender -b -P enemies.py -- out.fbx <name>"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
import paint  # noqa: E402
from paint import bevel, smooth  # noqa: E402

W = (1, 1, 1)
SKIN = (0.0, 1.0, 0.0)  # the marker colour the game repaints
args = sys.argv[sys.argv.index("--") + 1:]
out, name = os.path.abspath(args[0]), args[1]
rnd = random.Random(2)
lib.reset()
paint.setup()


def skin(obj):
    smooth(obj)
    paint.glow(obj, SKIN)  # stays its own part; the game sees the marker colour and repaints it (not Neon)
    return obj


def eye(x, y, z, r=0.13, col=(1.0, 0.9, 0.3)):
    paint.glow(lib.sphere(f"Eye{x}", r, (x, y, z), W, segments=8), col)


if name == "goblin":
    # big head with long ears and a pointy nose, leather tunic, belt and a rusty dagger
    skin(lib.sphere("Head", 0.62, (0, -0.05, 2.15), W, segments=16))
    for side in (-1, 1):
        ear = lib.cone(f"Ear{side}", 0.22, 0.95, (side * 0.72, 0.05, 2.3), W, vertices=8)
        ear.rotation_euler = (0, math.radians(side * 70), 0)
        skin(ear)
        skin(lib.cylinder(f"Arm{side}", 0.14, 0.9, (side * 0.55, -0.05, 1.25), W, vertices=8,
                          rotation=(0, math.radians(side * 18), 0)))
        skin(lib.cylinder(f"Leg{side}", 0.15, 0.7, (side * 0.2, 0, 0.35), W, vertices=8))
        paint.paint(lib.box(f"Foot{side}", (0.3, 0.45, 0.18), (side * 0.2, -0.08, 0.09), W), "wood_dark", W, 1.0)
    nose = lib.cone("Nose", 0.13, 0.4, (0, -0.65, 2.1), W, vertices=8)
    nose.rotation_euler = (math.radians(90), 0, 0)
    skin(nose)
    eye(-0.22, -0.52, 2.3)
    eye(0.22, -0.52, 2.3)
    tunic = lib.cone("Tunic", 0.55, 1.15, (0, 0, 1.25), W, vertices=12, radius_top=0.38)
    paint.paint(smooth(tunic), "cloth", (0.62, 0.45, 0.3), 1.0)
    paint.paint(lib.cylinder("Belt", 0.5, 0.14, (0, 0, 1.0), W, vertices=12), "wood_dark", W, 1.0)
    paint.paint(lib.box("Buckle", (0.18, 0.06, 0.14), (0, -0.5, 1.0), W), "brass", W, 0.5)
    paint.paint(lib.box("Dagger", (0.06, 0.06, 0.7), (0.72, -0.25, 1.05), W, rotation=(math.radians(-30), 0, 0)), "iron", W, 0.5)
elif name == "imp":
    # a small fiery devil: round body, horns, bat wings, tail
    skin(lib.sphere("Body", 0.55, (0, 0, 1.0), W, segments=14))
    skin(lib.sphere("Head", 0.45, (0, -0.05, 1.75), W, segments=14))
    for side in (-1, 1):
        horn = lib.cone(f"Horn{side}", 0.12, 0.5, (side * 0.25, 0, 2.2), W, vertices=8)
        horn.rotation_euler = (0, math.radians(side * 25), 0)
        paint.paint(horn, None, (0.95, 0.88, 0.75))
        wing = lib.box(f"Wing{side}", (0.9, 0.05, 0.6), (side * 0.75, 0.35, 1.3), W,
                       rotation=(0, math.radians(side * -25), math.radians(side * 20)))
        paint.paint(wing, "cloth", (0.35, 0.18, 0.15), 1.0)
        skin(lib.cylinder(f"Leg{side}", 0.1, 0.5, (side * 0.2, 0, 0.3), W, vertices=8))
    tail = lib.cone("Tail", 0.08, 0.9, (0, 0.6, 0.8), W, vertices=6)
    tail.rotation_euler = (math.radians(-60), 0, 0)
    skin(tail)
    eye(-0.15, -0.4, 1.8, 0.1)
    eye(0.15, -0.4, 1.8, 0.1)
elif name == "knight":
    # obsidian armour, glowing visor slit, round shield and a broad sword; the cape takes the enemy's colour
    armor = (0.55, 0.5, 0.65)
    paint.paint(bevel(lib.box("Chest", (1.1, 0.7, 1.1), (0, 0, 1.75), W), 0.12), "iron", armor, 1.2)
    paint.paint(bevel(lib.box("Hips", (0.9, 0.6, 0.45), (0, 0, 1.05), W), 0.08), "iron", armor, 1.2)
    helm = lib.cylinder("Helm", 0.38, 0.75, (0, 0, 2.65), W, vertices=12)
    paint.paint(bevel(helm, 0.06), "iron", armor, 1.0)
    paint.paint(lib.cone("Crest", 0.1, 0.5, (0, 0, 3.2), W, vertices=6), "iron", armor, 0.8)
    paint.glow(lib.box("Visor", (0.5, 0.05, 0.08), (0, -0.39, 2.7), W), (1.0, 0.55, 0.15))
    for side in (-1, 1):
        paint.paint(lib.sphere(f"Pauldron{side}", 0.35, (side * 0.65, 0, 2.15), W, segments=10), "iron", armor, 0.8)
        paint.paint(lib.box(f"Leg{side}", (0.32, 0.38, 0.85), (side * 0.25, 0, 0.42), W), "iron", armor, 1.0)
    shield = lib.cylinder("Shield", 0.55, 0.12, (-0.75, -0.3, 1.5), W, vertices=14, rotation=(math.radians(90), 0, 0))
    paint.paint(shield, "iron", (0.75, 0.68, 0.8), 1.0)
    paint.paint(lib.sphere("Boss", 0.14, (-0.75, -0.38, 1.5), W, segments=8), "brass", W, 0.5)
    paint.paint(lib.box("Sword", (0.12, 0.05, 1.5), (0.78, -0.25, 1.6), W), "iron", (1.15, 1.15, 1.2), 0.8)
    paint.paint(lib.box("Guard", (0.45, 0.12, 0.1), (0.78, -0.25, 0.9), W), "brass", W, 0.5)
    skin(lib.box("Cape", (1.0, 0.06, 1.6), (0, 0.4, 1.4), W, rotation=(math.radians(-8), 0, 0)))
elif name == "slime":
    # a wobbly blob (the enemy's colour) with big eyes and a shiny highlight
    body = lib.sphere("Body", 0.9, (0, 0, 0.75), W, segments=18)
    body.scale = (1.0, 1.0, 0.82)
    skin(body)
    for side in (-1, 1):
        paint.paint(lib.sphere(f"EyeWhite{side}", 0.2, (side * 0.3, -0.72, 1.0), W, segments=10), None, (1, 1, 1))
        paint.paint(lib.sphere(f"Pupil{side}", 0.1, (side * 0.3, -0.88, 1.0), W, segments=8), None, (0.08, 0.05, 0.05))
    paint.glow(lib.sphere("Shine", 0.18, (-0.35, -0.45, 1.35), W, segments=8), (1.0, 0.95, 0.85))
elif name == "golem":
    # a hulking rock giant with glowing cracks; the crystals on its back take the enemy's colour
    rock = "t_cave_wall"
    paint.paint(bevel(lib.box("Torso", (1.7, 1.2, 1.5), (0, 0, 2.0), W, rotation=(0.1, 0, 0)), 0.25), rock, W, 1.5)
    paint.paint(bevel(lib.box("Head", (0.8, 0.7, 0.6), (0, -0.35, 3.0), W), 0.15), rock, W, 1.0)
    paint.glow(lib.box("Eyes", (0.5, 0.05, 0.1), (0, -0.72, 3.05), W), (1.0, 0.6, 0.2))
    for side in (-1, 1):
        paint.paint(bevel(lib.box(f"Arm{side}", (0.6, 0.6, 1.6), (side * 1.25, -0.1, 1.6), W,
                                  rotation=(0, math.radians(side * 8), 0)), 0.15), rock, W, 1.2)
        paint.paint(bevel(lib.box(f"Fist{side}", (0.75, 0.75, 0.7), (side * 1.35, -0.15, 0.65), W), 0.15), rock, W, 1.0)
        paint.paint(bevel(lib.box(f"Leg{side}", (0.6, 0.65, 1.0), (side * 0.45, 0, 0.5), W), 0.12), rock, W, 1.0)
    paint.glow(lib.box("Core", (0.5, 0.05, 0.5), (0, -0.66, 2.0), W), (1.0, 0.5, 0.15))
    for i in range(5):
        a = (i - 2) * 0.35
        c = lib.cone(f"Crystal{i}", 0.22, 0.9 + rnd.uniform(0, 0.4), (math.sin(a) * 0.6, 0.6, 2.6 + math.cos(a) * 0.1), W, vertices=6)
        c.rotation_euler = (math.radians(-35), a, 0)
        skin(c)
elif name == "shade":
    # a hooded wisp: a flowing cloak (the enemy's colour), a dark hood and two bright eyes, no feet
    cloak = lib.cone("Cloak", 0.75, 2.2, (0, 0, 1.3), W, vertices=14, radius_top=0.3)
    skin(cloak)
    for i in range(5):
        a = i / 5 * math.pi * 2
        tat = lib.cone(f"Tatter{i}", 0.2, 0.5, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.2), W, vertices=4)
        tat.rotation_euler = (math.radians(180), 0, 0)
        skin(tat)
    hood = lib.sphere("Hood", 0.48, (0, 0.05, 2.55), W, segments=14)
    paint.paint(smooth(hood), "cloth", (0.18, 0.14, 0.24), 1.0)
    paint.paint(lib.sphere("Face", 0.34, (0, -0.15, 2.5), W, segments=12), None, (0.03, 0.02, 0.05))
    eye(-0.13, -0.47, 2.55, 0.08, (0.85, 0.95, 1.0))
    eye(0.13, -0.47, 2.55, 0.08, (0.85, 0.95, 1.0))
    for side in (-1, 1):
        arm = lib.cone(f"Arm{side}", 0.18, 1.1, (side * 0.6, -0.1, 1.7), W, vertices=8, radius_top=0.08)
        arm.rotation_euler = (math.radians(-30), math.radians(side * 40), 0)
        skin(arm)

parts = paint.bake("enemy_" + name, out[:-4] + "_paint.png", 512)
print("TRIANGLES", lib.triangles(parts))
lib.export_fbx(out)
print("EXPORTED", out)
