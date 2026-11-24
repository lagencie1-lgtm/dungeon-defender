#!/usr/bin/env bash
# Builds map kit pieces in Blender and a look sheet.  bash scripts/map_kit.sh <theme> [pieces...]
# Output: art/models/mapkit/mapkit_<piece>_<theme>.fbx + _paint.png, sheet reviews/maps/img/kit-<theme>.jpg
cd "$(dirname "$0")/.."
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
theme=$1; shift
pieces=${@:-wall low arch pillar bridge set}
mkdir -p art/models/mapkit reviews/maps/img tools/maptour
files=""
for pc in $pieces; do
	"$B" -b -P art/blender/map_kit.py -- art/models/mapkit/mapkit_${pc}_${theme}.fbx $pc $theme 2>&1 | grep -E "TRIANGLES|Error|Traceback|line [0-9]" | sed "s/^/$pc $theme: /"
done
for pc in wall low arch pillar bridge set face stairs; do
	[ -f art/models/mapkit/mapkit_${pc}_${theme}.fbx ] && files="$files art/models/mapkit/mapkit_${pc}_${theme}.fbx"
done
tiles=$("$B" -b -P art/blender/map_kit_view.py -- tools/maptour/kit_${theme}.png $files 2>&1 | grep "^TILES" | sed 's/^TILES //')
python - "$tiles" "reviews/maps/img/kit-${theme}.jpg" <<'PY'
import sys
from PIL import Image
tiles = [Image.open(p).convert("RGB") for p in sys.argv[1].split("|") if p]
w, h = tiles[0].size
sheet = Image.new("RGB", (3 * w, ((len(tiles) + 2) // 3) * h))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % 3) * w, (i // 3) * h))
sheet.save(sys.argv[2], quality=88)
print("sheet", sys.argv[2])
PY
