# Goblin King rig, round 2 (2026-11-25): small arm moves (option 2)

**Option 1, the cape cut off as its own piece by script, is not clean.** It is in `rig_monster.py` as `separate_cloth`, off for the King. What it does:

1. splits the colour-found cape faces off the body
2. closes the hole with a patch painted from the body's rim
3. gives the cape a thin back face
4. skins the cape only to its chains and the chest

What I saw on the 8-side sheets:

- The fur collar came loose from the body.
- Cape pieces next to the arms were still dragged into wedges and shards, because the cape's front edges wrap round the arms in the model itself.

Following the plan, after two rounds I fell back to **option 2**: the King's arm moves stay small. The angles he really uses are now in his key-points file (`test_angles`): arms raised 35, club swing 55, head 20.

## Numbers at those angles (`numbers.txt`)

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head:** 0 of its 591 rigid vertices are on another bone.
- **Club:** 0 of its 241 vertices are on another bone.
- **Edges over 1.6x the rest length:**

  | pose | max | edges over 1.6x | of them grown > 0.04 studs |
  |---|---|---|---|
  | head turn 20 | 2.61x | 14 | 13 |
  | arms up 35 | 4.81x | 46 | 46 |
  | swing 55 | 5.01x | 73 | 70 |
  | knees 45 | 5.59x | 71 | 64 |

**On the sheets:** the arm raise and the club swing read clean. One small cape wedge shows by the right arm in the front view. The cape hangs and the club stays whole.

**For his moves:** the slam's wind-up should lift the club arm about 35-55 degrees, not 90. A bigger tell has to come from the body: a lean back, a crouch and the club overhead from the wrist, plus the slam ring the game already shows.
