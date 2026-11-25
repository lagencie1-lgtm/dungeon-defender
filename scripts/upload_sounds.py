"""Uploads the code-made sounds in art/sounds/*.wav to Roblox as Audio (Open Cloud) and prints the ids.
Ids and file hashes are kept in art/sounds/ids.json; an unchanged file is not uploaded again.

  python scripts/upload_sounds.py            all .wav files in art/sounds
  python scripts/upload_sounds.py pet_dig    only these
"""
import glob
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "art", "sounds")
STORE = os.path.join(D, "ids.json")
KEY = open(os.path.join(ROOT, "tools", "roblox-api-key.txt")).read().strip()
UNIVERSE = json.load(open(os.path.join(ROOT, "scripts", "publish.json")))["universeId"]


def api(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": KEY, **(headers or {})})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"{}")


def main():
    store = json.load(open(STORE)) if os.path.exists(STORE) else {}
    owner = api("GET", f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}").get("user", "").split("/")[-1]
    names = sys.argv[1:] or [os.path.basename(p)[:-4] for p in sorted(glob.glob(os.path.join(D, "*.wav")))]
    for name in names:
        path = os.path.join(D, name + ".wav")
        digest = hashlib.sha1(open(path, "rb").read()).hexdigest()[:16]
        if store.get(name, {}).get("hash") == digest:
            print(name, store[name]["id"], "(unchanged)")
            continue
        request = {"assetType": "Audio", "displayName": "HTD " + name, "description": "Heroes Tower Defense sound",
                   "creationContext": {"creator": {"userId": owner}}}
        boundary = "----htdsnd" + str(int(time.time() * 1000))
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(request)}\r\n"
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.wav\"\r\n"
                f"Content-Type: audio/wav\r\n\r\n").encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
        try:
            op = api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
            for _ in range(90):
                done = api("GET", "https://apis.roblox.com/assets/v1/" + op["path"])
                if done.get("done"):
                    break
                time.sleep(2)
            asset = str(done["response"]["assetId"])
        except urllib.error.HTTPError as e:
            print("FAILED", name, e.code, e.read()[:300])
            continue
        store[name] = {"id": asset, "hash": digest}
        json.dump(store, open(STORE, "w"), indent=1)
        print(name, asset)


if __name__ == "__main__":
    main()
