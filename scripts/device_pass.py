"""Device pass: plays the Rule 1 route (Outpost, Shop, Pets, Backpack, a run with a Ranger, its upgrade panel) once per
device in Studio's Device Emulator, measures every screen (test/devices/Devices.client.luau), takes a screenshot at
each step and makes one labelled sheet per device plus an overview.

  python scripts/device_pass.py                  every device below
  python scripts/device_pass.py ipad_old xbox_4k only these
  python scripts/device_pass.py --list           the emulator's device ids found in Studio's files (to fix SIM ids)
  python scripts/device_pass.py --sheets         only remake the sheets from reviews/devices/results.json

Output: reviews/devices/<key>/<step>.png, reviews/devices/<key>-sheet.jpg, reviews/devices/overview.jpg,
reviews/devices/results.json. Ratings (1-10, written after looking at the sheets) go in reviews/devices/ratings.json
as {"<key>": [score, "one line why"]} and are printed on the sheets.
Takes tools/studio.lock like the other Studio scripts and closes each Studio it opened.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
OUT = os.path.join(ROOT, "reviews", "devices")
TOOLS = os.path.join(ROOT, "tools")
LOCK = os.path.join(TOOLS, "studio.lock")
STEPS = ["Outpost", "Shop", "Pets", "Backpack", "Run", "Defender"]
CHECKS = ["Cut", "TV safe", "Thumbs", "Tap", "Text", "Fits", "Overlap"]

# key, label on the sheet, Studio emulator id (SIM), input, the screen it should report (landscape, in UI pixels)
DEVICES = [
    ("iphone_se", "iPhone SE (1st gen, 2016) - oldest small iPhone", "iphone_se", "touch", (568, 320)),
    ("iphone_new", "iPhone 16 Pro Max - newest big iPhone (notch side)", "iphone_16_pro_max", "touch", (956, 440)),
    ("android_old", "Galaxy S7 class - old small Android", "samsung_galaxy_s7", "touch", (640, 360)),
    ("android_new", "Galaxy S24 Ultra class - new Android", "samsung_galaxy_s24_ultra", "touch", (915, 412)),
    ("ipad_old", "iPad (6th gen, 2018) - old iPad", "ipad", "touch", (1024, 768)),
    ("ipad_pro", "iPad Pro 13 - new iPad", "ipad_pro_12_9", "touch", (1366, 1024)),
    ("xbox_1080", "Xbox, 1080p TV, controller", "xbox_one", "pad", (1920, 1080)),
    ("xbox_4k", "Xbox, 4K TV, controller (worst case: 3840x2160 UI pixels)", "4k", "pad", (3840, 2160)),
    ("tv_touch", "Touch screen TV, 1080p", "1080p", "touch", (1920, 1080)),
    ("pc_laptop", "PC laptop 1366x768, mouse", "", "mouse", (1366, 768)),
]


def take_lock():
    while os.path.exists(LOCK) and time.time() - os.path.getmtime(LOCK) < 25 * 60:
        print("waiting for the Studio lock:", open(LOCK).read().strip(), flush=True)
        time.sleep(60)
    with open(LOCK, "w") as f:
        f.write("device pass %s" % time.strftime("%Y-%m-%dT%H:%M:%S"))


def project(key, sim, inputs):
    """writes tools/htd-devices-<key>.project.json and builds the place"""
    marker = {"$className": "RemoteEvent",
              "$attributes": {"Device": key, "SimDevice": sim, "Input": inputs, "Hold": 6}}
    shared = {"Shared": {"$path": "../src/shared"}, "DeviceTest": marker}
    if inputs == "pad":
        shared["GamepadTest"] = {"$className": "Folder"}   # Gamepad.luau acts as if a controller is in use
    if inputs == "touch":
        shared["MobileTest"] = {"$className": "Folder"}    # Ui.isTouch even if the emulator profile is a desktop size
    tree = {
        "name": "htd-devices-" + key,
        "tree": {
            "$className": "DataModel",
            "ReplicatedStorage": shared,
            "ServerScriptService": {"Server": {"$path": "../src/server"},
                                    "DevicesServer": {"$path": "../test/devices/Devices.server.luau"}},
            "StarterPlayer": {"StarterPlayerScripts": {"Client": {"$path": "../src/client"},
                                                       "DevicesClient": {"$path": "../test/devices/Devices.client.luau"}}},
            "MaterialService": {"$path": "../src/materials"},
        },
    }
    path = os.path.join(TOOLS, "htd-devices-%s.project.json" % key)
    with open(path, "w") as f:
        json.dump(tree, f, indent=1)
    place = os.path.join(TOOLS, "htd-devices-%s.rbxl" % key)
    subprocess.run([os.path.join(TOOLS, "rojo.exe"), "build", path, "-o", place], check=True)
    return place


def studio_exe():
    found = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe")), key=os.path.getmtime)
    if not found:
        sys.exit("Roblox Studio not found")
    return found[-1]


def install_plugin():
    plugins = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Plugins")
    os.makedirs(plugins, exist_ok=True)
    shutil.copy(os.path.join(ROOT, "test", "devices", "HTD_Devices.plugin.lua"), os.path.join(plugins, "HTD_Devices.lua"))


def newest_log():
    logs = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\logs\*Studio*.log"))
    return max(logs, key=os.path.getmtime) if logs else None


def capture(path, key):
    """screenshot of the game view through Studio's connector; the whole Studio window as a fallback"""
    try:
        from studio_mcp import Studio
        with Studio() as s:
            s.shot(path)
        return "connector"
    except BaseException as e:  # noqa: BLE001 (SystemExit from studio_mcp too)
        ffmpeg = os.path.join(TOOLS, "ffmpeg", "bin", "ffmpeg.exe")
        if not os.path.exists(ffmpeg):
            ffmpeg = shutil.which("ffmpeg") or "ffmpeg"
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-f", "gdigrab", "-i", "title=htd-devices-%s - Roblox Studio" % key,
                        "-frames:v", "1", path])
        return "window (%s)" % str(e)[:80]


