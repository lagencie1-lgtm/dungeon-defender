#!/usr/bin/env bash
# One pet improvement cycle step: builds second-generation pets (art/blender/pets2.py), renders each from three
# sides next to its target picture and the old model, and prints the measured match (scripts/pet_match.py).
#   bash scripts/pet_cycle.sh <kind> [<kind> ...]        e.g. bash scripts/pet_cycle.sh emberfox slimey
# Output: art/models/pets2/pet_<kind>.fbx + _paint.png, and the comparison sheet reviews/pets/img/_cycle_<kind>.png
# NOBUILD=1 skips the build (only renders and scores what is there).
cd "$(dirname "$0")/.."
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
mkdir -p art/models/pets2 reviews/pets/img
for kind in "$@"; do
  if [ -z "$NOBUILD" ]; then
    "$B" -b -P art/blender/pets2.py -- "$PWD/art/models/pets2/pet_$kind.fbx" "$kind" 2>&1 | grep -E "TRIANGLES|HEIGHT|Error|Traceback|line [0-9]" | sed "s/^/$kind: /"
  fi
  for a in 24 -50 160; do
    HTD_ANGLE=$a "$B" -b -P art/blender/tripo_fix.py -- "art/models/pets2/pet_$kind.fbx" "art/models/pets2/pet_${kind}_paint.png" "art/models/pets2/_v_${kind}_$a.png" 2>&1 | grep -E "Error|Traceback"
  done
  HTD_ANGLE=24 "$B" -b -P art/blender/tripo_fix.py -- "art/models/pet_$kind.fbx" "art/models/pet_${kind}_paint.png" "art/models/pets2/_old_${kind}.png" 2>&1 | grep -E "Error|Traceback"
  python scripts/pet_match.py "$kind"
done
