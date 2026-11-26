"""Uploads the second-generation pets (art/models/pets2/pet_<kind>.fbx + _paint.png) to Roblox as PRIVATE assets for
judging them in the engine. Ids are kept in reviews/pets/assets.json; the game uses the ids in src/shared/Art.luau.
Since 2026-11-24 the game uses these pets, so a changed pet gets NEW ids here and the game keeps showing the
approved one until the owner approves the change and the new ids are moved into Art.luau.

  python scripts/pet_upload.py                 upload what is new or changed (compares file hashes)
  python scripts/pet_upload.py emberfox slimey only these
A changed texture is always a new asset (images cannot be replaced). A changed model is a new version of the same
asset only while the game does not use that id; a model id found in Art.luau is never replaced in place.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "art", "models", "pets2")
STORE = os.path.join(ROOT, "reviews", "pets", "assets.json")
KEY = open(os.path.join(ROOT, "tools", "roblox-api-key.txt")).read().strip()
UNIVERSE = json.load(open(os.path.join(ROOT, "scripts", "publish.json")))["universeId"]
ART = open(os.path.join(ROOT, "src", "shared", "Art.luau"), encoding="utf-8").read()
KINDS = ["slimey", "leafling", "stonepup", "mosskitten", "glowbug", "emberfox", "crystalowl", "minigolem", "babydragon",
         "starunicorn", "phoenix", "voiddrake"]


def api(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": KEY, **(headers or {})})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"{}")


def multipart(request, path, mime):
    boundary = "----htdpet" + str(int(time.time() * 1000))
    body = f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n".encode() + json.dumps(request).encode() + b"\r\n"
    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
             f"Content-Type: {mime}\r\n\r\n").encode() + open(path, "rb").read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return body, "multipart/form-data; boundary=" + boundary


def wait(op):
    for _ in range(90):
        done = api("GET", "https://apis.roblox.com/assets/v1/" + op["path"])
        if done.get("done"):
            return str(done["response"]["assetId"])
        time.sleep(2)
    raise RuntimeError("upload did not finish")


def image_id_for(decal_id):
    try:
        with urllib.request.urlopen(f"https://assetdelivery.roblox.com/v1/asset/?id={decal_id}") as r:
            m = re.search(r"id=(\d+)", r.read().decode("utf-8", "ignore"))
        if m:
            return m.group(1)
    except Exception:
        pass
    return decal_id


def digest(path):
    return hashlib.sha1(open(path, "rb").read()).hexdigest()[:16]


def main():
    store = json.load(open(STORE)) if os.path.exists(STORE) else {}
    owner = api("GET", f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}").get("user", "").split("/")[-1]
    for kind in sys.argv[1:] or KINDS:
        fbx, tex = os.path.join(D, f"pet_{kind}.fbx"), os.path.join(D, f"pet_{kind}_paint.png")
        if not os.path.exists(fbx):
            print("missing", kind)
            continue
        e = store.setdefault(kind, {})
        try:
            if e.get("model_hash") != digest(fbx):
                # A model id the GAME uses (src/shared/Art.luau, since 2026-11-24) is never replaced in place: the
                # live game would show the new shape at once, with the old paint on it. It gets a new asset instead,
                # and the game keeps the old one until the new ids are moved into Art.luau.
                in_game = e.get("model") and ('"%s"' % e["model"]) in ART
                if in_game:
                    print("model", kind, "is in the game: uploading the change as a NEW asset", flush=True)
                if e.get("model") and not in_game:
                    body, ctype = multipart({"assetType": "Model", "assetId": e["model"]}, fbx, "model/fbx")
                    wait(api("PATCH", f"https://apis.roblox.com/assets/v1/assets/{e['model']}", body, {"Content-Type": ctype}))
                else:
                    request = {"assetType": "Model", "displayName": "HTD pet2 " + kind, "description": "Heroes Tower Defense pet (test)",
                               "creationContext": {"creator": {"userId": owner}}}
                    body, ctype = multipart(request, fbx, "model/fbx")
                    e["model"] = wait(api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": ctype}))
                e["model_hash"] = digest(fbx)
                print("model", kind, e["model"], flush=True)
            if e.get("paint_hash") != digest(tex):
                request = {"assetType": "Decal", "displayName": "HTD pet2 paint " + kind, "description": "Heroes Tower Defense pet texture (test)",
                           "creationContext": {"creator": {"userId": owner}}}
                body, ctype = multipart(request, tex, "image/png")
                decal = wait(api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": ctype}))
                e["paint"] = image_id_for(decal)
                e["paint_hash"] = digest(tex)
                print("paint", kind, e["paint"], flush=True)
        except Exception as ex:
            print("FAILED", kind, ex, getattr(ex, "read", lambda: b"")()[:300], flush=True)
        json.dump(store, open(STORE, "w"), indent=1)


if __name__ == "__main__":
    main()
