"""Draws each battle map's designed layout from the data (no Studio needed): the outline, the rise outside it,
lanes with their building ring, plateaus, channels, bridges and every placed thing. For checking a layout before
building it.
  python scripts/map_plan.py            -> reviews/maps/img/plan-<Theme>.jpg, and prints the distances that matter
Reads src/server/MapLayouts.luau, src/shared/MapOutline.luau and src/shared/Config.luau with regular expressions (the data is plain numbers).
"""
import math
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "reviews", "maps", "img")
SCALE = 4          # pixels per stud
HALF = (120, 90)   # Config.MapSize / 2
REACH = 48         # how far the rise is built beyond the rectangle
RISE = [(0, 5), (8, 10), (18, 16), (30, 24), (42, 30)]
THEMES = {"Forest": "CursedForest", "Magma": "MagmaFortress", "Crystal": "CrystalCaves"}
NUM = r"(-?\d+(?:\.\d+)?)"
V3 = r"v\(" + NUM + r", " + NUM + r", " + NUM + r"\)"
VEC = r"Vector3\.new\(" + NUM + r", " + NUM + r", " + NUM + r"\)"


def read(path):
    return open(os.path.join(ROOT, path), encoding="utf-8").read()


def block(text, start):
    """the {...} that starts at the first '{' after `start`"""
    i = text.index("{", text.index(start))
    depth, j = 0, i
    while True:
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        if depth == 0:
            return text[i:j + 1]
        j += 1


def points(text, pattern=V3):
    return [(float(x), float(z)) for x, _, z in re.findall(pattern, text)]


def layout(theme):
    body = block(read("src/server/MapLayouts.luau"), "MapLayouts.%s = " % theme)
    plateaus = []
    for m in re.finditer(r'Name = "([^"]+)", X0 = %s, X1 = %s, Z0 = %s, Z1 = %s, H = %s' % (NUM, NUM, NUM, NUM, NUM), body):
        plateaus.append((m.group(1),) + tuple(float(g) for g in m.groups()[1:]))
    channels = []
    for m in re.finditer(r"Width = %s, Points = (\{[^}]*\})" % NUM, block(body, "Channels = ")):
        channels.append((float(m.group(1)), points(m.group(2))))
    sets = block(body, "Sets = ")
    things = []
    for kind, pattern in (("kit", r'Piece = "(\w+)", At = ' + V3), ("prop", r'Model = "(\w+)", At = ' + V3)):
        for m in re.finditer(pattern, sets):
            things.append((kind, m.group(1), float(m.group(2)), float(m.group(4))))
    for grove in re.finditer(r"Grove = \{(.*?)\} \}", sets, re.S):
        for x, z in points(grove.group(1)):
            things.append(("grove", "tree", x, z))
    return {
        "plateaus": plateaus, "channels": channels, "things": things,
        "border": points(block(read("src/shared/MapOutline.luau"), "MapOutline.%s = " % theme)),
        "bridges": points(block(body, "Bridges = "), r"At = " + V3) if "Bridges = " in body else [],
        "paths": [(float(m.group(1)), points(m.group(2))) for m in
                  re.finditer(r"Width = %s, Points = (\{[^}]*\})" % NUM, block(body, "Paths = "))] if "Paths = " in body else [],
    }


def lane(map_id):
    config = read("src/shared/Config.luau")
    if map_id == "CursedForest":
        return points(block(config, "local ForestPath = "), VEC)
    body = block(config, map_id + " = ")
    return points(block(body, "Path = "), VEC)


def spawn(map_id):
    config = read("src/shared/Config.luau")
    body = block(config, map_id + " = ")
    m = re.search(r"SpawnPoint = " + VEC, body)
    return float(m.group(1)), float(m.group(3))


def to_line(p, line):
    best = 1e9
    for a, b in zip(line, line[1:]):
        ax, az, bx, bz = a + b
        t = max(0, min(1, ((p[0] - ax) * (bx - ax) + (p[1] - az) * (bz - az)) / ((bx - ax) ** 2 + (bz - az) ** 2)))
        best = min(best, math.hypot(p[0] - ax - (bx - ax) * t, p[1] - az - (bz - az) * t))
    return best


def outside(border, x, z):
    inside, best = False, 1e9
    for a, b in zip(border, border[1:] + border[:1]):
        if (a[1] > z) != (b[1] > z) and x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
        best = min(best, to_line((x, z), [a, b]))
    return -best if inside else best


