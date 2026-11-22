import sys, glob, os
from PIL import Image
out, w, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
files = sys.argv[4:]
ims = [Image.open(f).convert("RGB") for f in files]
h = int(w * ims[0].height / ims[0].width)
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * h), (16, 16, 16))
for i, im in enumerate(ims):
    sheet.paste(im.resize((w, int(w * im.height / im.width))).crop((0, 0, w, h)), ((i % cols) * w, (i // cols) * h))
sheet.save(out, optimize=True)
print(out, sheet.size, os.path.getsize(out))
