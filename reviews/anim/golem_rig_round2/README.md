# golem rig, round 2 (2026-11-26): rigid with joined seams

**Built by:**

```
blender --background --python art/blender/rig_monster.py -- art/tripo-in/<model>.glb art/models/rigged/golem_rigged.fbx golem 4.0 reviews/anim/golem_rig_round2 rigid
```

This one is **not uploaded**.

**What changed since round 1:**

- **Joined seams:** the body's seams are no longer cut. Their vertices blend between the two bones, so nothing opens. In round 1 the gaps behind the shoulders were 0.6-2.1 studs.
- **Pieces kept whole:** only hand-marked pieces are cut loose, and a box takes whole mesh islands. On the knight that is the sword, the shield and the cape.
- **Caps:** every cap faces outward.
- **Angles:** the tests use the angles in the key-points file (`test_angles`).

**Numbers:** in `numbers.txt`. There are no gaps over 0.3 studs in any pose, and the seam stretch per pose is listed. The 8-side sheets show no holes.
