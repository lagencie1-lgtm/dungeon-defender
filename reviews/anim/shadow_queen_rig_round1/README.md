# Shadow Queen rig, round 1 (2026-11-25)

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/151735_purple_sorceress_3d_model.glb art/models/rigged/shadow_queen_rigged.fbx shadow_queen 4.2 reviews/anim/shadow_queen_rig_round1 robe
```

This one is **not uploaded**.

**Skeleton:** hand-marked key points (`art/blender/rig_landmarks/shadow_queen.json`), read off front and side grid renders. She uses the robe body plan: no legs under the dress, four hem bones from the hips.

**Wide sleeves:** each is a cloth chain (`SleeveL`/`SleeveR`, 2 bones) hanging from the forearm.

- **Not cut loose** (`"cut_arm_cloth": false`): cutting sleeves off the arms left floating hands.
- **Short reach** (`radius` 0.45 studs): a sleeve only takes cloth close to it. Without that, dress vertices near the ground were pulled up to the hands in long spikes.

## Numbers (`numbers.txt`)

Angles from her file: arms 60, swing 80, head 25.

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head (hair and crown):** 0 of its 586 rigid vertices are on another bone.
- **Edges over 1.6x the rest length:**

  | pose | max | edges over 1.6x | of them grown > 0.04 studs |
  |---|---|---|---|
  | hem_sway | 6.68x | 24 | 18 |
  | head_turn | 3.43x | 95 | 88 (where the long hair meets the shoulders) |
  | arms_up | 49.63x | 281 | 259 |
  | swing | 28.82x | 472 | 426 |

**What the sheets show:**

- **Arms up:** the arms rise with the sleeves hanging from them like drapes. That is right for wide sleeves, but in the front views they show as flat panels.
- **Swing:** sharp folds where sleeve and bodice meet.
- **Turns and dress:** the head turn and the hem sway read clean.

**Next round:** a third sleeve bone and a lower test angle for the spell-cast raise (the Queen's moves are summons, so arms at about 45 would do), then re-check.
