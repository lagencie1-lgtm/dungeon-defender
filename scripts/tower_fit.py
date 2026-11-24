"""The shape loop of the tower workflow (docs/tower-pipeline.md): builds the model's outline only (no paint), renders
it from the picture's angle and scores the outline overlap (IoU) with the picture; then tries each size a few percent
bigger and smaller and keeps what overlaps better, round after round with smaller steps. Writes the tuned sizes to a
json the builder reads.

Run: python scripts/tower_fit.py ranger 2 [rounds=4]
     -> art/blender/params/tower_ranger_l2.json (and prints IoU and the widths per round)"""
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
WORK = os.path.join(ROOT, "tools", "fit")

# size -> (rows from the top as a share of the height, how strongly it follows: radii scale with the width)
BANDS = {
    "ranger2": {"roof_r": (0.26, 0.36), "look_r": (0.45, 0.55), "wall_r1": (0.58, 0.66), "wall_r0": (0.74, 0.86),
                "foot_r": (0.9, 0.96)},
}
# the sizes the loop may change (by a few percent at a time, kept when the outline overlap gets better) and the
# rules a tower must keep (a wall never grows toward the top, the roof stays wider than the lookout)
SEARCH = {"ballista1": ["aim", "pitch", "foot_r", "leg_h", "leg_spread", "bow_w", "stock", "bend", "thick"],
          "ballista2": ["aim", "pitch", "foot_r", "leg_h", "leg_spread", "bow_w", "stock", "bend", "thick"],
          "ballista3": ["aim", "foot_r", "wall_r", "wall_h", "bow_w", "stock", "gap", "bend"],
          "storm1": ["foot_r", "foot_h", "stone_w", "stone_h", "stone_d"],
          "storm2": ["foot_r", "plinth_r", "plinth_h", "ob_w", "ob_top", "ob_h", "rod"],
          "storm3": ["foot_r", "plinth_r", "plinth_h", "ob_w", "ob_top", "ob_h", "orb_r"],
          "frost1": ["foot_r", "foot_h", "ped_r0", "ped_r1", "ped_h", "shard_h", "shard_r", "lean"],
          "frost2": ["foot_r", "foot_h", "ped_r0", "ped_r1", "ped_h", "shard_h", "shard_r", "ring_r"],
          "frost3": ["foot_r", "foot_h", "ped_r0", "ped_r1", "ped_h", "shard_h", "shard_r", "crown_r", "orb_r"],
          "flame1": ["aim", "tilt", "foot_r", "foot_h", "cradle", "barrel_r", "barrel_len", "barrel_z"],
          "flame2": ["aim", "tilt", "foot_r", "drum_r", "drum_h", "barrel_r", "barrel_len", "barrel_z"],
          "flame3": ["aim", "tilt", "foot_r", "drum_r", "drum_h", "barrel_r", "barrel_len", "barrel_z"],
          "ranger1": ["view_turn", "foot_r", "leg_half", "box_z0", "box_h", "box_half", "eave", "ridge", "roof_len", "roof_span"],
          "ranger2": ["roof_r", "roof_z0", "bell", "look_r", "wall_top", "wall_r0", "wall_r1", "foot_r", "foot_h", "post_top", "post_r", "flag_len", "flag_h"],
          "ranger3": ["roof_r", "roof_z0", "roof_z1", "look_r", "wall_top", "band_z", "wall_r0", "wall_r1", "wall2_r", "foot_r", "post_top"]}
RULES = {"ranger1": [lambda p: p["ridge"] > p["eave"] + 1, lambda p: p["box_half"] <= p["leg_half"] + 0.7],
         "ranger3": [lambda p: p["wall_r0"] >= p["wall_r1"] >= p["wall2_r"], lambda p: p["roof_r"] > p["look_r"],
                     lambda p: p["band_z"] < p["wall_top"] - 2, lambda p: p["post_top"] < p["roof_z0"] + 0.2],
         "ranger2": [lambda p: p["wall_r0"] >= p["wall_r1"], lambda p: p["roof_r"] > p["look_r"],
                     lambda p: p["foot_r"] >= p["wall_r0"], lambda p: p["post_top"] < p["roof_z0"] + 0.2]}


