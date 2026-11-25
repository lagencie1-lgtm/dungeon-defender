# Monster and hero animation: summary (2026-11-26)

**How the monsters are rigged:** every rig is built by `art/blender/rig_monster.py`. The arguments are `in.glb out.fbx name height sheets plan`, where plan is one of humanoid / robe / slime / rigid. Hand-marked key points for the hard models are in `art/blender/rig_landmarks/<name>.json`.

**How they move:** in game everything is driven from code with springs: `src/client/MonsterAnim.client.luau`, with every number in `src/shared/MonsterMoves.luau`. Heroes use `HeroAnim` and `HeroMoves`.

**Uploads:** only the goblin is uploaded (private, with Lemp's OK). Every other FBX below waits for Lemp's typed OK.

**What the numbers mean:**

- **"Edges over 1.6x":** mesh edges stretched more than 1.6 times their rest length in that test pose. They show at joints and are mostly hidden on the sheets.
- **Gaps:** for the rigid models, how far apart the two sides of a cut open (target: none over 0.3 studs).

| monster | rig | tested angles (arms / swing / head / knees) | measured | open issues |
|---|---|---|---|---|
| Goblin (uploaded) | humanoid | 60 / 100 / 25 / 45 | over-1.6x edges: arms 21, swing 25, head 11, knees 0. In game: planted foot slides 0.013-0.015 studs per step, 2.8 steps/s, bob 0.33-0.36 studs. Within dE 8.7 of the old goblin's colour | none blocking (`goblin_ingame_round2`) |
| Ember Imp | humanoid + tail (3 bones) + wings | 60 / 100 / 25 / 45 | over-1.6x edges: arms 78, swing 46, head 6, knees 0 | armpit and wing roots stretch at 60 (`imp_rig_round1`) |
| Shade | robe (4 hem bones) | 60 / 100 / 25 / hem sway | over-1.6x edges: arms 14, swing 0, head 1, hem 20 | torn flaps stretch a little in the hem sway (`shade_rig_round1`) |
| Magma Slime | slime (body column + 4 bulges) | squash 22% / stretch / wobble 12 | squash 10 edges over 1.6x, nothing squeezed under 1/1.6, never below the ground | small bump at the back in the squash (`slime_rig_round1`) |
| Goblin King (boss) | humanoid, hand-marked, cape chains (3x3), club | 35 / 55 / 20 / 45 | over-1.6x edges: arms 46, swing 73, head 14, knees 71 | the cape wraps the arms: keep arm moves small (option 2). The separate-cape option is off (`goblin_king_rig_round2`) |
| Shadow Queen (boss) | robe, hand-marked, sleeve chains (2x3) | 45 / 60 / 25 / hem sway | over-1.6x edges: arms 233, swing 426, head 96, hem 12 | sleeves hang as flat slabs when an arm rises: keep her arms near the body (`shadow_queen_rig_round2`) |
| Molten Golem (boss) | rigid, joined seams | 45 / 70 / 25 / 45 | **0 gaps** over 0.3 studs (no cuts). Seam stretch, edges over 1.6x: arms 149, swing 143, head 75, knees 62 | lava cracks stretch at the shoulders, which reads as glowing cracks (`boss_molten_golem_rig_round2`) |
| Golem | rigid, joined seams | 45 / 70 / 25 / 45 | **0 gaps**. Seam stretch, edges over 1.6x: arms 74, swing 88, head 21, knees 23 | same as the boss (`golem_rig_round2`) |
| Obsidian Knight | rigid, joined seams; sword, shield and cape kept whole | 45 / 80 / 25 / 45 | **0 gaps**. Seam stretch, edges over 1.6x: arms 110, swing 90, head 25, knees 44 | the cape follows the shoulders a little when the arms rise (`knight_rig_round2`) |

## Rigid round 2: what changed

- **Joined seams instead of cuts:** cutting every seam left gaps of 0.6-2.1 studs behind the shoulders. The body's seams now stay joined, and their vertices blend between the two bones, like a crack that stretches.
- **Pieces made whole by island:** hand-marked boxes now take whole mesh islands (those with most of their area inside the box). Taking single faces left slivers of the knight's shield on his leg.
- **Caps face outward:** every cap's normal is recalculated.
- **8 sides:** all three models were checked from 8 sides, painted and grey. No gap shows.

## Heroes

- **`round1`:** the hero animation test. It found that HeroAnim did not move the hero at all on the new Roblox joints, and fixed that and the floating feet.
- **`round2`:** the knock-out now lies on its back on the ground.
