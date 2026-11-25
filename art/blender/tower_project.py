"""Paint from our own views (the towers' version of art/blender/pet_project.py, 2026-11-23). A picture painted
separately never lines up with the model; a repaint of the model's own render does. So:

  views    renders the model from four sides into a 2 x 2 sheet: top left the picture's own angle (azimuth -75, 15
           degrees up, like art/blender/render_match.py), then the three sides 90 degrees on round the tower,
           orthographic, white ground; plus the picture's view once more at full size (<sheet>_front.png).
  (outside) the picture painter repaints both in the look of the target picture, everything kept in place
           (scripts/tower_paint.py).
  project  throws the paintings back onto the model: every texel takes the paint from the view that sees it best
           (the full-size picture view counts most); what no view sees keeps the baked paint.
  grade    multiplies every texel by the colour gain of its height band (scripts/tower_grade.py).

A model has several painted parts (tower_kit.bake_atlases): "Body" wears <T>.png and "Skin_<x>" wears <T>_<x>.png,
for every texture path T given below (the base, the output).

Run: blender -b -P tower_project.py -- views   model.fbx texture.png sheet.png
     blender -b -P tower_project.py -- project model.fbx texture.png painted_sheet.png out_texture.png [strength] [front_painted]
     blender -b -P tower_project.py -- grade   model.fbx texture.png gains.json out_texture.png"""
import json
import math
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
mode, fbx, tex_path = args[0], os.path.abspath(args[1]), os.path.abspath(args[2])
CELL = 512
ELEVATION = 15
AZ0 = float(os.environ.get("HTD_VIEW_AZ", "-75"))   # the picture's azimuth (the barricade's pictures show its +Y face: 105)
VIEWS = [("pic", AZ0), ("right", AZ0 + 90), ("back", AZ0 + 180), ("left", AZ0 + 270)]
SLOT = {"pic": (0, 0), "right": (1, 0), "back": (0, 1), "left": (1, 1)}   # column, row in the sheet

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
skins = [o for o in meshes if o.name.startswith(("Body", "Skin_"))] or meshes[:1]
for o in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.array([v.co[:] for o in meshes for v in o.data.vertices])
lo, hi = co.min(axis=0), co.max(axis=0)
center = (lo + hi) / 2
SPAN = float((hi - lo).max()) * 1.08


def skin_path(path, o):
    """the texture a part wears: Body -> path, Skin_roof -> path with _roof before .png"""
    if o.name.startswith("Skin_"):
        return path[:-4] + "_" + o.name.split(".")[0][5:] + ".png"
    return path


def basis(az):
    a, e = math.radians(az), math.radians(ELEVATION)
    d = np.array([math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)])   # towards the camera
    r = np.array([-math.sin(a), math.cos(a), 0.0])                                      # right in the picture
    u = np.cross(d, r)                                                                   # up in the picture
    return d, r, u


def save_png(path, arr):
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.dstack([arr, np.ones((h, w))])
    img = bpy.data.images.new("out", w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def load_png(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    return np.flipud(arr.reshape(h, w, 4))


def raster(p2, size, on_pixels):
    """rasterises triangles given 2D points (n x 3 x 2, pixel units); calls on_pixels(ys, xs, bary, index)"""
    for i in range(len(p2)):
        (x0, y0), (x1, y1), (x2, y2) = p2[i]
        minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(size - 1, math.ceil(max(x0, x1, x2))))
        miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(size - 1, math.ceil(max(y0, y1, y2))))
        if maxx < minx or maxy < miny:
            continue
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-12:
            continue
        ys, xs = np.mgrid[miny:maxy + 1, minx:maxx + 1]
        a = ((y1 - y2) * (xs + 0.5 - x2) + (x2 - x1) * (ys + 0.5 - y2)) / den
        b = ((y2 - y0) * (xs + 0.5 - x2) + (x0 - x2) * (ys + 0.5 - y2)) / den
        c = 1 - a - b
        inside = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
        if inside.any():
            on_pixels(ys[inside], xs[inside], np.stack([a[inside], b[inside], c[inside]], axis=1), i)


def triangles(o):
    mesh = o.data
    mesh.calc_loop_triangles()
    verts = np.array([v.co[:] for v in mesh.vertices])
    tri_v = np.array([lt.vertices[:] for lt in mesh.loop_triangles])
    return mesh, verts, tri_v


