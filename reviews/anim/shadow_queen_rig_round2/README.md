# Shadow Queen rig, round 2 (2026-11-25)

**Changes from round 1:**

- each sleeve chain has a third bone (elbow down to 1.35)
- her test angles are what her summon and cast need: arms 45, swing 60, head 25

## Numbers (`numbers.txt`)

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head:** 0 of its 586 rigid vertices are on another bone.
- **Edges over 1.6x the rest length:**

  | pose | edges over 1.6x | of them grown > 0.04 studs |
  |---|---|---|
  | hem_sway | 12 | 10 |
  | head_turn | 96 | 88 (where the long hair meets the shoulders) |
  | arms_up 45 | 233 | 215 |
  | swing 60 | 426 | 389 |

**On the sheets:**

- **Head turn and dress:** they read clean.
- **Raised arm:** the sleeve under it still hangs as a flat, box-like drape.
- **Swing:** a few sharp folds where the sleeve meets the bodice.

The Tripo mesh builds each wide sleeve as one thick slab fused to the arm and bodice, and a 4-bone skin cannot fold that slab softly.

**Her moves for now:** keep her arms near the body. A summon with the hands lifted from the elbows, not the shoulders, reads well on the sheets.

**Next:** a cleaner fix would be sleeves as separate pieces, like the cape attempt on the King.
