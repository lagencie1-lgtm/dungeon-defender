"""Uploads the painted icons in art/icons/*.png to Roblox (Open Cloud Assets API) and writes their image ids
into src/shared/Art.luau. Icons that already have an id are skipped.
Needs the API key in tools/roblox-api-key.txt with the "asset" permission (read + write).
Each icon is first shrunk to 256x256 with ffmpeg (tools/ffmpeg).
Run:  python scripts/upload_art.py                      (art/icons, 256 px)
      python scripts/upload_art.py art/textures 1024    (another folder and size; names need a "" slot in Art.luau)
"""
import glob
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "src", "shared", "Art.luau")
ICONS = os.path.join(ROOT, "art", "icons")
SMALL = os.path.join(ROOT, "tools", "art-upload")
KEY = open(os.path.join(ROOT, "tools", "roblox-api-key.txt")).read().strip()
UNIVERSE = json.load(open(os.path.join(ROOT, "scripts", "publish.json")))["universeId"]


def api(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": KEY, **(headers or {})})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"{}")


def creator_user_id():
    info = api("GET", f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}")
    owner = info.get("user") or ""
    return owner.split("/")[-1]


def shrink(src, dst, size=256):
    ffmpeg = glob.glob(os.path.join(ROOT, "tools", "ffmpeg", "*", "bin", "ffmpeg.exe"))[0]
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", src, "-vf", f"scale={size}:{size}", dst], check=True)


def upload(path, name, user_id):
    boundary = "----htdart" + str(int(time.time() * 1000))
    request = {
        "assetType": "Decal",
        "displayName": "HTD " + name,
        "description": "Heroes Tower Defense icon",
        "creationContext": {"creator": {"userId": user_id}},
    }
    body = b""
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n".encode() + json.dumps(request).encode() + b"\r\n"
    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.png\"\r\n"
             "Content-Type: image/png\r\n\r\n").encode() + open(path, "rb").read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    op = api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    op_path = op.get("path")
    for _ in range(30):
        done = api("GET", "https://apis.roblox.com/assets/v1/" + op_path)
        if done.get("done"):
            return done["response"]["assetId"]
        time.sleep(2)
    raise RuntimeError("upload did not finish: " + name)


def image_id_for(decal_id):
    # a Decal wraps an Image; ImageLabels need the image id
    try:
        with urllib.request.urlopen(f"https://assetdelivery.roblox.com/v1/asset/?id={decal_id}") as r:
            xml = r.read().decode("utf-8", "ignore")
        m = re.search(r"id=(\d+)", xml)
        if m:
            return m.group(1)
    except Exception:
        pass
    return decal_id


def main():
    os.makedirs(SMALL, exist_ok=True)
    text = open(ART, encoding="utf-8").read()
    user_id = creator_user_id()
    folder = os.path.join(ROOT, sys.argv[1]) if len(sys.argv) > 1 else ICONS
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    for path in sorted(glob.glob(os.path.join(folder, "*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if not re.search(r"\n\t" + name + r' = "",', text):
            continue
        small = os.path.join(SMALL, name + ".png")
        shrink(path, small, size)
        try:
            decal = upload(small, name, user_id)
            image = image_id_for(decal)
            text = re.sub(r"(\n\t" + name + r' = )"",', r'\g<1>"' + str(image) + '",', text, count=1)
            print("uploaded", name, "->", image, flush=True)
        except Exception as e:
            print("FAILED", name, e, flush=True)
    open(ART, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    sys.exit(main())
