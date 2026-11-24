"""Free AI "picture to 3D" as a sculpting aid: sends one pet picture to an open model running on a free public
Hugging Face Space and saves the 3D model it returns. No install and no account: plain web requests.

Used as a SHAPE REFERENCE (how the head, muzzle and body really sit in 3D) and, where it is good enough, as the
base shape that the Blender pipeline then cleans, repaints and gives crisp eyes. Both models are MIT licensed:
  triposg    VAST-AI/TripoSG        fast, shape only (texture is a separate optional step)
  trellis2   microsoft/TRELLIS.2    slower, shape + texture

  python scripts/ai3d.py triposg  art/ref3d/batch2/pet_emberfox.png  art/ai3d/emberfox_triposg.glb
  python scripts/ai3d.py trellis2 art/ref3d/batch2/pet_emberfox.png  art/ai3d/emberfox_trellis2.glb
  python scripts/ai3d.py info triposg          what the space accepts

The free graphics time of these spaces is small (a few runs per day without an account): one run per pet, keep
the result in art/ai3d/. Only the picture itself is sent, under a neutral file name.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

SPACES = {"triposg": "https://vast-ai-triposg.hf.space", "trellis2": "https://microsoft-trellis-2.hf.space"}
UA = {"User-Agent": "Mozilla/5.0"}


class Space:
    def __init__(self, base):
        self.base = base
        self.session = uuid.uuid4().hex[:12]
        self.config = json.loads(self._get("/config"))
        self.prefix = self.config.get("api_prefix", "")
        self.deps = {d.get("api_name"): d for d in self.config["dependencies"] if d.get("api_name")}

    def _get(self, path, timeout=60):
        with urllib.request.urlopen(urllib.request.Request(self.base + path, headers=UA), timeout=timeout) as r:
            return r.read().decode("utf-8", "ignore")

    def upload(self, path, neutral_name):
        boundary = "----ai3d" + uuid.uuid4().hex
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"files\"; filename=\"{neutral_name}\"\r\n"
                "Content-Type: image/png\r\n\r\n").encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
        req = urllib.request.Request(self.base + self.prefix + "/upload", data=body, method="POST",
                                     headers={**UA, "Content-Type": "multipart/form-data; boundary=" + boundary})
        with urllib.request.urlopen(req, timeout=120) as r:
            server_path = json.loads(r.read())[0]
        return {"path": server_path, "orig_name": neutral_name, "meta": {"_type": "gradio.FileData"}}

    def call(self, api_name, data, timeout=900):
        dep = self.deps[api_name]
        body = json.dumps({"data": data, "event_data": None, "fn_index": dep["id"], "trigger_id": None, "session_hash": self.session}).encode()
        req = urllib.request.Request(self.base + self.prefix + "/queue/join", data=body, method="POST", headers={**UA, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            event = json.loads(r.read()).get("event_id")
        req = urllib.request.Request(self.base + self.prefix + "/queue/data?session_hash=" + self.session, headers={**UA, "Accept": "text/event-stream"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            for raw in r:
                line = raw.decode("utf-8", "ignore").strip()
                if not line.startswith("data:"):
                    continue
                msg = json.loads(line[5:])
                if msg.get("event_id") not in (None, event):
                    continue
                kind = msg.get("msg")
                if kind == "process_completed":
                    if not msg.get("success", True):
                        raise RuntimeError(f"{api_name} failed: {json.dumps(msg.get('output'))[:400]}")
                    return msg["output"]["data"]
                if kind in ("estimation", "process_starts"):
                    print("  ", api_name, kind, msg.get("rank", ""), msg.get("rank_eta", ""), flush=True)
                if kind == "close_stream":
                    break
        raise RuntimeError(api_name + ": stream closed without a result")

    def download(self, filedata, out):
        url = filedata.get("url") or (self.base + self.prefix + "/file=" + filedata["path"])
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
            data = r.read()
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        open(out, "wb").write(data)
        return len(data)


def defaults(space, api_name):
    info = json.loads(space._get(space.prefix + "/info"))
    return [(p.get("parameter_name"), p.get("parameter_default")) for p in info["named_endpoints"]["/" + api_name]["parameters"]]


def main():
    cmd = sys.argv[1]
    if cmd == "info":
        s = Space(SPACES[sys.argv[2]])
        for name in s.deps:
            try:
                print(name, defaults(s, name))
            except KeyError:
                print(name)
        return
    picture, out = sys.argv[2], sys.argv[3]
    s = Space(SPACES[cmd])
    if "start_session" in s.deps:
        s.call("start_session", [])
    img = s.upload(picture, "pet.png")
    started = time.time()
    if cmd == "triposg":
        seg = s.call("run_segmentation", [img])[0]
        d = dict(defaults(s, "image_to_3d"))
        faces = int(sys.argv[4]) if len(sys.argv) > 4 else 60000
        glb = s.call("image_to_3d", [seg, 0, d.get("num_inference_steps", 50), d.get("guidance_scale", 7), True, faces])[0]
        if "--texture" in sys.argv:
            try:
                glb = s.call("run_texture", [img, glb, 0])[0]
            except Exception as e:
                print("texture step failed, keeping the plain shape:", e)
    else:
        pre = s.call("preprocess_image", [img])[0]
        d = defaults(s, "image_to_3d")
        args = [pre] + [v for _, v in d[1:]]
        s.call("image_to_3d", args)
        e = dict(defaults(s, "extract_glb"))
        res = s.call("extract_glb", [e.get("decimation_target", 300000), e.get("texture_size", 2048)])
        glb = res[-1] if isinstance(res[-1], dict) else res[0]
    size = s.download(glb, out)
    print(f"saved {out} ({size / 1e6:.1f} MB) in {time.time() - started:.0f} s")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read()[:400])
        sys.exit(1)
