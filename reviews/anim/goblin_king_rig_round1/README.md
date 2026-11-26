# Goblin King rig, round 1 (2026-11-25)

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/151010_goblin_king_3d_model.glb art/models/rigged/goblin_king_rigged.fbx goblin_king 4.2 reviews/anim/goblin_king_rig_round1
```

This one is **not uploaded**: it waits for Lemp's OK.

## New: hand-marked key points (`art/blender/rig_landmarks/<name>.json`)

**Why:** the automatic landmarks failed on the King. His club, cape and crown put the shoulders, hands and crotch in the wrong places, and the cape was taken for wings.

**How it works:** a small file per monster gives the key points in studs, the way the script places the model (front -Y, left +X, standing on the ground).

- **The points:** crotch, hips, chest, neck, head top; shoulder, elbow, wrist and hand tip for each arm; hip, knee, ankle and toe for each leg.
- **What the script does with them:** it puts every main joint there, uses them for the vertex masks, and does no tail or wing guessing.
- **How I read the King's points:** from front and side renders with a stud grid. The tool for those renders is not committed yet.

**Cloth chains:** the file can add bone chains for cloth (`chains`). The King has a cape of 3 chains x 3 bones (left, centre, right) hanging from the Chest. They are never wings.

- **Which vertices count as cape:** colour (`cloth_colors`, here the red cape and its fur, read from the texture) and nearness to a chain bone.
- **Colour clean-up:** the colour mask is cleaned by a neighbourhood vote, because paint noise made single vertices flip.
- **Cape vertices:** they may only follow Chest, Spine, Hips and their own chain.

**Weapon:**

- It is looked for at both hands. The King's club is in his left hand; the Weapon bone hangs from Hand.L and the swing test mirrors to the left arm.
- Small pieces lying inside the weapon's box join it: 21 vertices of spikes and bands. These used to stay behind, floating, when the club swung.

## Numbers (`numbers.txt`), at the angles monsters really use

- **Weights:** 0 zero-weight vertices and 0 vertices with more than 4 bones.
- **Head:** 0 of its 591 rigid vertices are on another bone.
- **Club:** 0 of its 241 vertices are on another bone.
- **Edges over 1.6x the rest length:**

  | pose | max | edges over 1.6x | of them grown > 0.04 studs |
  |---|---|---|---|
  | arms_up | 7.54x | 71 | 71 |
  | swing | 6.58x | 89 | 85 |
  | knees_45 | 5.71x | 72 | 65 |
  | head_turn | 3.00x | 24 | 23 |

**Not good enough yet.**

- **Raised arms:** the cape's front edges wrap round both arms. When the arms rise, a flat wedge of cape stretches between arm and hem (front views of `goblin_king_arms_up.jpg`).
- **Swing:** in the club swing a few cape pieces tear at the club side.
- **What I tried:** cutting the cape off the body all along its colour edge, and cutting it off the arms by colour. Both shredded the cape into shards, so both are off (`cut_cloth_edge` in the file turns the first back on).
- **What would fix it:**
  1. Have the cape remade as its own piece (garment) by the 3D generator or by hand.
  2. Keep the King's arm moves small (his slam and charge barely lift the arms).