def texels(o, TS):
    """where every texel of a part's texture sits on the model, and which way the skin faces there"""
    mesh, verts, tri_v = triangles(o)
    uv = mesh.uv_layers.active.data
    tri_uv = np.array([[uv[li].uv[:] for li in lt.loops] for lt in mesh.loop_triangles])
    # flat face normals (the towers are faceted blocks and shingles; smooth vertex normals would leak across edges)
    fn = np.cross(verts[tri_v[:, 1]] - verts[tri_v[:, 0]], verts[tri_v[:, 2]] - verts[tri_v[:, 0]])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-9)
    pos = np.zeros((TS, TS, 3))
    nor = np.zeros((TS, TS, 3))
    used = np.zeros((TS, TS), dtype=bool)
    uv_px = np.stack([tri_uv[..., 0] * TS, (1 - tri_uv[..., 1]) * TS], axis=2)

    def fill(ys, xs, bary, i):
        pos[ys, xs] = bary @ verts[tri_v[i]]
        nor[ys, xs] = fn[i]
        used[ys, xs] = True

    raster(uv_px, TS, fill)
    return pos, nor, used


def fill_gaps(img, used, rounds=24):
    """Texels between the texture's islands are seen from far away (mip-maps average them in): the bake leaves them
    black, which darkened the whole tower on the phone (level 2, 2026-11-23). Grow the islands' colours outwards into
    the gaps, and give what is left the average colour."""
    out = img.copy()
    have = used.copy()
    for _ in range(rounds):
        acc = np.zeros_like(out[..., :3])
        cnt = np.zeros(have.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(have, dy, 0), dx, 1)
            acc += np.roll(np.roll(out[..., :3], dy, 0), dx, 1) * sh[..., None]
            cnt += sh
        grow = (~have) & (cnt > 0)
        out[..., :3][grow] = acc[grow] / cnt[grow][:, None]
        have = have | grow
    if (~have).any() and used.any():
        out[..., :3][~have] = img[..., :3][used].mean(axis=0)
    return out


def to_view(points, az):
    d, r, u = basis(az)
    rel = points - center
    return (rel @ r) / SPAN * CELL + CELL / 2, CELL / 2 - (rel @ u) / SPAN * CELL, -(rel @ d)


