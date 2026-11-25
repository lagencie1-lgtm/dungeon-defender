"""Where a tower look's files are, for the tower workflow scripts (tower_fit, tower_round, tower_paint, tower_grade).
Most towers have numbered levels (ranger 2 -> art/ref3d/tower_ranger_l2.png, builder argument "2"); the Oak Barricade
has four named looks (barricade l2 / thorn / root, builder argument "l2"). The barricade's pictures show its enemy side
(+Y), so it is seen from azimuth 105 instead of -75, and it is scored on its centre section only (the picture has no
road wings): HTD_CENTRE_ONLY=1 builds that part alone. The barricade's picture with the ground painted out
(tower_barricade_<look>_fit.png) is the one the scores use."""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AZIMUTH = {"barricade": 105.0}


def stage(kind, arg):
    arg = str(arg)
    named = not arg.isdigit()
    look = arg if named else "l" + arg
    picture = os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_{look}.png")
    fit = picture[:-4] + "_fit.png"
    az = AZIMUTH.get(kind, -75.0)
    return {
        "look": look,
        "builder_arg": arg,
        "key": f"{kind}_{look}" if named else f"{kind}{arg}",
        "picture": fit if os.path.exists(fit) else picture,
        "params": os.path.join(ROOT, "art", "blender", "params", f"tower_{kind}_{look}.json"),
        "folder": os.path.join(ROOT, "reviews", "towers", f"{kind}_{look}"),
        "builder": os.path.join(ROOT, "art", "blender", f"tower_{kind}_detail.py"),
        "az": az,
        "sides": [az, az + 90, az + 180, az + 270],
        "centre": kind == "barricade",
    }


def kind_of(fbx):
    """tower kind from a model file name (tower_barricade_l2.fbx -> barricade)"""
    name = os.path.basename(fbx)
    return name.split("_")[1] if name.startswith("tower_") else ""
