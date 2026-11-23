"""One full round of the tower workflow for one level (docs/tower-pipeline.md): bake the kit build with its tuned
sizes, let Codex repaint the model's own views (scripts/tower_paint.py), sharpen and colour-match per height band
(scripts/tower_grade.py), and log the round (scripts/tower_round.py).
  python scripts/tower_run.py <kind> <level> <round> "what changed"
  python scripts/tower_run.py --queue <kind:level> ...   each one after its shape loop (tools/fit/fit_<kind><level>.log)
                                                         has written PARAMS; one painter job at a time
Outputs: tools/towers/tower_<kind>_l<level>.fbx and its paints."""
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
WORK = os.path.join(ROOT, "tools", "towers")


def painter_busy():
    out = subprocess.run(["powershell", "-NoProfile", "-c",
                          "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | ? { $_.CommandLine -match 'pet_paint' } | Select -Expand ProcessId"],
                         capture_output=True, text=True).stdout.strip()
    return bool(out)


def run(kind, level, rnd, note):
    os.makedirs(WORK, exist_ok=True)
    fbx = os.path.join(WORK, f"tower_{kind}_l{level}.fbx")
    picture = os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{level}.png")
    b = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "art", "blender", f"tower_{kind}_detail.py"), "--", fbx, str(level)],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    for ln in b.stdout.splitlines():
        if ln.startswith(("MUZZLE", "HEIGHT", "TRIANGLES", "ATLAS")) or "Traceback" in ln or "Error:" in ln:
            print(f"[{kind} {level}] {ln}", flush=True)
    while painter_busy():
        time.sleep(20)
    subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "tower_paint.py"), fbx, picture])
    subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "tower_grade.py"), fbx, picture], capture_output=True)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "tower_round.py"), kind, str(level), str(rnd), fbx, note],
                       capture_output=True, text=True)
    print(f"[{kind} {level}] " + " | ".join(r.stdout.splitlines()[1:3]), flush=True)


def main():
    if sys.argv[1] == "--queue":
        jobs = [a.split(":") for a in sys.argv[2:]]
        done = set()
        while len(done) < len(jobs):
            for kind, level in jobs:
                if (kind, level) in done:
                    continue
                log = os.path.join(ROOT, "tools", "fit", f"fit_{kind}{level}.log")
                if os.path.exists(log) and "PARAMS" in open(log, encoding="utf-8", errors="ignore").read():
                    run(kind, int(level), 1, "kit build, shape loop, Codex repaint of its own views, sharpen, colour grade")
                    done.add((kind, level))
            time.sleep(30)
        print("QUEUE DONE", flush=True)
    else:
        run(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4])


if __name__ == "__main__":
    main()
