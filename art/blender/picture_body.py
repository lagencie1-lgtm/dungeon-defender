"""A painted picture as the body (docs/6A/6A-roblox-world-and-art.md section IV, extended to a turnaround; coordinator
2026-11-23): the model is built OUT OF the painting instead of sculpted to look like it, and the paintings are the paint.

  1. the views: a Codex orthographic sheet with FRONT, SIDE (his right side, facing the image's right edge) and BACK
     at the same height; each view is cut out, and the body axis of each is given in the spec.
  2. parts: each part is the front silhouette inside a box (arms, a leg...) and gets its depth row by row from the
     same part in the side view (a box there too).
  3. geometry: every row of a part's front silhouette becomes an ellipse in depth (as wide as the silhouette there,
     as deep as the side view says there, centred where the side view has it): front and back sheets meeting at the
     outline, closed by a thin wall. So the outline from the front and from the side IS the painting's outline.
  4. paint: the painting itself: the front view on faces looking forward, the back view on faces looking back, the
     side view on both sides (mirrored on the left), blended by the surface direction, baked into the part's texture.
     No repaint of renders anywhere: the face is the front painting's face, untouched.

Run: blender -b -P picture_body.py -- spec.json out_folder
spec.json: {"sheet": "...png", "height": 2.4, "step": 5,
            "views": {"front": [x0, y0, x1, y1, axis_x], "side": [...], "back": [...]},   (pixel boxes on the sheet)
            "parts": [{"name": "Body", "front_keep": [[x0,y0,x1,y1]...] or null, "front_cut": [[...]], "side_box": [...] or null,
                       "texture": 1024, "pivot": [x, y, z] (studs, optional)}]}
Boxes in a view are in that view's own pixels (0,0 = the view's top left). Writes <name>.fbx (all parts) and
<name>_<part>_paint.png per part."""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
spec = json.load(open(args[0]))
OUT = os.path.abspath(args[1])
os.makedirs(OUT, exist_ok=True)
SHEET = os.path.join(os.path.dirname(os.path.abspath(args[0])), spec["sheet"]) if not os.path.isabs(spec["sheet"]) else spec["sheet"]
NAME = spec.get("name", "picture_body")
STEP = spec.get("step", 5)

bpy.ops.wm.read_factory_settings(use_empty=True)
img = bpy.data.images.load(SHEET)
SW, SH = img.size
px = np.empty(SW * SH * 4, dtype=np.float32)
img.pixels.foreach_get(px)
sheet = np.flipud(px.reshape(SH, SW, 4))[:, :, :3]            # row 0 = top
solid = sheet.min(axis=2) < 0.9                                # the painter's white ground is not the figure
# (and not its pale anti-aliased rim either: one pixel in, so no white edge shows on the model)
solid = solid & np.roll(solid, 1, 0) & np.roll(solid, -1, 0) & np.roll(solid, 1, 1) & np.roll(solid, -1, 1)


def fill_holes(m):
    """everything not reachable from the border is inside the figure: the white of the eyes, the cream trim and the
    highlights punched holes in the silhouette (a face-shaped relief showed on the back of the hood)"""
    outside = np.zeros_like(m)
    outside[0, :] = ~m[0, :]
    outside[-1, :] = ~m[-1, :]
    outside[:, 0] = ~m[:, 0]
    outside[:, -1] = ~m[:, -1]
    while True:
        grown = outside | (np.roll(outside, 1, 0) | np.roll(outside, -1, 0) | np.roll(outside, 1, 1) | np.roll(outside, -1, 1)) & ~m
        if (grown == outside).all():
            return ~outside
        outside = grown


def view(name):
    x0, y0, x1, y1, ax = spec["views"][name]
    return {"x0": x0, "y0": y0, "x1": x1, "y1": y1, "axis": ax, "mask": fill_holes(solid[y0:y1, x0:x1].copy())}


