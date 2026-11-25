# Magma Slime rig, round 1 (2026-11-25)

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/152728_lava_slime_3d_model.glb art/models/rigged/slime_rigged.fbx slime 2.2 reviews/anim/slime_rig_round1 slime
```

This one is **not uploaded**: it waits for Lemp's OK.

## New body plan, "slime"

**Bones:**

- a column `Root` → `Body1` → `Body2` → `Body3` → `Top` up the middle
- four bulge bones `Bulge.F`/`B`/`L`/`R` from the middle of the widest ring (here near the base) out to its edge

The weights are automatic, smoothed twice, limited to 4 bones and normalized. There are no masks: a blob has no limbs to leak between.

**Squash and stretch (bones only, no scale anywhere):**

- **Squash:** the column sinks and the bulges push out.
- **Stretch:** the column rises and the bulges pull in.

**MonsterAnim:** a slime rig gets the "hop" gait (`MonsterMoves.Hop`), driven by the distance really travelled.

1. It lands squashed, then pushes off.
2. It springs up tall and thin and flies a small arc.
3. It squashes again on landing.

A spring smooths the squash. When standing it breathes, and the top wobbles.

## Numbers (`numbers.txt`)

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Poses:**

  | pose | max stretch | edges over 1.6x | most squeezed | edges under 1/1.6 | lowest point |
  |---|---|---|---|---|---|
  | squash (column -22% of height, bulges out) | 1.92x | 10 | 0.80x | 0 | 0.000 |
  | stretch | 1.22x | 0 | 0.67x | 0 | 0.000 |
  | wobble (12 degrees) | 1.31x | 0 | 0.75x | 0 | 0.000 |

  The lowest point stays at the ground in every pose.

**Sheets:** the squash reads wide and low, and the stretch tall and narrow. A small bump shows at the back in the squash, where `Bulge.B` pushes the drip lobe out.
