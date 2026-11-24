"""Films the map tour (test/maptour) in Roblox Studio at phone size and cuts one still per camera view.

  python scripts/map_tour.py <name> [--root <folder>] [--only CursedForest] [--limit 420]

<name> labels the take (cycle1, before ...). Output: reviews/maps/img/<name>-<Map>-<view>.jpg, one sheet per map
(<name>-<Map>-sheet.jpg), the test's own lines in reviews/maps/<name>.log.txt.
--root builds the place from another copy of the repo (a clean export of an older commit for "before" pictures);
the tour scripts are always taken from this checkout.
Takes tools/studio.lock for the run and closes only its own Studio window. The HTD_Film plugin (test/film) sees the
"htd-film-phonehq" in the place name, switches Studio to an iPhone 13 in landscape and starts the play test.
"""
import ctypes
import glob
import os
import re
import shutil
import subprocess
import sys
import time
from ctypes import wintypes

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCK = os.path.join(ROOT, "tools", "studio.lock")
OUT = os.path.join(ROOT, "reviews", "maps")
NAME = "htd-film-pc-maptour" if "--pc" in sys.argv else "htd-film-phonehq-maptour"


def arg(flag, default=None):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def window_title(part):
    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    def each(hwnd, _):
        buf = ctypes.create_unicode_buffer(400)
        user32.GetWindowTextW(hwnd, buf, 400)
        if part in buf.value and user32.IsWindowVisible(hwnd):
            found.append(buf.value)
        return True

    user32.EnumWindows(each, 0)
    return found[0] if found else None


def crop_view(im):
    """Cuts a frame of the Studio window down to the game view: the phone's screen in the device simulator (the
    only bright block in a dark panel), or the 3D view in pc mode."""
    import numpy as np
    a = np.asarray(im).astype(int)
    h, w = a.shape[:2]
    if "--pc" in sys.argv:
        # the viewport is the big area left of the Explorer: between the toolbar and the status bar
        return im.crop((2, int(h * 0.125), int(w * 0.792), int(h * 0.948)))
    # the simulated phone has a black rim (darker than Studio's own dark grey) on every map: its outline is the
    # box of near-black pixels in the view panel; the screen lies one rim width inside it
    top = int(h * 0.12)
    area = a[top:int(h * 0.95), :int(w * 0.79)]
    black = area.max(axis=2) < 14
    cols = np.where(black.sum(axis=0) > 40)[0]
    rows = np.where(black.sum(axis=1) > 40)[0]
    if len(cols) == 0 or len(rows) == 0:
        return im
    rim = round((cols[-1] - cols[0]) * 0.0222)
    return im.crop((int(cols[0]) + rim, int(rows[0]) + top + rim, int(cols[-1]) + 1 - rim, int(rows[-1]) + top + 1 - rim))


