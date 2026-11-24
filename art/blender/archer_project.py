"""Packs the archer's painted parts into one mesh with one picture, so the pets' painterly projection
(art/blender/pet_project.py, used unchanged) can paint him: it works on one mesh ("Body") and one texture.

  blender -b -P archer_project.py -- pack <archer.fbx> <out_dir> [noarms]
      Head, Body, ArmR and ArmL (the bow and quiver stay out: they keep their own paint) become one mesh "Body" whose
      texture layout is the four parts' own layouts side by side in a 2 x 2 atlas (Head top left, Body top right,
      ArmR bottom left, ArmL bottom right, 1024 px each). Writes <out_dir>/archer_pack.fbx, archer_pack_base.png
      (the parts' plain bakes in that atlas) and archer_pack_keep.png (the face marks: eyes, brows, mouth).
  blender -b -P archer_project.py -- pad <archer_pack.fbx> <atlas.png>
      The texels between texture islands are filled outward from the islands' own (painted) edge, 24 px deep
      (pet_project fills them with the plain colour; sampled at a seam they showed as a line).
The atlas is cut back into the parts' pictures by scripts/archer_paint.py (same cells)."""
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
args = sys.argv[sys.argv.index("--") + 1:]
mode, fbx, out = args[0], os.path.abspath(args[1]), os.path.abspath(args[2])
NAME = "ranger_archer"
CELLS = {"Head": (0, 0), "Body": (1, 0), "ArmR": (0, 1), "ArmL": (1, 1)}   # column, row from the top left
C = 1024
NOARMS = "noarms" in args[3:]   # pack Head and Body only (the painter then sees the torso's sides the arms hide)


def load(path, size):
    im = bpy.data.images.load(path)
    if im.size[0] != size:
        im.scale(size, size)
    a = np.empty(size * size * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    return np.flipud(a.reshape(size, size, 4))


def save(path, arr):
    h, w = arr.shape[:2]
    im = bpy.data.images.new("out", w, h, alpha=True)
    im.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()


if mode == "pack":
    os.makedirs(out, exist_ok=True)
    src = os.path.dirname(fbx)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    atlas = np.ones((2 * C, 2 * C, 4), dtype=np.float32)
    keep = np.zeros((2 * C, 2 * C, 4), dtype=np.float32)
    keep[..., 3] = 1
    parts = []
    for o in list(bpy.context.scene.objects):
        base = o.name.split(".")[0]
        if o.type != "MESH" or base not in CELLS or (NOARMS and base.startswith("Arm")):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        cx, cy = CELLS[base]
        uv = o.data.uv_layers.active.data
        for d in uv:   # the part's own layout into its cell (v runs up: row 0 is the top half)
            d.uv = ((d.uv[0] + cx) / 2, (d.uv[1] + (1 - cy)) / 2)
        atlas[cy * C:(cy + 1) * C, cx * C:(cx + 1) * C] = load(os.path.join(src, f"{NAME}_{base.lower()}_paint.png"), C)
        kp = os.path.join(src, f"{NAME}_{base.lower()}_keep.png")
        if os.path.exists(kp):
            keep[cy * C:(cy + 1) * C, cx * C:(cx + 1) * C, :3] = load(kp, C)[..., :3]
        o.data.materials.clear()
        parts.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = "Body"
    joined.data.name = "Body"
    save(os.path.join(out, "archer_pack_base.png"), atlas)
    save(os.path.join(out, "archer_pack_keep.png"), keep)
    import lib  # noqa: E402
    lib.export_fbx(os.path.join(out, "archer_pack.fbx"))
    print("PACKED", out, len(parts), "parts")


if mode == "pad":
    atlas_path = out
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    o = [m for m in bpy.context.scene.objects if m.type == "MESH"][0]
    img = load(atlas_path, bpy.data.images.load(atlas_path).size[0])
    T = img.shape[0]
    used = np.zeros((T, T), dtype=bool)
    me = o.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    for lt in me.loop_triangles:
        p = np.array([(uv[li].uv[0] * T, (1 - uv[li].uv[1]) * T) for li in lt.loops])
        x0, x1 = int(max(0, np.floor(p[:, 0].min()))), int(min(T - 1, np.ceil(p[:, 0].max())))
        y0, y1 = int(max(0, np.floor(p[:, 1].min()))), int(min(T - 1, np.ceil(p[:, 1].max())))
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        a = ((by - cy) * (xs + 0.5 - cx) + (cx - bx) * (ys + 0.5 - cy)) / den
        b = ((cy - ay) * (xs + 0.5 - cx) + (ax - cx) * (ys + 0.5 - cy)) / den
        inside = (a >= -0.01) & (b >= -0.01) & (1 - a - b >= -0.01)
        used[ys[inside], xs[inside]] = True
    rgb = img[..., :3].copy()
    known = used.copy()
    for _ in range(24):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            src = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * src[..., None]
            cnt += src
        new = (~known) & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]
        known |= new
    img[..., :3] = rgb
    save(atlas_path, img)
    print("PADDED", atlas_path, "%.0f%% of the atlas is islands" % (100 * used.mean()))