def run_device(key, label, sim, inputs, expect):
    place = project(key, sim, inputs)
    folder = os.path.join(OUT, key)
    os.makedirs(folder, exist_ok=True)
    before = newest_log()
    proc = subprocess.Popen([studio_exe(), place])
    log = None
    for _ in range(90):
        time.sleep(1)
        new = newest_log()
        if new and new != before:
            log = new
            break
    result = {"label": label, "sim": sim, "input": inputs, "expect": expect, "steps": {}, "lines": []}
    if not log:
        proc.kill()
        result["error"] = "no Studio log"
        return result
    seen = 0
    deadline = time.time() + 600
    done = False
    while time.time() < deadline and not done:
        time.sleep(0.5)
        try:
            text = open(log, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        lines = [ln for ln in text.splitlines() if "[DEVICES]" in ln or "Script '" in ln]
        for ln in lines[seen:]:
            ln = re.sub(r"^[^\[]*\[FLog::\w+\] ", "", ln)
            result["lines"].append(ln)
            print(ln[:240], flush=True)
            m = re.search(r"\[DEVICES\] SHOT (\S+) (\S+)", ln)
            if m:
                step = m.group(2)
                how = capture(os.path.join(folder, step + ".png"), key)
                result["steps"].setdefault(step, {})["shot"] = how
            m = re.search(r"\[DEVICES\] CHECK (\S+) (\S+) (.+?) (\d+)(?:: (.*))?$", ln)
            if m:
                result["steps"].setdefault(m.group(2), {}).setdefault("checks", {})[m.group(3)] = \
                    [int(m.group(4)), m.group(5) or ""]
            m = re.search(r"\[DEVICES\] SIZE \S+ (\S+) viewport (\d+)x(\d+) inset (\d+),(\d+)", ln)
            if m:
                result["steps"].setdefault(m.group(1), {})["viewport"] = [int(m.group(2)), int(m.group(3))]
                result["steps"][m.group(1)]["size_line"] = ln
            if "[DEVICES] DONE" in ln or "play test finished" in ln:
                done = True
        seen = len(lines)
    time.sleep(2)
    proc.kill()
    with open(LOCK, "w") as f:   # keep the lock fresh between devices
        f.write("device pass %s" % time.strftime("%Y-%m-%dT%H:%M:%S"))
    return result


def sheets(results):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("arialbd.ttf", 22)
        small = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = small = ImageFont.load_default()
    ratings = {}
    rpath = os.path.join(OUT, "ratings.json")
    if os.path.exists(rpath):
        ratings = json.load(open(rpath, encoding="utf-8"))
    cell_w, cell_h = 640, 360
    overview = []
    for key, r in results.items():
        cols, rows = 3, 2
        text_h = 40 + 22 * (len(CHECKS) + 2)
        sheet = Image.new("RGB", (cols * cell_w, 60 + rows * (cell_h + 30) + text_h), (18, 16, 14))
        d = ImageDraw.Draw(sheet)
        score = ratings.get(key)
        title = r["label"] + ("   -   rating %s/10: %s" % (score[0], score[1]) if score else "")
        d.text((14, 16), title, fill=(255, 225, 150), font=font)
        thumbs = []
        for i, step in enumerate(STEPS):
            x, y = (i % cols) * cell_w, 60 + (i // cols) * (cell_h + 30)
            info = r["steps"].get(step, {})
            vp = info.get("viewport")
            caption = "%d. %s%s" % (i + 1, step, ("   (%dx%d)" % tuple(vp)) if vp else "")
            d.text((x + 10, y + 4), caption, fill=(235, 235, 235), font=small)
            shot = os.path.join(OUT, key, step + ".png")
            if os.path.exists(shot):
                im = Image.open(shot).convert("RGB")
                im.thumbnail((cell_w - 10, cell_h - 4))
                sheet.paste(im, (x + 5, y + 26))
                if step in ("Outpost", "Run"):
                    thumbs.append(im)
            else:
                d.text((x + 20, y + 120), "no screenshot", fill=(255, 120, 120), font=font)
        y = 60 + rows * (cell_h + 30) + 10
        d.text((14, y), "Check".ljust(10) + "  ".join(s[:8].ljust(9) for s in STEPS), fill=(255, 225, 150), font=small)
        for j, check in enumerate(CHECKS):
            row = []
            for step in STEPS:
                c = r["steps"].get(step, {}).get("checks", {}).get(check)
                row.append(("-" if c is None else ("ok" if c[0] == 0 else str(c[0]))).ljust(9))
            d.text((14, y + 22 * (j + 1)), check.ljust(10) + "  ".join(row), fill=(220, 220, 220), font=small)
        d.text((14, y + 22 * (len(CHECKS) + 1)), "numbers = how many things broke the rule (test/devices/Devices.client.luau)",
               fill=(160, 160, 160), font=small)
        sheet.save(os.path.join(OUT, key + "-sheet.jpg"), quality=88)
        overview.append((key, r["label"], score, thumbs))
    if overview:
        w, h = 480, 270
        ov = Image.new("RGB", (60 + 2 * w + 520, len(overview) * (h + 10) + 10), (18, 16, 14))
        d = ImageDraw.Draw(ov)
        for i, (key, label, score, thumbs) in enumerate(overview):
            y = 10 + i * (h + 10)
            for j, im in enumerate(thumbs[:2]):
                t = im.copy()
                t.thumbnail((w, h))
                ov.paste(t, (10 + j * (w + 10), y))
            d.text((30 + 2 * w, y + 10), label, fill=(255, 225, 150), font=small)
            d.text((30 + 2 * w, y + 40), ("%s/10" % score[0]) if score else "not rated", fill=(255, 255, 255), font=font)
            if score:
                d.text((30 + 2 * w, y + 76), score[1][:60], fill=(200, 200, 200), font=small)
        ov.save(os.path.join(OUT, "overview.jpg"), quality=88)
    print("sheets in", OUT)


def list_ids():
    base = os.path.dirname(studio_exe())
    pattern = re.compile(r'"(iphone[\w]*|ipad[\w]*|samsung[\w]*|galaxy[\w]*|pixel[\w]*|xbox[\w]*|playstation[\w]*|ps\d[\w]*|\d+p|4k)"', re.I)
    found = set()
    for path in glob.glob(os.path.join(base, "**", "*.json"), recursive=True):
        try:
            text = open(path, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        hits = pattern.findall(text)
        if hits:
            found.update(hits)
            print(path, len(hits))
    print(sorted(found))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--list" in sys.argv:
        return list_ids()
    rpath = os.path.join(OUT, "results.json")
    results = json.load(open(rpath, encoding="utf-8")) if os.path.exists(rpath) else {}
    if "--sheets" not in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        install_plugin()
        take_lock()
        try:
            for key, label, sim, inputs, expect in DEVICES:
                if args and key not in args:
                    continue
                print("==", key, label, flush=True)
                results[key] = run_device(key, label, sim, inputs, expect)
                with open(rpath, "w", encoding="utf-8") as f:
                    json.dump(results, f, indent=1)
        finally:
            if os.path.exists(LOCK):
                os.remove(LOCK)
    ordered = {k: results[k] for k, *_ in DEVICES if k in results}
    sheets(ordered)


if __name__ == "__main__":
    main()
