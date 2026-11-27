# boss_molten_golem rig, round 1 (2026-11-26): rigid pieces

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/<model>.glb art/models/rigged/boss_molten_golem_rigged.fbx boss_molten_golem 4.0 reviews/anim/boss_molten_golem_rig_round1 rigid
```

The key points are in `art/blender/rig_landmarks/boss_molten_golem.json`. This one is **not uploaded**.

## The rigid body plan

**Why:** rock and armour are hard pieces, not skin, so the model is cut into pieces.

1. Every face takes the bone nearest it. Hand-marked boxes can override this: on the knight they keep the sword, the shield and the cape whole.
2. The labels are smoothed three times by neighbour vote, so the cuts run straight.
3. A mesh island (one rock, one plate) stays whole when 80% of it is one bone's.
4. The mesh is cut where the labels meet, and every opening is closed with a cap wearing its rim's paint.
5. Every vertex follows exactly one bone (weight 1).

The same bone names as the other rigs, so MonsterAnim's walk, attack, hit and fall work unchanged.

## Numbers (`numbers.txt`)

- **Weights:** 0 zero-weight vertices and 0 vertices on more than one bone.
- **Gaps:** the widest gap opening at a cut, for each test pose, is listed with the two pieces it is between.

**On the sheets:** the pieces turn cleanly as hard parts.

- **Shoulder gap:** where the shoulder opens at large arm angles, a dark gap shows behind the shoulder (seen from behind).
- **Black specks:** a few small black triangles show where a cap faces inward.
- **Next round:** turn the inward caps around, and overlap the shoulder pieces so the gap stays hidden at the angles the monster really uses.
