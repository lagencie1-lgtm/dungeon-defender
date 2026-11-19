#!/usr/bin/env bash
# Builds hand-made models and renders each from three sides into one sheet, for checking before upload.
#   bash scripts/pet_views.sh <blender_script> <prefix> <kind> [<kind> ...]     e.g. pets_hand.py pet slimey leafling
cd "$(dirname "$0")/.."
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
script="$1"; prefix="$2"; shift 2
for kind in "$@"; do
  "$B" -b -P "art/blender/$script" -- "$PWD/art/models/${prefix}_$kind.fbx" "$kind" 2>&1 | grep -E "TRIANGLES|Error|Traceback|line [0-9]" | sed "s/^/$kind: /"
  for a in 24 -50 160; do
    HTD_ANGLE=$a "$B" -b -P art/blender/tripo_fix.py -- "art/models/${prefix}_$kind.fbx" "art/models/${prefix}_${kind}_paint.png" "art/models/_v_${kind}_$a.png" 2>&1 | grep -E "Error|Traceback"
  done
done
python - "$@" <<'PY'
import sys
from PIL import Image
kinds = sys.argv[1:]
sheet = Image.new('RGB', (420 * 3, 420 * len(kinds)))
for r, k in enumerate(kinds):
    for c, a in enumerate(('24', '-50', '160')):
        try:
            im = Image.open(f'art/models/_v_{k}_{a}.png').convert('RGB').crop((90, 60, 610, 640)).resize((420, 420))
            sheet.paste(im, (c * 420, r * 420))
        except FileNotFoundError:
            pass
sheet.save('art/models/_views.png')
PY
rm -f art/models/_v_*.png
