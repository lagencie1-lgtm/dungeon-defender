"""Pose first (coordinator 2026-11-24: "measure pose and placement from the painting and set them directly before the
shape loop"): tries every value in a list for one size at a time (the weapon's yaw and pitch, the bow's roll ...),
outline only, against the level's painting from its own camera, and keeps the best; then the next size.
  python scripts/tower_pose.py <kind> <level> name=v1,v2,... [name=...]     -> art/blender/params/tower_<kind>_l<n>.json"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tower_fit as F  # noqa: E402


def main():
    kind, level = sys.argv[1], int(sys.argv[2])
    grids = [(a.split("=")[0], [float(v) for v in a.split("=")[1].split(",")]) for a in sys.argv[3:]]
    key = f"{kind}{level}"
    picture = os.path.join(F.ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png")
    params_path = os.path.join(F.ROOT, "art", "blender", "params", f"tower_{kind}_l{level}.json")
    builder = os.path.join(F.ROOT, "art", "blender", f"tower_{kind}_detail.py")
    os.makedirs(F.WORK, exist_ok=True)
    out = F.run([F.BLENDER, "-b", "-P", builder, "--", os.path.join(F.WORK, f"probe_{key}.fbx"), str(level)],
                env=dict(os.environ, HTD_FAST="1", HTD_PARAMS_ONLY="1"))
    params = json.loads(next(ln[7:] for ln in out.splitlines() if ln.startswith("PARAMS ")))
    if os.path.exists(params_path):
        params.update(json.load(open(params_path)))

    def iou(p):
        trial = os.path.join(F.WORK, f"{key}_pose.json")
        json.dump(p, open(trial, "w"))
        fbx = os.path.join(F.WORK, f"{key}_pose.fbx")
        render = os.path.join(F.WORK, f"{key}_pose.png")
        F.run([F.BLENDER, "-b", "-P", builder, "--", fbx, str(level), trial], env=dict(os.environ, HTD_FAST="1"))
        F.run([F.BLENDER, "-b", "-P", os.path.join(F.ROOT, "art", "blender", "render_match.py"), "--", fbx, render, "-75", "15", "512"])
        line = F.run([sys.executable, os.path.join(F.ROOT, "scripts", "match_score.py"), picture, render]).splitlines()[0]
        return float(line.split("IoU ")[1].split("%")[0])
    best = iou(params)
    print(f"start IoU {best:.1f}%", flush=True)
    for name, values in grids:
        scores = []
        for v in values:
            trial = dict(params, **{name: v})
            got = iou(trial)
            scores.append((got, v))
            if got > best:
                best, params = got, trial
        print(f"{name}: " + " ".join(f"{v:g}:{s:.1f}" for s, v in scores) + f"  -> {params[name]:g} ({best:.1f}%)", flush=True)
        json.dump(params, open(params_path, "w"), indent=1)
    print("POSE", params_path, f"{best:.1f}%")


if __name__ == "__main__":
    main()