def erase_parts():
    """a separate part (quiver, bow...) is always erased from the body paintings before anything is projected or
    measured (coordinator 2026-11-23: the back painting's own quiver plus the modelled one made two quivers): its
    polygon (in a view's own pixels) is filled from the surrounding colours, and cut from that view's silhouette
    where it stood out over the background."""
    global sheet, solid
    for vname, polys in spec.get("erase", {}).items():
        x0, y0, x1, y1, _ = spec["views"][vname]
        er = np.zeros((y1 - y0, x1 - x0), dtype=bool)
        for poly in polys:   # scanline fill (Blender's Python has no PIL)
            n = len(poly)
            for r in range(er.shape[0]):
                xs = []
                for i in range(n):
                    (ax_, ay), (bx, by) = poly[i], poly[(i + 1) % n]
                    if (ay <= r < by) or (by <= r < ay):
                        xs.append(ax_ + (r - ay) * (bx - ax_) / (by - ay))
                xs.sort()
                for a_, b_ in zip(xs[0::2], xs[1::2]):
                    er[r, max(0, int(a_)):min(er.shape[1], int(b_) + 1)] = True
        region = sheet[y0:y1, x0:x1]
        known = solid[y0:y1, x0:x1] & ~er
        out = region.copy()
        have = known.copy()
        for _ in range(400):
            grow = (~have) & er
            if not grow.any():
                break
            acc = np.zeros_like(out)
            cnt = np.zeros(have.shape)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sh = np.roll(np.roll(have, dy, 0), dx, 1)
                acc += np.roll(np.roll(out, dy, 0), dx, 1) * sh[..., None]
                cnt += sh
            step = grow & (cnt > 0)
            if not step.any():
                break
            out[step] = acc[step] / cnt[step][:, None]
            have |= step
        sheet[y0:y1, x0:x1] = out
        # the silhouette: what the part covered outside the body becomes background; holes inside close again
        cut = solid[y0:y1, x0:x1] & ~er
        solid[y0:y1, x0:x1] = fill_holes(cut | (er & fill_holes(cut)))
        print("ERASED", vname, int(er.sum()), "pixels")


erase_parts()
V = {k: view(k) for k in ("front", "side", "back")}


