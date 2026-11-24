"""Paint projection for pets (2026-11-23): gives a code-built pet the hand-painted surface of its target picture.

Step 1 "views":   renders the model straight from the front, left, back and right into one 2 x 2 sheet
                  (front | left / back | right), white ground, no perspective.
Step 2 (outside): the picture painter repaints that sheet in the style of the target picture, keeping every view
                  where it is (scripts/pet_paint.py).
Step 3 "project": throws the painted sheet back onto the model from the same four sides. Every point of the skin
                  takes the paint from the side that sees it best; points no side sees well keep the baked paint.

Run: blender -b -P pet_project.py -- views   model.fbx texture.png sheet.png
     blender -b -P pet_project.py -- project model.fbx texture.png painted_sheet.png out_texture.png [strength] [noface]
The model file is not changed: only a new texture is written.
"""
import math
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
mode, fbx, tex_path = args[0], os.path.abspath(args[1]), os.path.abspath(args[2])
CELL = 512
HALO = 12   # texels of plain paint kept round eyes and mouth
NEAR = 46   # texels round eyes and mouth in which dark painter leftovers are removed
# name, direction from the pet to the camera, the world axis that runs to the right in the picture (+ sign)
VIEWS = [("front", (0, -1, 0), (1, 0, 0)), ("left", (1, 0, 0), (0, 1, 0)), ("back", (0, 1, 0), (-1, 0, 0)), ("right", (-1, 0, 0), (0, -1, 0))]
SLOT = {"front": (0, 0), "left": (1, 0), "back": (0, 1), "right": (1, 1)}   # column, row in the sheet

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = ([o for o in meshes if o.name.startswith("Body")] or meshes)[0]
for o in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.array([v.co[:] for o in meshes for v in o.data.vertices])
lo, hi = co.min(axis=0), co.max(axis=0)
center = (lo + hi) / 2
SPAN = float((hi - lo).max()) * 1.12   # one view shows SPAN units across


def save_png(path, arr):
    """arr: H x W x 3 or 4, floats 0..1, row 0 at the top"""
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


if mode == "views":
    out = os.path.abspath(args[3])
    image = bpy.data.images.load(tex_path)
    mat = bpy.data.materials.new("preview")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    emit = mat.node_tree.nodes.new("ShaderNodeEmission")
    mat.node_tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
    mat.node_tree.links.new(emit.outputs["Emission"], mat.node_tree.nodes.get("Material Output").inputs["Surface"])
    body.data.materials.clear()
    body.data.materials.append(mat)
    body_co = np.array([v.co[:] for v in body.data.vertices])
    for o in meshes:
        if o is not body:
            # A glowing piece that FLOATS beside the pet (the sparkles of the rare pets) is left out of the sheet: the
            # painter drops or moves it, and since each painted view is fitted to the model by its outer box, a
            # sparkle outside the body threw the whole front and back view off (gold from the hooves on the legs).
            gco = np.array([v.co[:] for v in o.data.vertices])
            if len(gco) and np.sqrt(((gco[:, None, :] - body_co[None, :, :]) ** 2).sum(axis=2)).min() > 0.05:
                o.hide_render = True
        if o is not body and o.name.startswith("c_"):
            r, g, b = [int(v) / 255 for v in o.name.split(".")[0].split("_")[1:4]]
            gm = bpy.data.materials.new("glow")
            gm.use_nodes = True
            em = gm.node_tree.nodes.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = (r, g, b, 1)
            gm.node_tree.links.new(em.outputs["Emission"], gm.node_tree.nodes.get("Material Output").inputs["Surface"])
            o.data.materials.clear()
            o.data.materials.append(gm)
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
    target = bpy.data.objects.new("target", None)
    target.location = center
    scene.collection.objects.link(target)
    track = cam.constraints.new("TRACK_TO")
    track.target = target
    scene.camera = cam
    sheet = np.ones((CELL * 2, CELL * 2, 3))
    for name, d, _ in VIEWS:
        cam.location = [center[i] + d[i] * 20 for i in range(3)]
        scene.render.filepath = out + "_tmp.png"
        bpy.ops.render.render(write_still=True)
        v = load_png(out + "_tmp.png")
        rgb = v[:, :, :3] * v[:, :, 3:4] + (1 - v[:, :, 3:4])
        cx, cy = SLOT[name]
        sheet[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL] = rgb
    os.remove(out + "_tmp.png")
    save_png(out, sheet)
    print("SHEET", out)

