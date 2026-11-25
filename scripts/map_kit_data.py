"""Writes src/server/MapKit.luau from the measured kit (art/models/mapkit/boxes.json, made by
art/blender/map_kit_boxes.py): each model's box and what is solid in it, in the placed piece's own space
(X to its right, Y up, front at -Z; the build scripts use X along, Y to the back, Z up).
Run after building kit pieces:  python scripts/map_kit_data.py"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
boxes = json.load(open(os.path.join(ROOT, "art", "models", "mapkit", "boxes.json")))

# what a hero bumps into, per piece, as boxes in the build script's coordinates: (centre), (size)
SOLID = {
    "wall": [((-3.5, 0, 2.4), (7.0, 1.8, 4.8)), ((3.5, 0, 1.5), (7.0, 1.8, 3.0))],
    "low": [((0, 0, 1.2), (12.0, 1.4, 2.4))],
    "arch": [((-8.6, 0, 4.5), (3.6, 3.6, 9.0)), ((8.6, 0, 4.5), (3.6, 3.6, 9.0))],
    "pillar": [((0, 0, 3.4), (2.4, 2.4, 6.8))],
    "bridge": [((0, -8.1, 1.3), (17.0, 1.5, 2.6)), ((0, 8.1, 1.3), (17.0, 1.5, 2.6))],
    "set_forest": [((-2.6, 0, 3.6), (2.0, 1.5, 7.2)), ((2.6, 0, 3.6), (2.0, 1.5, 7.2))],
    "set_magma": [((0, 0, 2.2), (3.4, 3.4, 4.4))],
    "set_crystal": [((0, 0, 1.4), (4.0, 2.8, 2.8))],
    # the wall, and the flagstone rim lying behind it (a hero walks on the rim over the terrain's bevel)
    "face": [((0, 0, 1.55), (12.0, 1.3, 6.1)), ((0, 2.15, 4.87), (12.0, 6.2, 0.55))],
    # the keep tower: all of it (its door is a picture; nobody goes in)
    "tower": [((0, 0, 9.0), (9.6, 9.6, 18.0))],
    # the furnace's body (the chimney stands on it, the slag trough is flat)
    "furnace": [((0, 0, 3.8), (12.4, 9.4, 7.6))],
}


def v(x, y, z):
    return "Vector3.new(%s, %s, %s)" % tuple(("%.3f" % c).rstrip("0").rstrip(".") for c in (x, y, z))


lines = ["-- Made by scripts/map_kit_data.py from the built kit (art/models/mapkit). Do not edit by hand.",
         "-- Boxes: each kit model's box in the piece's own space (X right, Y up, front at -Z), in studs.",
         "-- Solid: what a hero bumps into (the pictures themselves never collide: an arch's rough hull would block the lane).",
         "local MapKit = {}", "", "MapKit.Boxes = {"]
for name, b in sorted(boxes.items()):
    (x0, y0, z0), (x1, y1, z1) = b["min"], b["max"]
    lines.append("\t%s = { Min = %s, Max = %s }," % (name, v(-x1, z0, y0), v(-x0, z1, y1)))
lines += ["}", "", "MapKit.Solid = {"]
for piece, solids in SOLID.items():
    parts = ", ".join("{ Centre = %s, Size = %s }" % (v(-c[0], c[2], c[1]), v(s[0], s[2], s[1])) for c, s in solids)
    lines.append("\t%s = { %s }," % (piece, parts))
lines += ["}", "", "return MapKit", ""]
open(os.path.join(ROOT, "src", "server", "MapKit.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
print("wrote src/server/MapKit.luau with", len(boxes), "models")
