# Goblin rig, round 1 (2026-11-25)

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/144634_goblin_character_3d_model.glb art/models/rigged/goblin_rigged.fbx goblin 2.8 reviews/anim/goblin_rig_round1
```

I ran it with Blender 5.2 on Lemp's PC. Nothing was uploaded or published.

**Output:**

- `art/models/rigged/goblin_rigged.fbx`: the armature `goblin_rig` is the parent of the mesh `goblin`. There are no leaf bones and the texture is embedded.
- `goblin_rigged_paint.png`: the texture at 1024, beside the FBX.

**Mesh:** 3,334 triangles and 1,701 vertices after merging the generator's split seams. It keeps its UVs and has no vertex colours. It stands 2.8 studs tall, faces -Y, and its left is +X.

**Weapon:** none. Nothing reaches out of either hand, so there is no Weapon bone.

## Sheets

Each sheet has the painted model on top and grey below, from 8 sides: front, then every 45 degrees round to the left.

- **`goblin_rest.jpg`:** the rest pose.
- **`goblin_arms_up.jpg`:** both upper arms raised 90 degrees to the side. The forearms keep their bend.
- **`goblin_swing.jpg`:** a club swing. The right arm is overhead and back 120 degrees with the elbow bent 40, the chest twisted 25, and the left arm forward 35.
- **`goblin_knees_45.jpg`:** thighs forward 25 and shins back 45 relative to them, so the knees are bent 45. The feet lift because the hips do not drop in this test pose.
- **`goblin_head_40.jpg`:** the head turned 40 degrees. The shoulder pads stay put.

## Numbers (`numbers.txt`)

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head:** 0 of its 619 rigid vertices are on another bone. No weapon was found, so there is no weapon check.
- **Edges over 1.6x the rest length:**

  | pose | max | edges over 1.6x | of them grown > 0.03 studs |
  |---|---|---|---|
  | arms_up | 6.47x | 38 | 37 |
  | swing | 5.98x | 44 | 39 |
  | knees_45 | 1.45x | 0 | 0 |
  | head_40 | 9.31x | 41 | 41 |

**Not met: "no edge over 1.6x".** Every remaining stretched edge is in the band where the shoulders, the vest collar and the jaw meet: 46-66% of the height, 11-24% of it out from the middle.
This chibi goblin has almost no neck (the jaw rests on the shoulder pads) and its armpits are welded into the vest. A plain 4-bone skin cannot raise an arm 90 degrees or turn the head 40 degrees there without stretching some short edges.

**What I tried and kept or dropped:**

- **Dropped: cutting the jaw-to-pad welds.** It halved the stretched edges in head_40 (15 left) but opened holes between the pads and the vest collar when the arms rose.
- **Kept: limb masks and the rigid-head rule.** Each vertex only follows its own limb, and pads that reach up beside the jaw are not part of the rigid head. This took head_40 from a dragged shoulder strap to a clean turn on the sheet, and arms_up shows no holes.
- **Kept: weight smoothing around the stretched edges.** It ran 12 rounds and kept the best round. It barely moves the count: the stretch is geometric, not a weight error.

To reach the 1.6x target in those two poses, the options are:

1. **Smaller test angles,** closer to what a goblin animation uses (arms 60 degrees, head 25).
2. **A neck ring:** a corrective second Neck bone or a twist bone at the collar.
3. **Re-meshing the shoulders,** so the pads are separate pieces.

## Bones (rest, studs; front -Y, left +X)

| bone | parent | head | tail |
|---|---|---|---|
| Root | - | 0.00 0.00 0.00 | 0.00 0.00 0.34 |
| Hips | Root | 0.00 0.15 0.79 | 0.00 0.19 0.91 |
| Spine | Hips | 0.00 0.19 0.91 | 0.00 -0.11 1.22 |
| Chest | Spine | 0.00 -0.11 1.22 | 0.00 0.04 1.61 |
| Neck | Chest | 0.00 0.04 1.61 | 0.00 0.04 1.66 |
| Head | Neck | 0.00 0.04 1.66 | 0.00 0.04 2.80 |
| UpperArm.L | Chest | 0.73 0.18 1.58 | 0.88 0.19 1.19 |
| LowerArm.L | UpperArm.L | 0.88 0.19 1.19 | 1.03 0.03 0.81 |
| Hand.L | LowerArm.L | 1.03 0.03 0.81 | 1.06 0.03 0.60 |
| UpperArm.R | Chest | -0.73 0.12 1.58 | -0.88 0.15 1.20 |
| LowerArm.R | UpperArm.R | -0.88 0.15 1.20 | -1.04 0.02 0.81 |
| Hand.R | LowerArm.R | -1.04 0.02 0.81 | -1.06 0.02 0.60 |
| UpperLeg.L | Hips | 0.37 0.15 0.68 | 0.40 0.11 0.41 |
| LowerLeg.L | UpperLeg.L | 0.40 0.11 0.41 | 0.42 0.25 0.15 |
| Foot.L | LowerLeg.L | 0.42 0.25 0.15 | 0.42 -0.16 0.03 |
| UpperLeg.R | Hips | -0.37 0.15 0.68 | -0.40 0.11 0.41 |
| LowerLeg.R | UpperLeg.R | -0.40 0.11 0.41 | -0.42 0.25 0.15 |
| Foot.R | LowerLeg.R | -0.42 0.25 0.15 | -0.42 -0.16 0.03 |

The landmarks it found:

- crotch 0.68
- shoulders 1.58
- neck (under the chin) 1.66
- hands at ±1.06, down to 0.60
- feet at ±0.42

The FBX re-imports with the same 18 bones, 17 vertex groups (Root carries no skin) and at most 4 influences per vertex.