elif mode == "project":
    painted_path, out = os.path.abspath(args[3]), os.path.abspath(args[4])
    strength = float(args[5]) if len(args) > 5 else 1.0
    # views the painter got wrong (scripts/pet_paint.py measures the overlap) are left out: that side keeps the
    # plain colours in the painter's tone, which is cleaner than paint smeared over the wrong parts
    skip = next((a[5:].split(",") for a in args[6:] if a.startswith("skip=")), [])
    if "noface" in args[6:]:
        # the painter got a pet without a face and painted none: nothing of its own to hide round the eyes and mouth,
        # so the paint may run right up to them
        HALO, NEAR = 2, 0
    base = load_png(tex_path)[:, :, :3]
    TS = base.shape[0]
    painted = load_png(painted_path)[:, :, :3]
    if painted.shape[0] != painted.shape[1] or painted.shape[0] % (CELL * 2):
        raise SystemExit("painted sheet must be square, %d px or a multiple (scripts/pet_paint.py resizes it)" % (CELL * 2))
    CELL = painted.shape[0] // 2   # a doubled sheet (pet_paint --crisp) is sampled at its full size

    mesh = body.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    verts = np.array([v.co[:] for v in mesh.vertices])
    vnorm = np.array([v.normal[:] for v in mesh.vertices])
    tris = [(lt.vertices[:], [uv[li].uv[:] for li in lt.loops]) for lt in mesh.loop_triangles]

    def raster(p2, values, size, on_pixels):
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

    # where every texel of the texture sits on the model, and which way the skin faces there
    pos = np.zeros((TS, TS, 3))
    nor = np.zeros((TS, TS, 3))
    used = np.zeros((TS, TS), dtype=bool)
    tri_v = np.array([t[0] for t in tris])
    uv_px = np.array([[(u * TS, (1 - v) * TS) for u, v in t[1]] for t in tris])

    def fill_texel(ys, xs, bary, i):
        pos[ys, xs] = bary @ verts[tri_v[i]]
        nor[ys, xs] = bary @ vnorm[tri_v[i]]
        used[ys, xs] = True

    raster(uv_px, None, TS, fill_texel)
    nlen = np.linalg.norm(nor, axis=2, keepdims=True)
    nor = nor / np.maximum(nlen, 1e-6)

    def to_view(points, d, right):
        """world points -> (px, py, depth) in one view cell"""
        d, right = np.array(d, dtype=float), np.array(right, dtype=float)
        rel = points - center
        px = (rel @ right) / SPAN * CELL + CELL / 2
        py = CELL / 2 - rel[..., 2] / SPAN * CELL
        return px, py, -(rel @ d)      # smaller depth = nearer to the camera

    def painter_tone(plain, paint, good, B=10):
        """The plain bake shifted to the painter's colours: a small 3D table 'plain colour -> the average change the
        painter made to it', learnt where the paint landed well and read back smoothly (like a colour grade)."""
        acc = np.zeros((B, B, B, 3))
        cnt = np.zeros((B, B, B))
        cell = np.rint(np.clip(plain[good], 0, 1) * (B - 1)).astype(int)
        np.add.at(acc, (cell[:, 0], cell[:, 1], cell[:, 2]), paint[good] - plain[good])
        np.add.at(cnt, (cell[:, 0], cell[:, 1], cell[:, 2]), 1.0)
        have = cnt >= 40
        delta = np.where(have[..., None], acc / np.maximum(cnt, 1)[..., None], 0.0)
        for _ in range(B):   # colours the painter never touched take the change of their nearest neighbours
            if have.all() or not have.any():
                break
            a2 = np.zeros_like(delta)
            c2 = np.zeros(have.shape)
            for ax in range(3):
                for sh in (1, -1):
                    sa, sc = np.roll(delta * have[..., None], sh, ax), np.roll(have.astype(float), sh, ax)
                    edge = [slice(None)] * 3
                    edge[ax] = 0 if sh == 1 else -1
                    sa[tuple(edge)] = 0
                    sc[tuple(edge)] = 0
                    a2 += sa
                    c2 += sc
            new = (~have) & (c2 > 0)
            delta[new] = a2[new] / c2[new][:, None]
            have = have | new
        g = np.clip(plain, 0, 1) * (B - 1)
        i0 = np.clip(np.floor(g).astype(int), 0, B - 2)
        f = g - i0
        shift = np.zeros_like(plain)
        for dr in (0, 1):
            for dg in (0, 1):
                for db in (0, 1):
                    w = (f[..., 0] if dr else 1 - f[..., 0]) * (f[..., 1] if dg else 1 - f[..., 1]) * (f[..., 2] if db else 1 - f[..., 2])
                    shift += delta[i0[..., 0] + dr, i0[..., 1] + dg, i0[..., 2] + db] * w[..., None]
        return np.clip(plain + shift, 0, 1)

    total = np.zeros((TS, TS, 3))
    weight = np.zeros((TS, TS))
    for name, d, right in VIEWS:
        if name in skip:
            continue
        # what this side really sees: nearest surface per pixel
        zbuf = np.full((CELL, CELL), 1e9)
        vx, vy, vz = to_view(verts, d, right)
        p2 = np.stack([np.stack([vx[tri_v], vy[tri_v]], axis=2)], axis=0)[0]
        tz = vz[tri_v]

        def fill_depth(ys, xs, bary, i):
            z = bary @ tz[i]
            np.minimum.at(zbuf, (ys, xs), z)

        raster(p2, None, CELL, fill_depth)
        cx, cy = SLOT[name]
        cell = painted[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL].copy()
        # the painter draws a dark outline round every view; projected, it would lie on the skin as stray lines.
        # So the rim (the outer RIM pixels of the painted shape) is refilled from the paint just inside it.
        RIM = 7 * CELL // 512
        ground = cell.min(axis=2) >= 0.94
        solid = ~ground
        for _ in range(RIM):   # shrink the shape
            m = solid.copy()
            m[1:, :] &= solid[:-1, :]; m[:-1, :] &= solid[1:, :]; m[:, 1:] &= solid[:, :-1]; m[:, :-1] &= solid[:, 1:]
            solid = m
        filled = solid.copy()
        for _ in range(RIM + 4):   # grow the inner paint back out over the rim (and a little beyond)
            acc = np.zeros_like(cell)
            cnt = np.zeros(cell.shape[:2])
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                src = np.roll(np.roll(filled, dy, 0), dx, 1)
                acc += np.roll(np.roll(cell, dy, 0), dx, 1) * src[..., None]
                cnt += src
            new = (~filled) & (cnt > 0)
            cell[new] = acc[new] / cnt[new][:, None]
            filled |= new
        cell[~filled] = 1.0
        px, py, pz = to_view(pos, d, right)
        ix = np.clip(px.astype(int), 0, CELL - 1)
        iy = np.clip(py.astype(int), 0, CELL - 1)
        facing = nor @ np.array(d, dtype=float)
        seen = used & (pz <= zbuf[iy, ix] + SPAN * 0.012) & (facing > 0.3)
        colour = cell[iy, ix]
        not_ground = colour.min(axis=2) < 0.94          # the painter's white ground is not paint
        # one side wins clearly (blending two paintings of the same eye gives a ghost face), and the front
        # painting owns everything it can see well: that is where the face is
        w = np.where(seen & not_ground, np.clip(facing, 0, 1) ** 8 * (6.0 if name == "front" else 1.0), 0.0)
        total += colour * w[..., None]
        weight += w
    mix = np.clip(weight * 3.0, 0, 1)[..., None] * strength
    paint = total / np.maximum(weight, 1e-6)[..., None]
    # Spots no side could paint (behind a flower, between two views, round the eyes) used to keep the flat colour of
    # the plain bake and showed as patches of another tone. They now get the painter's tone for that colour.
    toned = painter_tone(base, paint, used & (weight * 3.0 >= 1.0))
    result = toned * (1 - mix) + paint * mix
    # On near-white skin, paint that is much darker than the skin is one of the painter's outlines that landed a
    # little off (between the legs, along the hair), not fur: it showed as orange-brown scratches on the Unicorn.
    # Shading on white fur is never that dark, so those texels go back to the skin's own tone.
    lum_ = lambda c: c[..., 0] * 0.3 + c[..., 1] * 0.59 + c[..., 2] * 0.11  # noqa: E731
    # (Only really dark paint counts: a first version took everything a quarter darker than the skin, which also tore
    # white holes into pink ears, blush and gold cuffs.)
    stray = (lum_(toned) > 0.78) & (lum_(result) < 0.5)
    for _ in range(2):
        m = stray.copy()
        m[1:, :] |= stray[:-1, :]; m[:-1, :] |= stray[1:, :]; m[:, 1:] |= stray[:, :-1]; m[:, :-1] |= stray[:, 1:]
        stray = m & (lum_(toned) > 0.78)
    result = np.where(stray[..., None], toned, result)
    # fill the gaps between UV islands so texture filtering never pulls in grey
    result = np.where(used[..., None], result, toned)
    # eyes and mouth keep their crisp baked shapes (see petkit.finish: the _keep.png mask)
    keep_path = tex_path.replace("_base.png", "_keep.png")
    if os.path.exists(keep_path):
        k = load_png(keep_path)[:, :, 0]
        if k.shape[0] == TS:
            # a halo round the kept shapes also keeps the plain paint: the painter never puts its own eyes and mouth
            # exactly where ours are, and without the halo their leftovers show as dark smudges beside the eyes
            halo = k.copy()
            for _ in range(HALO):
                m = halo.copy()
                m[1:, :] = np.maximum(m[1:, :], halo[:-1, :]); m[:-1, :] = np.maximum(m[:-1, :], halo[1:, :])
                m[:, 1:] = np.maximum(m[:, 1:], halo[:, :-1]); m[:, :-1] = np.maximum(m[:, :-1], halo[:, 1:])
                halo = m
            for _ in range(6):   # soften the outer edge of the halo
                halo = (halo + np.roll(halo, 1, 0) + np.roll(halo, -1, 0) + np.roll(halo, 1, 1) + np.roll(halo, -1, 1)) / 5
            halo = np.maximum(halo, k)
            # further out (NEAR texels), only DARK leftovers are removed: where the painter's paint is much darker
            # than our plain paint it is the rim or pupil of an eye it drew in the wrong place, not fur
            near = k.copy()
            for _ in range(NEAR):
                m = near.copy()
                m[1:, :] = np.maximum(m[1:, :], near[:-1, :]); m[:-1, :] = np.maximum(m[:-1, :], near[1:, :])
                m[:, 1:] = np.maximum(m[:, 1:], near[:, :-1]); m[:, :-1] = np.maximum(m[:, :-1], near[:, 1:])
                near = m
            lum = lambda c: c[..., 0] * 0.3 + c[..., 1] * 0.59 + c[..., 2] * 0.11  # noqa: E731
            dark = (near > 0.5) & (lum(result) < 0.62 * lum(base))
            for _ in range(2):   # take the soft edge of each leftover with it
                m = dark.copy()
                m[1:, :] |= dark[:-1, :]; m[:-1, :] |= dark[1:, :]; m[:, 1:] |= dark[:, :-1]; m[:, :-1] |= dark[:, 1:]
                dark = m & (near > 0.5)
            halo = np.maximum(halo, dark.astype(np.float32))
            result = result * (1 - halo[..., None]) + toned * halo[..., None]
            result = result * (1 - k[..., None]) + base * k[..., None]   # the eyes and mouth themselves: untouched
    save_png(out, np.clip(result, 0, 1))
    print("PROJECTED", out, "covered %.0f%%" % (100 * (mix[..., 0][used] > 0.5).mean()))
