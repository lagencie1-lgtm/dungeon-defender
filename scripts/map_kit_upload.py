"""Uploads the map kit (art/models/mapkit/mapkit_<piece>_<theme>.fbx and its _paint.png) to Roblox as private
assets and writes the ids into Art.Models / Art.Textures (paint_<name>) in src/shared/Art.luau.
  python scripts/map_kit_upload.py            every piece that has no id yet
  python scripts/map_kit_upload.py --force mapkit_arch_forest [more names]   new versions of these (model: same id; paint: new id)
Uses the same Open Cloud calls as upload_models.py and upload_art.py.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import upload_art  # noqa: E402
import upload_models  # noqa: E402

ART = os.path.join(ROOT, "src", "shared", "Art.luau")
KIT = os.path.join(ROOT, "art", "models", "mapkit")


def slot(text, table, name):
    """the id stored for `name` in `table` (adds an empty line for a new name); returns (text, id)"""
    start = text.index(table + " = {")
    end = text.index("\n}", start)
    block = text[start:end]
    m = re.search(r"\n\t" + name + r' = "(\d*)",', block)
    if m:
        return text, m.group(1)
    eol = "\r\n" if "\r\n" in text else "\n"
    block = block.replace(table + " = {" + eol, table + " = {" + eol + "\t" + name + ' = "",' + eol, 1)
    return text[:start] + block + text[end:], ""


def store(text, table, name, value):
    start = text.index(table + " = {")
    end = text.index("\n}", start)
    block = re.sub(r"(\n\t" + name + r' = )"\d*",', r'\g<1>"' + str(value) + '",', text[start:end], count=1)
    return text[:start] + block + text[end:]


def main():
    force = [a for a in sys.argv[2:]] if "--force" in sys.argv else []
    text = open(ART, encoding="utf-8", newline="").read()
    owner = upload_art.creator_user_id()
    os.makedirs(upload_art.SMALL, exist_ok=True)
    for fbx in sorted(glob.glob(os.path.join(KIT, "mapkit_*.fbx"))):
        name = os.path.basename(fbx)[:-4]
        try:
            text, model_id = slot(text, "Art.Models", name)
            if not model_id:
                request = {"assetType": "Model", "displayName": "HTD " + name, "description": "Heroes Tower Defense model",
                           "creationContext": {"creator": {"userId": owner}}}
                body, ctype = upload_models.multipart(request, fbx)
                new_id = upload_models.wait(upload_models.api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": ctype}))
                text = store(text, "Art.Models", name, new_id)
                print("model", name, "->", new_id, flush=True)
            elif name in force:
                body, ctype = upload_models.multipart({"assetType": "Model", "assetId": model_id}, fbx)
                upload_models.wait(upload_models.api("PATCH", f"https://apis.roblox.com/assets/v1/assets/{model_id}", body, {"Content-Type": ctype}))
                print("model", name, "updated", model_id, flush=True)
            paint = fbx[:-4] + "_paint.png"
            text, paint_id = slot(text, "Art.Textures", "paint_" + name)
            if not paint_id or name in force:
                from PIL import Image
                size = Image.open(paint).size[0]
                small = os.path.join(upload_art.SMALL, "paint_" + name + ".png")
                upload_art.shrink(paint, small, size)
                decal = upload_art.upload(small, "paint_" + name, owner)
                text = store(text, "Art.Textures", "paint_" + name, upload_art.image_id_for(decal))
                print("paint", name, "->", decal, flush=True)
        except Exception as e:
            print("FAILED", name, e, getattr(e, "read", lambda: b"")()[:300], flush=True)
        open(ART, "w", encoding="utf-8", newline="").write(text)


if __name__ == "__main__":
    main()
