# Ember Imp rig, round 1 (2026-11-25)

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/152358_lava_devil_3d_model.glb art/models/rigged/imp_rigged.fbx imp 2.8 reviews/anim/imp_rig_round1
```

This one is **not uploaded**: only the goblin was approved, so the imp needs Lemp's OK first.

**Mesh:** 3,320 triangles and 1,670 vertices. It keeps its UVs, has no vertex colours, and stands 2.8 studs tall.

**Centring:** the model is now centred on its feet (the lowest tenth of the mesh) instead of its bounding box. The long tail used to pull the box centre back by half a stud.

## New in the pipeline (rig_monster.py), for monsters that have them

- **Tail:** mesh lying behind the back (measured at the chest), below the chest. It gets a chain `Tail1`-`Tail3` from the base of the spine out to the tip (74 vertices here). Its vertices may only follow Hips and the tail bones.
- **Wings:** mesh out past the shoulders, from the armpits up, behind the arms. It gets `Wing.L` / `Wing.R` on the Chest (34 vertices each). Its vertices may only follow Chest and their wing bone. A wing welded to the arm beside it is cut loose (34 welded edges).
- **MonsterAnim:**
  - The tail swishes side to side, each bone a little behind the one before, wider while moving (`MonsterMoves.Tail`).
  - The wings are held a little open and beat (`MonsterMoves.Wings`).
  - Both only run on rigs that have those bones.

Checked: re-rigging the goblin with the new pipeline finds no tail or wings and gives the same numbers as before.

## Numbers (`numbers.txt`), at the angles monsters really use

Head turn 25, arms up 60, swing 100, knees 45.

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head:** 0 of its 623 rigid vertices are on another bone.
- **Edges over 1.6x the rest length:**

  | pose | max | edges over 1.6x | of them grown > 0.03 studs |
  |---|---|---|---|
  | knees_45 | 1.37x | 0 | 0 |
  | head_turn | 1.81x | 6 | 5 |
  | swing | 16.99x | 46 | 38 |
  | arms_up | 12.44x | 78 | 72 |

**Not met:** arms_up and swing stretch more than on the goblin. The imp's short arms grow straight out of a round body, with the wing roots right behind the shoulders, so raising an arm 60 degrees pulls the skin at the armpit and the wing root.

On the sheets the arms rise cleanly and the wings and tail stay in place. The stretch sits in the armpit band (36-63% of the height). The same options apply as for the goblin: smaller arm angles in the imp's moves, or a corrective bone.

## Sheets

The poses are rest, arms up, swing, knees 45 and head turn. Each sheet shows the painted model on top and grey below, from 8 sides.
