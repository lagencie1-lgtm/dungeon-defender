"""Uploads the Blender-built models (art/models/*.fbx) to Roblox as Model assets and writes their ids
into Art.Models in src/shared/Art.luau. Use --force NAME to upload a new version of one model.
Run:  python scripts/upload_models.py [--force tower_ranger]
"""
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "src", "shared", "Art.luau")
MODELS = os.path.join(ROOT, "art", "models")
KEY = open(os.path.join(ROOT, "tools", "roblox-api-key.txt")).read().strip()
UNIVERSE = json.load(open(os.path.join(ROOT, "scripts", "publish.json")))["universeId"]


def api(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": KEY, **(headers or {})})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"{}")


def multipart(request, path):
    boundary = "----htdmodel" + str(int(time.time() * 1000))
    name = os.path.basename(path)
    body = f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n".encode() + json.dumps(request).encode() + b"\r\n"
    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}\"\r\n"
             "Content-Type: model/fbx\r\n\r\n").encode() + open(path, "rb").read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return body, "multipart/form-data; boundary=" + boundary


def wait(op):
    for _ in range(60):
        done = api("GET", "https://apis.roblox.com/assets/v1/" + op["path"])
        if done.get("done"):
            return done["response"]["assetId"]
        time.sleep(2)
    raise RuntimeError("upload did not finish")


def main():
    force = sys.argv[sys.argv.index("--force") + 1] if "--force" in sys.argv else None
    full = open(ART, encoding="utf-8").read()
    start = full.index("Art.Models = {")
    end_ = full.index("\n}", start) + 2
    head, text, tail = full[:start], full[start:end_], full[end_:]
    owner = api("GET", f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}").get("user", "").split("/")[-1]
    for file in sorted(os.listdir(MODELS)):
        if not file.endswith(".fbx"):
            continue
        name = file[:-4]
        path = os.path.join(MODELS, file)
        m = re.search(r"\n\t" + name + r' = "(\d*)",', text)
        if m is None:
            # add a line for a new model inside Art.Models
            text = text.replace("Art.Models = {\n", "Art.Models = {\n\t" + name + ' = "",\n', 1)
            m = re.search(r"\n\t" + name + r' = "(\d*)",', text)
        existing = m.group(1)
        try:
            if existing and force == name:
                # a new version of the same asset (the id stays the same)
                body, ctype = multipart({"assetType": "Model", "assetId": existing}, path)
                wait(api("PATCH", f"https://apis.roblox.com/assets/v1/assets/{existing}", body, {"Content-Type": ctype}))
                print("updated", name, existing)
            elif not existing:
                request = {"assetType": "Model", "displayName": "HTD " + name, "description": "Heroes Tower Defense model",
                           "creationContext": {"creator": {"userId": owner}}}
                body, ctype = multipart(request, path)
                new_id = wait(api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": ctype}))
                text = re.sub(r"(\n\t" + name + r' = )"",', r'\g<1>"' + str(new_id) + '",', text, count=1)
                print("uploaded", name, "->", new_id)
        except Exception as e:
            print("FAILED", name, e, getattr(e, "read", lambda: b"")()[:300])
    open(ART, "w", encoding="utf-8").write(head + text + tail)


if __name__ == "__main__":
    sys.exit(main())
