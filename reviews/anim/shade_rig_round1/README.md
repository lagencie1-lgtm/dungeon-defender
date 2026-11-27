# Shade rig, round 1 (2026-11-25)

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/152550_ghost_character_3d_model.glb art/models/rigged/shade_rigged.fbx shade 2.8 reviews/anim/shade_rig_round1 robe
```

This one is **not uploaded**: it waits for Lemp's OK.

**New body plan, "robe":** for a ghost, or any monster whose legs are hidden under a robe or dress.

- **Bones:** no leg bones. Instead there are four hem bones (`Hem.F`/`B`/`L`/`R`) running from the hips down to the front, back and sides of the hem. Everything below the hips may only follow Hips and the hem bones.
- **Test pose:** knees_45 is replaced by `hem_sway` (front and back swung 25 degrees, sides twisted 15).
- **MonsterAnim:** a rig without legs gets the new "float" gait (`MonsterMoves.Float`). It bobs, leans into the glide, rolls a little, the hem trails back while it moves and sways side to side, and the sleeves drift.

**Weapon detection:** it now also requires the piece to stick out of the body's outline. A cloak piece next to the right hand was taken for a weapon. The goblin and the imp still find none, as before.

## Numbers (`numbers.txt`)

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head (the hood):** 0 of its 442 rigid vertices are on another bone.
- **Edges over 1.6x the rest length:**

  | pose | max | edges over 1.6x | of them grown > 0.03 studs |
  |---|---|---|---|
  | swing | 1.53x | 0 | 0 |
  | head_turn | 1.69x | 1 | 1 |
  | arms_up | 2.73x | 14 | 14 |
  | hem_sway | 3.51x | 20 | 19 |

The stretch in hem_sway sits in the torn cloth flaps where two hem bones meet.

**Sheets:** sleeves rise cleanly, the hem trails back and sways, and the hood turns without tearing.
