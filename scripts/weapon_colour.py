"""Weapon colour gate (coordinator 2026-11-24, Ballista round 4): the weapon's colour against the painting's weapon,
from the painting's own angle. The model is drawn whole and with only its weapon part (same camera); both are lined
up with the painting the way scripts/match_score.py lines up outlines (cropped to the whole outline, same height,
centred); the weapon's pixels are then compared with the painting's pixels at the same place (median Lab dE).
  python scripts/weapon_colour.py <model.fbx> <painting.png> [part=Skin_barrel]   -> prints WEAPON dE"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageCms

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import match_score as M  # noqa: E402

BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"


def lab(img):
    tf = ImageCms.buildTransformFromOpenProfiles(ImageCms.createProfile("sRGB"), ImageCms.createProfile("LAB"), "RGB", "LAB")
    a = np.asarray(ImageCms.applyTransform(img.convert("RGB"), tf))
    ab = a[..., 1:].view(np.int8).astype(float)   # (Pillow's LAB keeps a and b as signed bytes)
    return np.dstack([a[..., 0].astype(float) * 100 / 255, ab[..., 0], ab[..., 1]])


def main():
    fbx, pic = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    part = next((a[5:] for a in sys.argv[3:] if a.startswith("part=")), "Skin_barrel")
    full, weap = fbx[:-4] + "_wc_full.png", fbx[:-4] + "_wc_weapon.png"
    r = os.path.join(ROOT, "art", "blender", "render_match.py")
    subprocess.run([BLENDER, "-b", "-P", r, "--", fbx, full, "-75", "15", "512"], capture_output=True)
    subprocess.run([BLENDER, "-b", "-P", r, "--", fbx, weap, "-75", "15", "512"], capture_output=True, env=dict(os.environ, HTD_ONLY_PART=part))
    f_rgb, f_m = M.mask_render(Image.open(full))
    w_rgb, w_m = M.mask_render(Image.open(weap))
    box = f_m.getbbox()
    W = max(1, round((box[2] - box[0]) * M.H / (box[3] - box[1])))
    f_rgb, w_m = f_rgb.crop(box).resize((W, M.H)), w_m.crop(box).resize((W, M.H))
    t_rgb, t_m = M.normalise(*M.mask_target(Image.open(pic)))
    width = max(W, t_m.size[0]) + 20
    f_rgb, w_m = M.centred(f_rgb, width, "RGB", (255, 255, 255)), M.centred(w_m, width, "L", 0)
    t_rgb, t_m = M.centred(t_rgb, width, "RGB", (255, 255, 255)), M.centred(t_m, width, "L", 0)
    wm = (np.asarray(w_m) > 0) & (np.asarray(t_m) > 0)
    lm, lt = lab(f_rgb), lab(t_rgb)
    med = float(np.linalg.norm(np.median(lm[wm], 0) - np.median(lt[wm], 0)))
    mean = float(np.linalg.norm(lm[wm] - lt[wm], axis=1).mean())
    print(f"WEAPON dE {med:.1f} (median colours), {mean:.1f} pixel by pixel, {int(wm.sum())} px")
    print("  model weapon median Lab", np.round(np.median(lm[wm], 0), 1), " painting there", np.round(np.median(lt[wm], 0), 1))


if __name__ == "__main__":
    main()
