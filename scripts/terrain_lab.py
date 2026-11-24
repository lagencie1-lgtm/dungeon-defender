"""Terrain lab: runs a Luau snippet in an empty Studio place (edit mode) through Studio's connector and prints what
it returns; optionally saves a picture. For trying terrain recipes (channels, plateaus) with numbers before they
go into TerrainBuilder.
  python scripts/terrain_lab.py snippet.luau [--shot out.png x y z  lx ly lz] [--keep]
Each step must `return` a string. With --keep the lab Studio stays open (the lock too): the next call reuses it;
finish with  python scripts/terrain_lab.py --close
"""
import glob
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from studio_mcp import Studio  # noqa: E402

LOCK = os.path.join(ROOT, "tools", "studio.lock")
PLACE = os.path.join(ROOT, "tools", "terrain-lab.rbxlx")
MINE = "maps thread (terrain lab)"


def close():
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*terrain-lab*' } | Stop-Process -Force"])
    if os.path.exists(LOCK) and MINE in open(LOCK).read():
        os.remove(LOCK)


def connect():
    for _ in range(40):
        s = Studio()
        found = [x for x in s.studios() if "terrain-lab" in x.get("file", "")]
        if found:
            s.studio_id = found[0]["id"]
            return s
        s.close()
        time.sleep(4)
    raise SystemExit("Studio did not connect")


def main():
    if "--close" in sys.argv:
        close()
        return
    mine = os.path.exists(LOCK) and MINE in open(LOCK).read()
    if not mine:
        while os.path.exists(LOCK) and time.time() - os.path.getmtime(LOCK) < 25 * 60:
            print("waiting for the Studio lock:", open(LOCK).read().strip(), flush=True)
            time.sleep(30)
        open(PLACE, "w").write('<roblox version="4"></roblox>')
        studio = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe")), key=os.path.getmtime)[-1]
        subprocess.Popen([studio, PLACE])
    open(LOCK, "w").write(MINE + " " + time.strftime("%Y-%m-%dT%H:%M:%S"))
    try:
        s = connect()
        # the snippet may be cut into steps with lines "--#STEP" (each run as its own call, 1.5 s apart, because
        # fresh terrain only answers rays a moment later and a call must not yield); everything before the first
        # "--#STEP" is put in front of every step
        parts = open(sys.argv[1], encoding="utf-8").read().split("--#STEP")
        header, steps = (parts[0], parts[1:]) if len(parts) > 1 else ("", parts)
        for n, step in enumerate(steps):
            got = ""
            for _ in range(8):
                got = s.text("execute_luau", {"code": header + step, "datamodel_type": "Edit"})
                if got.strip() and "not ready" not in got.lower():
                    break
                time.sleep(5)
            print(got)
            time.sleep(1.5)
        if "--shot" in sys.argv:
            i = sys.argv.index("--shot")
            cam = [float(v) for v in sys.argv[i + 2:i + 8]]
            time.sleep(1.5)
            print(s.shot(sys.argv[i + 1], {"camera_position": cam[:3], "look_at_position": cam[3:]}))
        s.close()
    finally:
        if "--keep" not in sys.argv:
            close()


if __name__ == "__main__":
    main()