def font(size):
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    for theme, map_id in THEMES.items():
        L = layout(theme)
        path = lane(map_id)
        w, h = (HALF[0] + REACH) * 2, (HALF[1] + REACH) * 2
        im = Image.new("RGB", (w * SCALE, h * SCALE), (70, 110, 60))
        d = ImageDraw.Draw(im)

        def px(x, z):
            return (x + HALF[0] + REACH) * SCALE, (z + HALF[1] + REACH) * SCALE

        def rect(x0, z0, x1, z1, **kw):
            d.rectangle(px(x0, z0) + px(x1, z1), **kw)

        # the rise, cell by cell (as TerrainBuilder builds it, without the wander of the upper steps)
        if L["border"]:
            for cx in range(-HALF[0] - REACH + 2, HALF[0] + REACH, 4):
                for cz in range(-HALF[1] - REACH + 2, HALF[1] + REACH, 4):
                    dist = outside(L["border"], cx, cz)
                    if dist <= 0 or any(to_line((cx, cz), pts) < width / 2 + 5 for width, pts in L["channels"]):
                        continue
                    height = [hh for start, hh in RISE if dist >= start][-1]
                    shade = 150 - height * 3
                    rect(cx - 2, cz - 2, cx + 2, cz + 2, fill=(shade, shade, shade - 12))
        rect(-HALF[0], -HALF[1], HALF[0], HALF[1], outline=(255, 255, 255))
        for width, pts in L["channels"]:
            d.line([px(*p) for p in pts], fill=(60, 150, 230), width=int(width * SCALE))
        for name, x0, x1, z0, z1, hh in L["plateaus"]:
            rect(x0, z0, x1, z1, fill=(120, 160, 90), outline=(230, 230, 200))
            d.text(px(x0 + 1, z0 + 1), "%s %d" % (name, hh), font=font(13), fill=(20, 30, 10))
        # the building ring beside the lane (8.5 to 18 studs), then the lane
        d.line([px(*p) for p in path], fill=(150, 175, 110), width=36 * SCALE, joint="curve")
        d.line([px(*p) for p in path], fill=(120, 150, 90), width=17 * SCALE, joint="curve")
        d.line([px(*p) for p in path], fill=(110, 70, 50), width=10 * SCALE, joint="curve")
        for width, pts in L["paths"]:
            (x0, z0), (x1, z1) = pts[0], pts[-1]
            if z0 == z1:
                rect(min(x0, x1), z0 - width / 2, max(x0, x1), z0 + width / 2, fill=(170, 130, 90))
            else:
                rect(x0 - width / 2, min(z0, z1), x0 + width / 2, max(z0, z1), fill=(170, 130, 90))
        for b in L["bridges"]:
            x, y = px(*b)
            d.rectangle((x - 30, y - 30, x + 30, y + 30), outline=(250, 200, 80), width=3)
        colours = {"kit": (235, 235, 235), "prop": (240, 190, 90), "grove": (20, 70, 20)}
        for kind, name, x, z in L["things"]:
            cx, cy = px(x, z)
            r = 14 if kind == "grove" else 9
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colours[kind], outline=(0, 0, 0))
            if kind != "grove":
                d.text((cx + 11, cy - 7), name.replace("keep_field_", "").replace("keep_", ""), font=font(12), fill=(0, 0, 0))
        if L["border"]:
            d.line([px(*p) for p in L["border"] + L["border"][:1]], fill=(255, 60, 60), width=3)
        sx, sy = px(*spawn(map_id))
        d.ellipse((sx - 8, sy - 8, sx + 8, sy + 8), fill=(255, 255, 0), outline=(0, 0, 0))
        d.text((12, 8), "%s: outline red, rise grey (darker = higher), building ring light, spawn yellow" % map_id,
               font=font(20), fill=(255, 255, 255))
        im.convert("RGB").save(os.path.join(OUT, "plan-%s.jpg" % theme), quality=88)

        # the numbers
        if not L["border"]:
            continue
        near = min((-outside(L["border"], *p), p) for a, b in zip(path, path[1:])
                   for p in [(a[0] + (b[0] - a[0]) * t / 20, a[1] + (b[1] - a[1]) * t / 20) for t in range(21)])
        print("%s: the lane comes within %.1f studs of the outline (at %d, %d)" % (map_id, near[0], near[1][0], near[1][1]))
        for i, p in enumerate(L["border"]):
            print("   corner %2d (%4d, %4d): %.1f from the lane" % (i + 1, p[0], p[1], to_line(p, path)))
        for kind, name, x, z in L["things"]:
            dist = outside(L["border"], x, z)
            if dist > -3:
                print("   %s %s at %d, %d is %.1f studs %s the outline" % (kind, name, x, z, abs(dist), "outside" if dist > 0 else "inside"))
        ring = inside = 0
        for x in range(-HALF[0] + 6, HALF[0] - 5, 4):
            for z in range(-HALF[1] + 6, HALF[1] - 5, 4):
                if 8.5 <= to_line((x, z), path) <= 18:
                    ring += 1
                    inside += outside(L["border"], x, z) < -6
        area = sum(outside(L["border"], x, z) < 0 for x in range(-118, 120, 4) for z in range(-88, 90, 4)) * 16
        print("   %d%% of the building ring lies 6 studs or more inside; the field is %d%% of the old rectangle"
              % (round(inside / ring * 100), round(area / (240 * 180) * 100)))


if __name__ == "__main__":
    main()
