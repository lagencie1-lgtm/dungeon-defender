"""Uploads rebuilt map props (art/models/<name>.fbx and <name>_paint.png) as NEW Roblox assets and writes the new ids
into Art.Models[<name>] and Art.Textures["paint_<name>"] in src/shared/Art.luau.
Always new assets, never a new version of an old id: the live game loads models by id, so a new version of a live
asset would change the live game at once, without a publish. The new ids reach players only with the next publish.
  python scripts/upload_props.py tree_oak tree_dead
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import map_kit_upload as kit  # noqa: E402
import upload_art  # noqa: E402
import upload_models  # noqa: E402


def main():
    names = sys.argv[1:]
    text = open(kit.ART, encoding="utf-8", newline="").read()
    owner = upload_art.creator_user_id()
    os.makedirs(upload_art.SMALL, exist_ok=True)
    for name in names:
        fbx = os.path.join(ROOT, "art", "models", name + ".fbx")
        request = {"assetType": "Model", "displayName": "HTD " + name, "description": "Heroes Tower Defense model",
                   "creationContext": {"creator": {"userId": owner}}}
        body, ctype = upload_models.multipart(request, fbx)
        new_id = upload_models.wait(upload_models.api("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": ctype}))
        text, _ = kit.slot(text, "Art.Models", name)
        text = kit.store(text, "Art.Models", name, new_id)
        print("model", name, "->", new_id, flush=True)
        from PIL import Image
        paint = fbx[:-4] + "_paint.png"
        size = Image.open(paint).size[0]
        small = os.path.join(upload_art.SMALL, "paint_" + name + ".png")
        upload_art.shrink(paint, small, size)
        decal = upload_art.upload(small, "paint_" + name, owner)
        text, _ = kit.slot(text, "Art.Textures", "paint_" + name)
        text = kit.store(text, "Art.Textures", "paint_" + name, upload_art.image_id_for(decal))
        print("paint", name, "->", decal, flush=True)
        open(kit.ART, "w", encoding="utf-8", newline="").write(text)


if __name__ == "__main__":
    main()
