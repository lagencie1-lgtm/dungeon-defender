"""Runs inside the Blender window that receives models from the Tripo website (the "Tripo Bridge" add-on).
Every model the bridge delivers is saved by itself as art/tripo-in/<time>_<name>.glb, so the game pipeline
(art/blender/tripo_clean.py) can pick it up without anybody downloading or exporting by hand.
Start Blender with:  blender --python art/blender/tripo_bridge_helper.py
"""
import os
import re
import time

import bpy

OUT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tripo-in"))
os.makedirs(OUT, exist_ok=True)
state = {"seen": None, "pending": {}, "saved": 0}


def roots_now():
    return {o.name for o in bpy.context.scene.objects if o.parent is None and o.type in ("MESH", "EMPTY", "ARMATURE")}


def family(obj):
    out = [obj]
    for child in obj.children_recursive:
        out.append(child)
    return out


def save(name):
    obj = bpy.context.scene.objects.get(name)
    if obj is None or not any(o.type == "MESH" for o in family(obj)):
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in family(obj):
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj
    clean = re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_") or "model"
    path = os.path.join(OUT, time.strftime("%H%M%S") + "_" + clean + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB")
    state["saved"] += 1
    print("HTD saved", path, flush=True)


def tick():
    try:
        now = roots_now()
        if state["seen"] is None:
            state["seen"] = now  # whatever is in the scene at the start is not ours
            return 2.0
        for name in now - state["seen"]:
            state["pending"].setdefault(name, 0)
        for name in list(state["pending"]):
            if name not in now:
                del state["pending"][name]
                continue
            state["pending"][name] += 1
            if state["pending"][name] >= 3:  # in the scene for a few seconds: the import has finished
                del state["pending"][name]
                state["seen"].add(name)
                save(name)
    except Exception as exc:  # keep the timer alive whatever happens
        print("HTD helper error:", exc, flush=True)
    return 2.0


bpy.app.timers.register(tick, first_interval=3.0, persistent=True)
print("HTD Tripo helper running, saving models to", OUT, flush=True)
