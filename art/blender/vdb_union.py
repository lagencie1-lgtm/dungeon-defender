"""Smooth union of closed meshes through OpenVDB level sets (the same smooth-minimum petkit's clay uses: two shapes
pressed together like clay, a fillet instead of a crease). petkit's union only takes its own formula shapes (balls,
cones), not meshes; this takes any closed meshes.
  smooth_union([(points, faces), ...], voxel, k) -> (points, faces)   faces: lists of 3 or 4 vertex indices"""
import numpy as np


def _level_set(points, faces, voxel, band):
    import openvdb
    tris = np.array([f for f in faces if len(f) == 3], dtype=np.uint32).reshape(-1, 3)
    quads = np.array([f for f in faces if len(f) == 4], dtype=np.uint32).reshape(-1, 4)
    xf = openvdb.createLinearTransform(voxelSize=voxel)
    return openvdb.FloatGrid.createLevelSetFromPolygons(np.asarray(points, dtype=np.float32), triangles=tris, quads=quads,
                                                       transform=xf, halfWidth=band)


def smooth_union(shapes, voxel=0.012, k=0.06, band=4.0):
    """shapes: [(points, faces)]; k: how far they melt into each other (world units)"""
    import openvdb
    grids = [_level_set(p, f, voxel, band) for p, f in shapes]
    boxes = [g.evalActiveVoxelBoundingBox() for g in grids]
    pad = int(np.ceil(k / voxel)) + 6
    lo = np.min([b[0] for b in boxes], axis=0) - pad
    hi = np.max([b[1] for b in boxes], axis=0) + pad
    dims = tuple(int(v) for v in (hi - lo + 1))
    D = None
    for g in grids:
        a = np.full(dims, g.background, dtype=np.float32)
        g.copyToArray(a, ijk=tuple(int(v) for v in lo))
        if D is None:
            D = a
            continue
        # petkit's smooth minimum (art/blender/petkit.py _clay_field): h = clamp(0.5 + 0.5 (d1 - d2) / k)
        h = np.clip(0.5 + 0.5 * (D - a) / k, 0, 1)
        D = D * (1 - h) + a * h - k * h * (1 - h)
    out = openvdb.FloatGrid(background=float(band * voxel))
    out.copyFromArray(np.clip(D, -band * voxel, band * voxel).astype(np.float32), ijk=tuple(int(v) for v in lo))
    out.transform = openvdb.createLinearTransform(voxelSize=voxel)
    out.gridClass = openvdb.GridClass.LEVEL_SET
    pts, tris, quads = out.convertToPolygons(isovalue=0.0, adaptivity=0.0)
    faces = [tuple(q) for q in quads.tolist()] + [tuple(t) for t in tris.tolist()]
    return np.asarray(pts), faces
