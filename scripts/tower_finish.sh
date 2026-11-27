# (tracked copy of tools/tower_finish.sh, 2026-11-27: tools/ is not in git. Art.Icons and Art.Models both have
# tower_ranger_l1..3: the blanking below only touches the tables after Art.Icons, so an upload never lands in an icon's line)
# copy a finished tower's three levels into art/models, upload model + paints as new assets, print heights and muzzles
cd /c/Projects/RealmGuardians
k=$1
D=tools/${k}f
rm -rf tools/up_$k; mkdir -p tools/up_$k/1024 tools/up_$k/512
names=""
for l in ${LEVELS:-1 2 3}; do   # (LEVELS="3": only re-upload the levels that changed)
  n=tower_${k}_l$l
  cp $D/$n.fbx art/models/$n.fbx
  cp $D/${n}_paint.png art/models/${n}_paint.png; cp $D/${n}_paint.png tools/up_$k/1024/paint_$n.png; names="$names $n paint_$n"
  for f in $D/${n}_paint_*.png; do
    s=$(basename $f .png); s=${s#${n}_paint_}
    case $s in base*|*front*) continue;; esac
    cp $f art/models/${n}_paint_$s.png; cp $f tools/up_$k/512/paint_${n}_$s.png; names="$names paint_${n}_$s"
  done
done
python - $names <<'PY'
import re, sys
p='C:/Projects/RealmGuardians/src/shared/Art.luau'; s=open(p,encoding='utf-8').read()
# (2026-11-27: only below Art.Icons: Icons has its own tower_ranger_l1..3 pictures, which a blank here wiped and the
# next upload filled with a model id)
i = s.index('\nArt.Models = {'); head, s = s[:i], s[i:]
for k in sys.argv[1:]:
    s,c=re.subn(r'(\n\t'+k+r' = )"\d*",', r'\1"",', s)
    print('blank', k, c)
open(p,'w',encoding='utf-8').write(head + s)
PY
python scripts/upload_art.py tools/up_$k/1024 1024 2>&1 | grep uploaded
python scripts/upload_art.py tools/up_$k/512 512 2>&1 | grep uploaded
python scripts/upload_models.py 2>&1 | grep -i "uploaded\|error" | grep $k
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python-expr "
import bpy
from mathutils import Vector
for l in (1,2,3):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=r'art/models/tower_${k}_l%d.fbx'%l)
    zs=[(o.matrix_world@Vector(c)).z for o in bpy.context.scene.objects if o.type=='MESH' for c in o.bound_box]
    print('HEIGHT tower_${k}_l%d %.2f'%(l,max(zs)-min(zs)))
" 2>&1 | grep HEIGHT
grep -h MUZZLE tools/round_${k}2.log 2>/dev/null
echo FINISH DONE