if mode == "views":
    out = os.path.abspath(args[3])
    for o in meshes:
        mat = bpy.data.materials.new("preview")
        mat.use_nodes = True
        nt = mat.node_tree
        emit = nt.nodes.new("ShaderNodeEmission")
        if o in skins:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(skin_path(tex_path, o))
            nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
        elif o.name.startswith("c_"):
            r, g, b = [int(v) / 255 for v in o.name.split(".")[0].split("_")[1:4]]
            emit.inputs["Color"].default_value = (r, g, b, 1)
        nt.links.new(emit.outputs["Emission"], nt.nodes.get("Material Output").inputs["Surface"])
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = scene.render.resolution_y = CELL
    scene.render.film_transparent = True
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = SPAN
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    from mathutils import Vector
    sheet = np.ones((CELL * 2, CELL * 2, 3))
    for name, az in VIEWS:
        d, _, _ = basis(az)
        cam.location = Vector(center + d * SPAN * 2)
        cam.rotation_euler = (Vector(center) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = out + "_tmp.png"
        bpy.ops.render.render(write_still=True)
        v = load_png(out + "_tmp.png")
        cx, cy = SLOT[name]
        sheet[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL] = v[:, :, :3] * v[:, :, 3:4] + (1 - v[:, :, 3:4])
        if name == "pic":   # the picture's own view once more at full size: the painter gives it the most detail
            scene.render.resolution_x = scene.render.resolution_y = CELL * 2
            scene.render.filepath = out[:-4] + "_front.png"
            bpy.ops.render.render(write_still=True)
            v = load_png(out[:-4] + "_front.png")
            save_png(out[:-4] + "_front.png", v[:, :, :3] * v[:, :, 3:4] + (1 - v[:, :, 3:4]))
            scene.render.resolution_x = scene.render.resolution_y = CELL
    os.remove(out + "_tmp.png")
    save_png(out, sheet)
    print("SHEET", out)

elif mode == "grade":
    gains = np.array(json.load(open(os.path.abspath(args[3])))["bands"])
    out = os.path.abspath(args[4])
    zlo, zhi = co[:, 2].min(), co[:, 2].max()
    n = len(gains)
    for o in skins:
        base = load_png(skin_path(tex_path, o))
        TS = base.shape[0]
        pos, _, used = texels(o, TS)
        z = np.where(used, pos[..., 2], (zlo + zhi) / 2)
        t = np.clip((zhi - z) / (zhi - zlo) * n - 0.5, 0, n - 1)
        k0 = np.floor(t).astype(int)
        k1 = np.minimum(k0 + 1, n - 1)
        w = (t - k0)[..., None]
        g = gains[k0] * (1 - w) + gains[k1] * w
        graded = base.copy()
        graded[..., :3] = np.clip(base[..., :3] * g, 0, 1)
        save_png(skin_path(out, o), fill_gaps(graded, used))
        print("GRADED", skin_path(out, o))

elif mode == "project":
    painted_path, out = os.path.abspath(args[3]), os.path.abspath(args[4])
    strength = float(args[5]) if len(args) > 5 else 1.0
    front_path = os.path.abspath(args[6]) if len(args) > 6 else None
    front = load_png(front_path)[:, :, :3] if front_path and os.path.exists(front_path) else None
    painted = load_png(painted_path)[:, :, :3]
    if painted.shape[0] != CELL * 2 or painted.shape[1] != CELL * 2:
        raise SystemExit("painted sheet must be %d px square (scripts/tower_paint.py resizes it)" % (CELL * 2))
    # what each view sees: the nearest surface of the whole model (all parts hide each other)
    zbufs = {}
    for name, az in VIEWS:
        zbuf = np.full((CELL, CELL), 1e9)
        for o in meshes:
            _, verts, tri_v = triangles(o)
            vx, vy, vz = to_view(verts, az)
            tz = vz[tri_v]

            def fill_depth(ys, xs, bary, i, tz=tz):
                np.minimum.at(zbuf, (ys, xs), bary @ tz[i])

            raster(np.stack([vx[tri_v], vy[tri_v]], axis=2), CELL, fill_depth)
        zbufs[name] = zbuf
    for o in skins:
        base = load_png(skin_path(tex_path, o))[:, :, :3]
        TS = base.shape[0]
        pos, nor, used = texels(o, TS)
        total = np.zeros((TS, TS, 3))
        weight = np.zeros((TS, TS))
        cover = np.zeros((TS, TS))   # how sure we are some view painted this texel (tops seen at 15 degrees count too)
        for name, az in VIEWS:
            d, _, _ = basis(az)
            cx, cy = SLOT[name]
            cell = painted[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL]
            px, py, pz = to_view(pos, az)
            ix = np.clip(px.astype(int), 0, CELL - 1)
            iy = np.clip(py.astype(int), 0, CELL - 1)
            colour = cell[iy, ix]
            if name == "pic" and front is not None:   # the full-size painting of the picture's view
                fs = front.shape[0] / CELL
                colour = front[np.clip((py * fs).astype(int), 0, front.shape[0] - 1), np.clip((px * fs).astype(int), 0, front.shape[1] - 1)]
            # (the kit's parts do not all wind the same way; the depth test already says what this view can see)
            facing = np.abs(nor @ d)
            seen = used & (pz <= zbufs[name][iy, ix] + SPAN * 0.01) & (facing > 0.2)
            not_ground = colour.min(axis=2) < 0.94
            w = np.where(seen & not_ground, np.clip(facing, 0, 1) ** 6 * (5.0 if name == "pic" else 1.0), 0.0)
            total += colour * w[..., None]
            weight += w
            cover = np.maximum(cover, np.where(seen & not_ground, np.clip(facing / 0.22, 0, 1), 0.0))
        mix = cover[..., None] * strength
        result = base * (1 - mix) + (total / np.maximum(weight, 1e-6)[..., None]) * mix
        result = np.where(used[..., None], result, base)
        save_png(skin_path(out, o), np.clip(fill_gaps(result, used), 0, 1))
        print("PROJECTED", skin_path(out, o), "covered %.0f%%" % (100 * (mix[..., 0][used] > 0.5).mean()))
