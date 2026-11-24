"""Reduce the repeated oak mesh while keeping its existing painted UV atlas.

Run: blender -b -P art/blender/tree_oak_mobile.py -- art/models/tree_oak.fbx out.fbx
"""

import math
from pathlib import Path
import sys

import bpy

sys.path.append(str(Path(__file__).resolve().parent))
import lib  # noqa: E402


def bounds(obj):
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return [(min(p[axis] for p in points), max(p[axis] for p in points)) for axis in range(3)]


def main():
    source, output = (Path(path).resolve() for path in sys.argv[sys.argv.index("--") + 1 :])
    if source == output:
        raise ValueError("The reduced mesh needs its own FBX path")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1 or meshes[0].name != "Body" or not meshes[0].data.uv_layers:
        raise ValueError("Expected one painted Body mesh")
    tree = meshes[0]
    before = lib.triangles(tree)
    original_bounds = bounds(tree)

    bpy.context.view_layer.objects.active = tree
    tree.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    pieces = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    bottom, top = original_bounds[2]
    crown_start = bottom + (top - bottom) * 0.57
    width = original_bounds[0][1] - original_bounds[0][0]
    for piece in pieces:
        x, _, z = bounds(piece)
        # The tapered bark and its UV seams need their original faces at eye level.
        if (z[0] + z[1]) / 2 < crown_start or x[1] - x[0] < width * 0.20:
            continue
        bpy.context.view_layer.objects.active = piece
        modifier = piece.modifiers.new("Mobile crown", "DECIMATE")
        modifier.ratio = 0.35
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    for piece in pieces:
        piece.select_set(True)
    bpy.context.view_layer.objects.active = tree
    bpy.ops.object.join()

    after = lib.triangles(tree)
    if after > before * 0.55 or not tree.data.uv_layers:
        raise ValueError("Triangle reduction lost the budget or the texture coordinates")
    for original, reduced in zip(original_bounds, bounds(tree)):
        span = original[1] - original[0]
        if any(not math.isclose(a, b, abs_tol=span * 0.035) for a, b in zip(original, reduced)):
            raise ValueError("Reduction changed the tree silhouette bounds by more than 3.5%")

    print(f"OAK_TRIANGLES {before} -> {after}")
    lib.export_fbx(str(output))


if __name__ == "__main__":
    main()
