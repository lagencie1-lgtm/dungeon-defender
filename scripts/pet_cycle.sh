#!/usr/bin/env bash
# One pet improvement cycle step: builds pets with the clay kit (art/blender/pets2.py + petkit.py), measures the
# shape against the pet's blueprint (front / side / back, scripts/pet_blueprint.py), renders it lit like the engine
# and makes the labelled comparison sheet.
#   bash scripts/pet_cycle.sh <kind> [<kind> ...]        e.g. bash scripts/pet_cycle.sh emberfox slimey
# Output: art/models/pets2/pet_<kind>.fbx + _paint.png + _keep.png,
#         reviews/pets/img/_cycle_<kind>.png  (TARGET | NEW front | NEW other side | NEW back | OLD | phone size)
#         reviews/pets/img/_blue_<kind>.png   (blueprint, model and overlay: red = add clay, blue = remove)
# NOBUILD=1 skips the build and the blueprint check (use after scripts/pet_paint.py: renders the painted pet).
cd "$(dirname "$0")/.."
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
ANGLES="24 -50 160 -35 -20 0 10 35 50"   # all of them are tried for the measured match with the target picture
mkdir -p art/models/pets2/paint reviews/pets/img
for kind in "$@"; do
  if [ -z "$NOBUILD" ]; then
    "$B" -b -P art/blender/pets2.py -- "$PWD/art/models/pets2/pet_$kind.fbx" "$kind" 2>&1 | grep -E "TRIANGLES|HEIGHT|Error|Traceback|line [0-9]" | sed "s/^/$kind: /"
    rm -f "art/models/pets2/pet_${kind}_base.png"   # a fresh build has a fresh plain texture
    "$B" -b -P art/blender/pet_project.py -- views "art/models/pets2/pet_$kind.fbx" "art/models/pets2/pet_${kind}_paint.png" "art/models/pets2/paint/${kind}_views.png" 2>&1 | grep -E "Error|Traceback"
    if [ -f "art/ref3d/turn/$kind.png" ]; then python -W ignore scripts/pet_blueprint.py check "$kind"; fi
  fi
  rm -f art/models/pets2/_v_${kind}_*.png art/models/pets2/_lit_${kind}_*.png
  "$B" -b -P art/blender/pet_render.py -- "art/models/pets2/pet_$kind.fbx" "art/models/pets2/pet_${kind}_paint.png" "art/models/pets2/_v_${kind}" $ANGLES 2>&1 | grep -E "Error|Traceback"
  HTD_LIT=1 "$B" -b -P art/blender/pet_render.py -- "art/models/pets2/pet_$kind.fbx" "art/models/pets2/pet_${kind}_paint.png" "art/models/pets2/_lit_${kind}" 24 -50 160 2>&1 | grep -E "Error|Traceback"
  if [ ! -f "art/models/pets2/_old_${kind}_24.png" ]; then
    "$B" -b -P art/blender/pet_render.py -- "art/models/pet_$kind.fbx" "art/models/pet_${kind}_paint.png" "art/models/pets2/_old_${kind}" 24 2>&1 | grep -E "Error|Traceback"
  fi
  python -W ignore scripts/pet_match.py "$kind"
done