def widths(path, rows=100):
    im = Image.open(path)
    if im.mode == "RGBA":
        a = im.split()[3].load()
        solid = lambda x, y: a[x, y] > 40  # noqa: E731
    else:
        im = im.convert("RGB")
        p = im.load()
        solid = lambda x, y: min(p[x, y]) < 238  # noqa: E731
    w, h = im.size
    filled = [y for y in range(h) if any(solid(x, y) for x in range(0, w, 2))]
    top, bot = filled[0], filled[-1]
    out = []
    for k in range(rows):
        y = top + int((bot - top) * (k + 0.5) / rows)
        xs = [x for x in range(0, w, 2) if solid(x, y)]
        out.append((max(xs) - min(xs)) / (bot - top) if xs else 0.0)
    return out, bot - top


def run(cmd, env=None):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore", env=env)
    if r.returncode != 0 or "Traceback" in r.stdout:
        raise SystemExit(r.stdout[-2000:] + r.stderr[-1000:])
    return r.stdout


def main():
    kind, level = sys.argv[1], int(sys.argv[2])
    rounds = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    key = f"{kind}{level}"
    picture = os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png")
    params_path = os.path.join(ROOT, "art", "blender", "params", f"tower_{kind}_l{level}.json")
    os.makedirs(os.path.dirname(params_path), exist_ok=True)
    os.makedirs(WORK, exist_ok=True)
    builder = os.path.join(ROOT, "art", "blender", f"tower_{kind}_detail.py")
    out = run([BLENDER, "-b", "-P", builder, "--", os.path.join(WORK, "probe.fbx"), str(level), "--print-params"],
              env=dict(os.environ, HTD_FAST="1", HTD_PARAMS_ONLY="1"))
    params = json.loads(next(ln[7:] for ln in out.splitlines() if ln.startswith("PARAMS ")))
    if os.path.exists(params_path):
        params.update(json.load(open(params_path)))
    cache = {}

    def iou(p):
        k = json.dumps(p, sort_keys=True)
        if k not in cache:
            trial = os.path.join(WORK, f"{key}_trial.json")
            json.dump(p, open(trial, "w"))
            fbx = os.path.join(WORK, f"{key}.fbx")
            render = os.path.join(WORK, f"{key}_trial.png")
            run([BLENDER, "-b", "-P", builder, "--", fbx, str(level), trial], env=dict(os.environ, HTD_FAST="1"))
            run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", "render_match.py"), "--", fbx, render, "-75", "15", "512"])
            line = run([sys.executable, os.path.join(ROOT, "scripts", "match_score.py"), picture, render]).splitlines()[0]
            cache[k] = float(line.split("IoU ")[1].split("%")[0])
        return cache[k]

    best = iou(params)
    print(f"start IoU {best:.1f}%", flush=True)
    step = 0.06
    for rnd in range(rounds):
        moved = []
        for name in SEARCH[key]:
            for sign in (1, -1):
                trial = dict(params)
                trial[name] = round(params[name] * (1 + sign * step), 3)
                if not all(rule(trial) for rule in RULES.get(key, [])):
                    continue
                got = iou(trial)
                if got > best + 0.05:
                    best, params = got, trial
                    moved.append(f"{name} {'+' if sign > 0 else '-'}{step * 100:.0f}%")
                    break
        print(f"round {rnd}: IoU {best:.1f}%  " + (", ".join(moved) or f"no move at {step * 100:.0f}%"), flush=True)
        json.dump(params, open(params_path, "w"), indent=1)
        if not moved:
            step /= 2
            if step < 0.012:
                break
    json.dump(params, open(params_path, "w"), indent=1)
    print("PARAMS", params_path)


if __name__ == "__main__":
    main()
