import sys
from PIL import Image, ImageStat
def sv(p):
    im = Image.open(p).convert("HSV")
    w, h = im.size
    im = im.crop((int(w*0.15), int(h*0.3), int(w*0.85), int(h*0.8)))  # the world, not the HUD edges
    s = ImageStat.Stat(im)
    return s.mean[2] / 255, s.mean[1] / 255
for name in sys.argv[1:]:
    v, s = sv(name)
    print(f"{name}: brightness {v:.3f} saturation {s:.3f}")