def fit_back_axis():
    """the back view's body axis: where its outline best matches the front outline seen from behind (mirrored)"""
    fm, bm_ = V["front"]["mask"], V["back"]["mask"]
    h = min(fm.shape[0], bm_.shape[0])
    best, best_ax = -1, V["back"]["axis"]
    fax = V["front"]["axis"]
    for ax in range(bm_.shape[1] // 2 - 40, bm_.shape[1] // 2 + 41):
        # front column c (x = c - fax) appears in the back view at column ax - (c - fax)
        score = 0
        for r in range(0, h, 6):
            cols = np.where(fm[r])[0]
            bc = ax - (cols - fax)
            ok = (bc >= 0) & (bc < bm_.shape[1])
            score += bm_[r, bc[ok]].sum()
        if score > best:
            best, best_ax = score, ax
    V["back"]["axis"] = best_ax
    print("BACK AXIS", best_ax)


fit_back_axis()


def pad_colours(rgb, mask, rounds=12):
    """grow the figure's colours a few pixels out over the white ground, so paint taken right at an edge is never the
    painter's white (it drew a pale rim round every part)"""
    inner = mask.copy()
    for _ in range(2):   # first drop the pale anti-aliased rim itself
        inner = inner & np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    out = rgb.copy()
    have = inner.copy()
    for _ in range(rounds):
        acc = np.zeros_like(out)
        cnt = np.zeros(have.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(have, dy, 0), dx, 1)
            acc += np.roll(np.roll(out, dy, 0), dx, 1) * sh[..., None]
            cnt += sh
        grow = (~have) & (cnt > 0)
        out[grow] = acc[grow] / cnt[grow][:, None]
        have |= grow
    return out


padded = pad_colours(sheet, solid)
pimg = bpy.data.images.new("sheet_padded", SW, SH)
pimg.pixels.foreach_set(np.flipud(np.dstack([padded, np.ones((SH, SW))])).astype(np.float32).ravel())
img = pimg
HPX = V["front"]["y1"] - V["front"]["y0"]
S = spec["height"] / HPX                                       # studs per pixel


def box_mask(shape, boxes):
    m = np.zeros(shape, dtype=bool)
    for x0, y0, x1, y1 in boxes:
        m[y0:y1, x0:x1] = True
    return m


def part_masks(p):
    f = V["front"]["mask"].copy()
    if p.get("front_keep"):
        f &= box_mask(f.shape, p["front_keep"])
    if p.get("front_cut"):
        f &= ~box_mask(f.shape, p["front_cut"])
    s = V["side"]["mask"].copy()
    if p.get("side_box"):
        s &= box_mask(s.shape, [p["side_box"]])
    return f, s


def depth_rows(side):
    """per row: (front y, back y) in studs (front = -Y, the face side = the side view's right)"""
    ax = V["side"]["axis"]
    rows = []
    for r in range(side.shape[0]):
        cols = np.where(side[r])[0]
        if len(cols) == 0:
            rows.append(None)
        else:
            rows.append((-(cols.max() + 1 - ax) * S, -(cols.min() - ax) * S))
    return rows


def build(p):
    """the part's solid: per row, each run of the front silhouette becomes a half-ellipse in front and behind"""
    f, s = part_masks(p)
    dr = depth_rows(s)
    # rows without side information borrow the nearest row that has some
    known = [i for i, v in enumerate(dr) if v]
    for i in range(len(dr)):
        if dr[i] is None and known:
            dr[i] = dr[min(known, key=lambda k: abs(k - i))]
    # smooth the depth from row to row (single painted rows jump; the steps showed as streaks in the paint)
    if known:
        arr = np.array([v for v in dr])
        k = p.get("depth_smooth", 9)
        pad = np.pad(arr, ((k // 2, k // 2), (0, 0)), mode="edge")
        kern = np.ones(k) / k
        arr = np.stack([np.convolve(pad[:, c], kern, mode="valid") for c in range(2)], axis=1)
        dr = [tuple(v) for v in arr]
    ax = V["front"]["axis"]
    H, W = f.shape
    ys = list(range(0, H, STEP)) + ([H - 1] if (H - 1) % STEP else [])
    xs = list(range(0, W, STEP)) + ([W - 1] if (W - 1) % STEP else [])
    inside = np.zeros((len(ys), len(xs)), dtype=bool)
    ell = np.zeros((len(ys), len(xs)))
    for i, r in enumerate(ys):
        row = f[r]
        cols = np.where(row)[0]
        if len(cols) == 0:
            continue
        # runs of the silhouette in this row
        breaks = np.where(np.diff(cols) > 1)[0]
        starts = np.concatenate(([cols[0]], cols[breaks + 1]))
        ends = np.concatenate((cols[breaks], [cols[-1]]))
        for j, c in enumerate(xs):
            for a, b in zip(starts, ends):
                if a - STEP * 0.5 <= c <= b + STEP * 0.5:
                    half = max(1.0, (b - a) / 2 + 0.5)
                    mid = (a + b) / 2
                    u = min(1.0, abs(c - mid) / half)
                    inside[i, j] = True
                    ell[i, j] = math.sqrt(max(0.0, 1 - u * u)) ** 0.8
                    break
    bm = bmesh.new()
    front, back = {}, {}
    for i, r in enumerate(ys):
        if dr[r] is None:
            continue
        yf, yb = dr[r]
        c, half = (yf + yb) / 2, (yb - yf) / 2
        z = (H - r) * S
        for j, col in enumerate(xs):
            if inside[i, j]:
                x = (col - ax) * S
                e = max(ell[i, j], 0.04)
                front[i, j] = bm.verts.new((x, c - half * e, z))
                back[i, j] = bm.verts.new((x, c + half * e, z))
    for i in range(len(ys) - 1):
        for j in range(len(xs) - 1):
            q = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            if all(k in front for k in q):
                bm.faces.new([front[k] for k in q])
                bm.faces.new([back[k] for k in reversed(q)])
    # a thin wall where the sheets end, so the part is closed
    for (i, j) in list(front):
        for di, dj in ((0, 1), (1, 0)):
            k2 = (i + di, j + dj)
            if k2 not in front:
                continue
            # an edge is on the outline when only one of the two quads beside it exists
            if di == 0:
                side_a = [(i - 1, j), (i - 1, j + 1)]
                side_b = [(i + 1, j), (i + 1, j + 1)]
            else:
                side_a = [(i, j - 1), (i + 1, j - 1)]
                side_b = [(i, j + 1), (i + 1, j + 1)]
            a_ok = all(k in front for k in side_a)
            b_ok = all(k in front for k in side_b)
            if a_ok != b_ok:
                try:
                    bm.faces.new([front[(i, j)], front[k2], back[k2], back[(i, j)]])
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(p["name"])
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(p["name"], mesh)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    sm = o.modifiers.new("smooth", "SMOOTH")   # soften the pixel steps of the outline
    sm.factor = 0.5
    sm.iterations = p.get("smooth", 10)
    bpy.ops.object.modifier_apply(modifier=sm.name)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return o


PART_WEIGHTS = {p["name"]: p.get("weights", {}) for p in spec["parts"]}


def paint_material(o):
    """the paintings as the paint: three projections of the sheet, blended by the surface direction"""
    mat = bpy.data.materials.new(o.name + "_views")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes.new, nt.links.new
    coord = n("ShaderNodeTexCoord")
    xyz = n("ShaderNodeSeparateXYZ")
    link(coord.outputs["Object"], xyz.inputs[0])
    geo = n("ShaderNodeNewGeometry")
    nrm = n("ShaderNodeSeparateXYZ")
    link(geo.outputs["Normal"], nrm.inputs[0])

    def lin(src, a, b):
        """a * src + b"""
        m1 = n("ShaderNodeMath")
        m1.operation = "MULTIPLY_ADD"
        link(src, m1.inputs[0])
        m1.inputs[1].default_value = a
        m1.inputs[2].default_value = b
        return m1.outputs[0]

    def projection(vname, horiz, sign):
        v = V[vname]
        # sheet U from the horizontal coordinate, V from the height (image rows run downwards, UV upwards)
        u = lin(horiz, sign / S / SW, (v["x0"] + v["axis"]) / SW)
        vv = lin(xyz.outputs["Z"], 1 / S / SH, 1 - (v["y0"] + (v["y1"] - v["y0"])) / SH)
        comb = n("ShaderNodeCombineXYZ")
        link(u, comb.inputs[0])
        link(vv, comb.inputs[1])
        tex = n("ShaderNodeTexImage")
        tex.image = img
        tex.extension = "EXTEND"
        link(comb.outputs[0], tex.inputs["Vector"])
        return tex.outputs["Color"]

    front = projection("front", xyz.outputs["X"], 1)
    back = projection("back", xyz.outputs["X"], -1)
    side = projection("side", xyz.outputs["Y"], -1)        # his right side; the left side shows it mirrored

    def weight(src, mode, power=6.0, gain=1.0):
        m = n("ShaderNodeMath")
        if mode == "neg":
            m.operation = "MULTIPLY"
            link(src, m.inputs[0])
            m.inputs[1].default_value = -1
            src = m.outputs[0]
            m = n("ShaderNodeMath")
        if mode == "abs":
            m.operation = "ABSOLUTE"
            link(src, m.inputs[0])
            src = m.outputs[0]
            m = n("ShaderNodeMath")
        m.operation = "MAXIMUM"
        link(src, m.inputs[0])
        m.inputs[1].default_value = 0
        p = n("ShaderNodeMath")
        p.operation = "POWER"
        link(m.outputs[0], p.inputs[0])
        p.inputs[1].default_value = power
        g = n("ShaderNodeMath")
        g.operation = "MULTIPLY"
        link(p.outputs[0], g.inputs[0])
        g.inputs[1].default_value = gain
        return g.outputs[0]

    # the front and back paintings own everything but the true sides: at 45 degrees a blend of the front face and
    # the side profile drew two faces (the side view's power is higher, so it only wins where it looks straight on)
    wcfg = PART_WEIGHTS.get(o.name, {})
    wf = weight(nrm.outputs["Y"], "neg", wcfg.get("front_power", 2.0), wcfg.get("front_gain", 4.0))
    wb = weight(nrm.outputs["Y"], "pos", wcfg.get("back_power", 2.0), wcfg.get("back_gain", 4.0))
    ws = weight(nrm.outputs["X"], "abs", wcfg.get("side_power", 10.0), wcfg.get("side_gain", 1.0))
    # mix: (front*wf + back*wb + side*ws) / (wf + wb + ws)
    total = n("ShaderNodeMath")
    total.operation = "ADD"
    link(wf, total.inputs[0])
    link(wb, total.inputs[1])
    total2 = n("ShaderNodeMath")
    total2.operation = "ADD"
    link(total.outputs[0], total2.inputs[0])
    link(ws, total2.inputs[1])
    total3 = n("ShaderNodeMath")
    total3.operation = "MAXIMUM"
    link(total2.outputs[0], total3.inputs[0])
    total3.inputs[1].default_value = 1e-4

    def scaled(col, w):
        d = n("ShaderNodeMath")
        d.operation = "DIVIDE"
        link(w, d.inputs[0])
        link(total3.outputs[0], d.inputs[1])
        mix = n("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        link(col, mix.inputs[6])
        val = n("ShaderNodeCombineColor")
        for k in range(3):
            link(d.outputs[0], val.inputs[k])
        link(val.outputs[0], mix.inputs[7])
        return mix.outputs[2]

    a = scaled(front, wf)
    b = scaled(back, wb)
    c = scaled(side, ws)
    add1 = n("ShaderNodeMix")
    add1.data_type = "RGBA"
    add1.blend_type = "ADD"
    add1.inputs["Factor"].default_value = 1.0
    link(a, add1.inputs[6])
    link(b, add1.inputs[7])
    add2 = n("ShaderNodeMix")
    add2.data_type = "RGBA"
    add2.blend_type = "ADD"
    add2.inputs["Factor"].default_value = 1.0
    link(add1.outputs[2], add2.inputs[6])
    link(c, add2.inputs[7])
    emit = n("ShaderNodeEmission")
    link(add2.outputs[2], emit.inputs["Color"])
    out = n("ShaderNodeOutputMaterial")
    link(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def bake(o, size, keep_material=False):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    if keep_material:
        mat = o.data.materials[0]
    else:
        o.data.materials.clear()
        mat = paint_material(o)
        o.data.materials.append(mat)
    tex = bpy.data.images.new(o.name + "_paint", size, size)
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = tex
    mat.node_tree.nodes.active = node
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.margin = 16       # wide margin: no dark gaps between islands when the game shows it small
    bpy.ops.object.bake(type="EMIT")
    path = os.path.join(OUT, f"{NAME}_{o.name.lower()}_paint.png")
    tex.filepath_raw = path
    tex.file_format = "PNG"
    tex.save()
    final = bpy.data.materials.new(o.name + "_baked")
    final.use_nodes = True
    t = final.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = tex
    final.node_tree.links.new(t.outputs["Color"], final.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(final)
    print("PART", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), "triangles", path)


def load_sheet(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    rgb = np.flipud(a.reshape(h, w, 4))[:, :, :3]
    m = rgb.min(axis=2) < 0.92
    padded = pad_colours(rgb, m)
    pim = bpy.data.images.new(os.path.basename(path) + "_padded", w, h)
    pim.pixels.foreach_set(np.flipud(np.dstack([padded, np.ones((h, w))])).astype(np.float32).ravel())
    return pim, m, w, h


def build_flat(p):
    """a flat prop (bow, quiver) from its own picture: the outline extruded to `thickness`, soft edges, the picture
    on both faces; placed with `place` (location, rotation in degrees). Its picture's x runs along local X (mirror:
    true flips it), its height along Z."""
    fl = p["flat"]
    path = os.path.join(os.path.dirname(os.path.abspath(args[0])), fl["sheet"])
    pim, m, w, h = load_sheet(path)
    x0, y0, x1, y1 = fl["box"]
    mask = m[y0:y1, x0:x1]
    hp = y1 - y0
    sc = fl["height"] / hp
    t = fl.get("thickness", 0.06)
    st = max(3, int(hp / fl.get("grid", 40)))
    ys = list(range(0, mask.shape[0], st))
    xs = list(range(0, mask.shape[1], st))
    bm = bmesh.new()
    front, back = {}, {}
    mir = -1 if fl.get("mirror") else 1
    cx = (x1 - x0) / 2
    for i, r in enumerate(ys):
        for j, c in enumerate(xs):
            if mask[r, c]:
                x, z = mir * (c - cx) * sc, (hp - r) * sc
                front[i, j] = bm.verts.new((x, -t / 2, z))
                back[i, j] = bm.verts.new((x, t / 2, z))
    for i in range(len(ys) - 1):
        for j in range(len(xs) - 1):
            q = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            if all(k in front for k in q):
                bm.faces.new([front[k] for k in q])
                bm.faces.new([back[k] for k in reversed(q)])
    for (i, j) in list(front):
        for di, dj in ((0, 1), (1, 0)):
            k2 = (i + di, j + dj)
            if k2 not in front:
                continue
            sa = [(i - 1, j), (i - 1, j + 1)] if di == 0 else [(i, j - 1), (i + 1, j - 1)]
            sb = [(i + 1, j), (i + 1, j + 1)] if di == 0 else [(i, j + 1), (i + 1, j + 1)]
            if all(k in front for k in sa) != all(k in front for k in sb):
                try:
                    bm.faces.new([front[(i, j)], front[k2], back[k2], back[(i, j)]])
                except ValueError:
                    pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(p["name"])
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(p["name"], mesh)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    sm = o.modifiers.new("smooth", "SMOOTH")
    sm.factor = 0.5
    sm.iterations = 3
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=sm.name)
    for poly in mesh.polygons:
        poly.use_smooth = True
    # paint: the prop picture straight on (object X, Z -> picture)
    mat = bpy.data.materials.new(p["name"] + "_pic")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes.new, nt.links.new
    coord = n("ShaderNodeTexCoord")
    xyz = n("ShaderNodeSeparateXYZ")
    link(coord.outputs["Object"], xyz.inputs[0])
    mu = n("ShaderNodeMath")
    mu.operation = "MULTIPLY_ADD"
    link(xyz.outputs["X"], mu.inputs[0])
    mu.inputs[1].default_value = mir / sc / w
    mu.inputs[2].default_value = (x0 + cx) / w
    mv = n("ShaderNodeMath")
    mv.operation = "MULTIPLY_ADD"
    link(xyz.outputs["Z"], mv.inputs[0])
    mv.inputs[1].default_value = 1 / sc / h
    mv.inputs[2].default_value = 1 - y1 / h
    comb = n("ShaderNodeCombineXYZ")
    link(mu.outputs[0], comb.inputs[0])
    link(mv.outputs[0], comb.inputs[1])
    tex = n("ShaderNodeTexImage")
    tex.image = pim
    tex.extension = "EXTEND"
    link(comb.outputs[0], tex.inputs["Vector"])
    emit = n("ShaderNodeEmission")
    link(tex.outputs["Color"], emit.inputs["Color"])
    out = n("ShaderNodeOutputMaterial")
    link(emit.outputs["Emission"], out.inputs["Surface"])
    o.data.materials.append(mat)
    return o


def build_tube(p):
    """a round prop from its picture (coordinator 2026-11-23: no flat cut-outs for anything that turns): per row of the
    picture, the widest run of the outline is the limb; its centre line and width become a tube with a round
    section. "string": also a thin string between the two ends. "cards_above": rows above that one (feathers) become
    two crossed painted cards instead."""
    fl = p["flat"]
    path = os.path.join(os.path.dirname(os.path.abspath(args[0])), fl["sheet"])
    pim, m, w, h = load_sheet(path)
    x0, y0, x1, y1 = fl["box"]
    # (no hole filling here: the space between a bow and its string is not bow)
    mask = m[y0:y1, x0:x1] if fl.get("string") else fill_holes(m[y0:y1, x0:x1])
    hp = y1 - y0
    sc = fl["height"] / hp
    mir = -1 if fl.get("mirror") else 1
    cx = (x1 - x0) / 2
    st = max(2, int(hp / fl.get("rings", 60)))
    card_row = fl.get("cards_above", 0)
    bm = bmesh.new()
    seg = 10
    rings, tips = [], []
    for r in range(card_row, mask.shape[0], st):
        cols = np.where(mask[r])[0]
        if len(cols) == 0:
            continue
        breaks = np.where(np.diff(cols) > 1)[0]
        starts = np.concatenate(([cols[0]], cols[breaks + 1]))
        ends = np.concatenate((cols[breaks], [cols[-1]]))
        k = int(np.argmax(ends - starts))
        a_, b_ = starts[k], ends[k]
        rad_ = max(1.5, (b_ - a_ + 1) / 2) * sc
        xc = mir * ((a_ + b_) / 2 - cx) * sc
        z = (hp - r) * sc
        ring = [bm.verts.new((xc + math.cos(2 * math.pi * i / seg) * rad_, math.sin(2 * math.pi * i / seg) * rad_ * fl.get("depth", 1.0), z)) for i in range(seg)]
        rings.append(ring)
        tips.append((xc, z))
    for ra, rb in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if rings:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    if fl.get("string") and len(tips) > 2:
        # the string: from end to end on the far side from the bulge
        (xa, za), (xb, zb) = tips[0], tips[-1]
        bulge = max(tips, key=lambda t: abs(t[0] - (xa + xb) / 2))
        off = -0.04 * (1 if bulge[0] > (xa + xb) / 2 else -1)
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.012, radius2=0.012, depth=abs(za - zb))
        bmesh.ops.translate(bm, vec=((xa + xb) / 2 + off, 0, (za + zb) / 2), verts=res["verts"])
    if card_row > 0:
        # feathers: the picture's top rows on two crossed cards
        sub = mask[:card_row]
        rows = np.where(sub.any(axis=1))[0]
        colsx = np.where(sub.any(axis=0))[0]
        if len(rows) and len(colsx):
            xa, xb = mir * (colsx.min() - cx) * sc, mir * (colsx.max() - cx) * sc
            za, zb = (hp - rows.max()) * sc, (hp - rows.min()) * sc
            for k in range(2):
                ang = math.radians(45 + 90 * k)
                c, s_ = math.cos(ang), math.sin(ang)
                mid = (xa + xb) / 2
                half = (xb - xa) / 2
                q = [bm.verts.new((mid + (-half) * c, (-half) * s_ * 0.6, za)), bm.verts.new((mid + half * c, half * s_ * 0.6, za)),
                     bm.verts.new((mid + half * c, half * s_ * 0.6, zb)), bm.verts.new((mid + (-half) * c, (-half) * s_ * 0.6, zb))]
                bm.faces.new(q)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(p["name"])
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(p["name"], mesh)
    bpy.context.scene.collection.objects.link(o)
    for poly in mesh.polygons:
        poly.use_smooth = True
    # the picture straight on, as for flat props
    mat = bpy.data.materials.new(p["name"] + "_pic")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes.new, nt.links.new
    coord = n("ShaderNodeTexCoord")
    xyz = n("ShaderNodeSeparateXYZ")
    link(coord.outputs["Object"], xyz.inputs[0])
    mu = n("ShaderNodeMath")
    mu.operation = "MULTIPLY_ADD"
    link(xyz.outputs["X"], mu.inputs[0])
    mu.inputs[1].default_value = mir / sc / w
    mu.inputs[2].default_value = (x0 + cx) / w
    mv = n("ShaderNodeMath")
    mv.operation = "MULTIPLY_ADD"
    link(xyz.outputs["Z"], mv.inputs[0])
    mv.inputs[1].default_value = 1 / sc / h
    mv.inputs[2].default_value = 1 - y1 / h
    comb = n("ShaderNodeCombineXYZ")
    link(mu.outputs[0], comb.inputs[0])
    link(mv.outputs[0], comb.inputs[1])
    tex = n("ShaderNodeTexImage")
    tex.image = pim
    tex.extension = "EXTEND"
    link(comb.outputs[0], tex.inputs["Vector"])
    emit = n("ShaderNodeEmission")
    link(tex.outputs["Color"], emit.inputs["Color"])
    out = n("ShaderNodeOutputMaterial")
    link(emit.outputs["Emission"], out.inputs["Surface"])
    o.data.materials.append(mat)
    return o


def place(o, pl):
    from mathutils import Euler, Matrix, Vector
    o.matrix_world = Matrix.Translation(Vector(pl.get("location", (0, 0, 0)))) @ Euler([math.radians(v) for v in pl.get("rotation", (0, 0, 0))], "XYZ").to_matrix().to_4x4()
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


parts = []
for p in spec["parts"]:
    if p.get("flat"):
        o = build_tube(p) if p["flat"].get("tube") else build_flat(p)
        bake(o, p.get("texture", 512), keep_material=True)
        place(o, p.get("place", {}))
        parts.append(o)
        continue
    o = build(p)
    if p.get("triangles"):
        count = sum(len(q.vertices) - 2 for q in o.data.polygons)
        if count > p["triangles"]:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            dec = o.modifiers.new("dec", "DECIMATE")
            dec.ratio = p["triangles"] / count
            bpy.ops.object.modifier_apply(modifier=dec.name)
    bake(o, p.get("texture", 1024))
    parts.append(o)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
out_fbx = os.path.join(OUT, NAME + ".fbx")
lib.export_fbx(out_fbx)
print("HEIGHT %.2f" % spec["height"])
print("EXPORTED", out_fbx)