def cut_stills(take, clip, lines, start_ms):
    """one still per "shot" mark, cut to the game view, and a sheet per map"""
    from PIL import Image
    ffmpeg = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    shots = {}
    for l in lines:
        m = re.match(r"\[MAPTOUR\] (\d+) shot (\S+) (\S+)", l)
        if m:
            shots.setdefault(m.group(2), []).append((m.group(3), (int(m.group(1)) - start_ms) / 1000.0))
    for map_id, views in shots.items():
        ims, names = [], []
        for view, t in views:
            still = os.path.join(OUT, "img", f"{take}-{map_id}-{view}.jpg")
            raw = os.path.join(ROOT, "tools", "maptour", "frame.png")
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-ss", f"{max(0, t):.2f}", "-i", clip, "-frames:v", "1", raw])
            if os.path.exists(raw):
                im = crop_view(Image.open(raw).convert("RGB"))
                im.save(still, quality=93)
                ims.append(im)
                names.append(view)
                os.remove(raw)
        if not ims:
            continue
        w = 640
        ims = [im.resize((w, int(im.height * w / im.width)), Image.LANCZOS) for im in ims]
        cols = 3
        rows = (len(ims) + cols - 1) // cols
        h = max(im.height for im in ims)
        sheet = Image.new("RGB", (cols * w, rows * h), (20, 20, 20))
        for i, im in enumerate(ims):
            sheet.paste(im, ((i % cols) * w, (i // cols) * h))
        sheet.save(os.path.join(OUT, "img", f"{take}-{map_id}-sheet.jpg"), quality=90)
        print("sheet", os.path.join(OUT, "img", f"{take}-{map_id}-sheet.jpg"), names)


def main():
    take = sys.argv[1]
    if "--recut" in sys.argv:
        work = os.path.join(ROOT, "tools", "maptour")
        lines = open(os.path.join(OUT, take + ".log.txt"), encoding="utf-8").read().splitlines()
        start = arg("--recut") if arg("--recut", "").isdigit() else open(os.path.join(work, take + ".start.txt")).read()
        cut_stills(take, os.path.join(work, take + ".mp4"), lines, int(start))
        return
    src_root = os.path.abspath(arg("--root", ROOT))
    limit = int(arg("--limit", "420"))
    only = arg("--only")
    while os.path.exists(LOCK) and time.time() - os.path.getmtime(LOCK) < 25 * 60:
        print("waiting for the Studio lock:", open(LOCK).read().strip(), flush=True)
        time.sleep(45)
    open(LOCK, "w").write("maps thread (map tour) " + time.strftime("%Y-%m-%dT%H:%M:%S"))
    proc = ff = None
    try:
        os.makedirs(os.path.join(OUT, "img"), exist_ok=True)
        work = os.path.join(ROOT, "tools", "maptour")
        os.makedirs(work, exist_ok=True)
        project = os.path.join(ROOT, "test", "maptour.project.json")
        if src_root != ROOT:
            # the other copy's game code with this checkout's tour scripts
            shutil.copytree(os.path.join(ROOT, "test", "maptour"), os.path.join(src_root, "test", "maptour"), dirs_exist_ok=True)
            shutil.copy(project, os.path.join(src_root, "test", "maptour.project.json"))
            project = os.path.join(src_root, "test", "maptour.project.json")
        if only:
            text = open(project, encoding="utf-8").read().replace(
                '"ReplicatedStorage": {', '"ReplicatedStorage": { "$attributes": { "TourOnly": "%s" },' % only, 1)
            project = os.path.join(os.path.dirname(project), "maptour-only.project.json")
            open(project, "w", encoding="utf-8").write(text)
        if "--pc" in sys.argv:
            text = open(project, encoding="utf-8").read().replace("htd-film-phonehq-maptour", NAME)
            project = os.path.join(os.path.dirname(project), "maptour-pc.project.json")
            open(project, "w", encoding="utf-8").write(text)
        place = os.path.join(ROOT, "tools", NAME + ".rbxl")
        subprocess.run([os.path.join(ROOT, "tools", "rojo.exe"), "build", project, "-o", place], check=True)
        for made in ("maptour-only.project.json", "maptour-pc.project.json"):   # (this run's own variants of the project)
            made = os.path.join(os.path.dirname(project), made)
            if os.path.exists(made):
                os.remove(made)
        shutil.copy(os.path.join(ROOT, "test", "film", "HTD_Film.plugin.lua"),
                    os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Plugins\HTD_Film.lua"))
        studio = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe")), key=os.path.getmtime)[-1]
        log_dir = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\logs")
        before = set(glob.glob(os.path.join(log_dir, "*Studio*.log")))
        proc = subprocess.Popen([studio, place])
        log = None
        for _ in range(120):
            time.sleep(1)
            new = set(glob.glob(os.path.join(log_dir, "*Studio*.log"))) - before
            if new:
                log = sorted(new, key=os.path.getmtime)[-1]
                break
        if not log:
            raise SystemExit("no Studio log")

        def read():
            try:
                return open(log, encoding="utf-8", errors="ignore").read()
            except OSError:
                return ""

        end = time.time() + 240
        while time.time() < end and "[MAPTOUR]" not in read():
            time.sleep(0.5)
        if "[MAPTOUR]" not in read():
            print("\n".join(l[-240:] for l in read().splitlines() if "rror" in l or "FILM" in l)[-3000:])
            raise SystemExit("the tour never started")
        title = window_title(NAME)
        clip = os.path.join(work, take + ".mp4")
        ffmpeg = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
        start_ms = int(time.time() * 1000)
        ff = subprocess.Popen([ffmpeg, "-y", "-loglevel", "error", "-f", "gdigrab", "-framerate", "12", "-i", "title=" + title,
                               "-t", str(limit), "-vf", "crop=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", "-preset", "veryfast",
                               "-crf", "16", "-pix_fmt", "yuv420p", clip], stdin=subprocess.PIPE)
        end = time.time() + limit
        while time.time() < end and not re.search(r"\[MAPTOUR\] \d+ DONE|play test finished", read()):
            time.sleep(1)
        time.sleep(1.5)
        try:
            ff.stdin.write(b"q")
            ff.stdin.flush()
            ff.wait(20)
        except Exception:
            ff.kill()
        lines = [re.sub(r"^.*?\[MAPTOUR\]", "[MAPTOUR]", l) for l in read().splitlines() if "[MAPTOUR]" in l]
        errors = [l[-260:] for l in read().splitlines() if re.search(r"Script '[^']+', Line \d+|FLog::CreatorError", l)]
        open(os.path.join(OUT, take + ".log.txt"), "w", encoding="utf-8").write("\n".join(lines + ["", "errors:"] + errors[:80]))
        for l in lines:
            if " shot " not in l:
                print(l)
        print("errors:", len(errors))
        for e in errors[:25]:
            print("  ", e)
        open(os.path.join(work, take + ".start.txt"), "w").write(str(start_ms))
        cut_stills(take, clip, lines, start_ms)
    finally:
        if ff and ff.poll() is None:
            ff.kill()
        subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*" + NAME + "*' } | Stop-Process -Force"])
        if os.path.exists(LOCK) and "maps thread" in open(LOCK).read():
            os.remove(LOCK)


if __name__ == "__main__":
    main()
