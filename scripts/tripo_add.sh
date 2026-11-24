#!/usr/bin/env bash
# Takes a model the Tripo bridge saved (art/tripo-in/*.glb), cleans it in Blender, renders a preview and uploads
# it with its texture as a game model.   bash scripts/tripo_add.sh <file.glb> <model_name> [triangles] [texture]
# e.g. bash scripts/tripo_add.sh art/tripo-in/151010_goblin_king_3d_model.glb boss_goblin_king 5000 1024
cd "$(dirname "$0")/.."
glb="$1"; name="$2"; tris="${3:-3000}"; tex="${4:-1024}"
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b -P art/blender/tripo_clean.py -- "$glb" "$PWD/art/models/$name.fbx" "$tris" "$tex" 2>&1 | grep -E "TRIANGLES|TEXTURE|EXPORTED|Error|Traceback"
"$B" -b -P art/blender/tripo_fix.py -- "art/models/$name.fbx" "art/models/${name}_paint.png" "art/models/${name}_preview.png" 2>&1 | grep -E "PREVIEW|Error|Traceback"
cp "art/models/${name}_paint.png" "tools/art-paint/paint_$name.png"
python - "$name" <<'PY'
import re, sys
name = sys.argv[1]
p = 'src/shared/Art.luau'; s = open(p, encoding='utf-8').read()
slot = 'paint_' + name
if re.search(r'\n\t' + slot + r' = "\d*",', s):
    s = re.sub(r'(\n\t' + slot + r' = )"\d*",', r'\1"",', s)   # new paint: upload again
else:
    s = s.replace('\tpaint_map_rift = ', '\t' + slot + ' = "",\n\tpaint_map_rift = ', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
python scripts/upload_art.py tools/art-paint "$tex" 2>&1 | tail -1
if grep -q "	$name = \"[0-9]" src/shared/Art.luau; then python scripts/upload_models.py --force "$name" 2>&1 | tail -1; else python scripts/upload_models.py 2>&1 | tail -1; fi
