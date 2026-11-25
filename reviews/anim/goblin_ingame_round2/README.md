# Rigged goblin in game, round 2 (2026-11-25)

**What is new:** Lemp's "Bouncy run", the hit direction, a death filmed with one goblin alone, and the colour check.

**Setup:** one goblin spawned alone on an empty path in Cursed Forest, filmed at iPhone 13 landscape (device simulator, graphics 1). The rig is `test/anim-goblin.project.json`. The clip starts 10 s after the marks' zero.

## Bouncy run (`MonsterMoves.Run`, `Gaits.Goblin = "run"`)

**Each step:**

- **Contact:** one foot is planted. Its leg is solved so the foot stays on the spot it landed on, and the knee gives up to `Squash` 34 degrees, then straightens to push off.
- **Hop:** both feet are up and the body follows an arc `Hop` 0.045 x height high. It starts and ends at the height the legs leave and land at.

**The rest of the body:** arms pump 34 degrees with the elbows bent 55, the body leans 10 degrees forward (the legs are leaned back by the same amount so the lean does not move the feet), and the head lags the bob on its spring.

**Step rate:** `StepRate` 2.75 steps/s sets it. The step length follows the monster's real speed, capped at `MaxStep` 3 leg lengths.

**Planted-foot correction:** after posing, the planted foot is checked against the spot it landed on. The planted leg turns by what is left, forwards and sideways, in the same frame. The ideal-leg solve alone let it creep 0.09 studs per contact, and it slid up to 0.9 studs at path corners.

| measured (`numbers_phone.txt`) | side, straight path | 3/4, incl. a path corner |
|---|---|---|
| step rate | 2.80 steps/s | 2.76 steps/s |
| planted-foot slide per contact (inside MonsterAnim, right after posing) | 0.013 studs (worst 0.018) | 0.015 studs (worst 0.022) |
| same, read by the test script a frame later (frame-order noise at 15 fps) | 0.041 | 0.040 |
| hips bob (top to bottom) | 0.36 studs | 0.33 studs |

## Hit direction

**Server:** `EnemyService.Damage(..., from)` writes `HitFromX` and `HitFromZ` next to `HitAt` for rigged monsters. The callers pass:

- **hero blows:** the hero's position
- **Ranger, Frost, Ballista, turret:** the tower's position
- **Flame Cannon:** the blast centre
- **Storm:** the chain's previous point
- **pet pounce:** the hero

**Client:** MonsterAnim rocks away from that point. It falls back to the nearest hero only when no point came with the hit. In this run the hero stood at the goblin's side and the hits carried `HitFromX = -31.0`, `HitFromZ = -7.3`.

## Death, one goblin alone (`phone_knockout_alone.jpg`, 14 frames/s)

The knees give, it falls forward onto its face, and it is removed 0.7 s after Dead. No other goblin is in the shot.

## Colour

All numbers are CIE Lab dE, at graphics level 1, for the skin pixels of the phone frames.

| compared | dE |
|---|---|
| rigged goblin in game vs the old (solid) goblin in game, same map | 8.7 |
| rigged goblin in game vs its paint texture | 14.5 (the texture is lighter: in the shade of the path it renders darker) |

**Colours sampled:**

- rigged goblin in game: (109, 131, 22)
- old goblin in game: (132, 140, 21)
- the texture's skin: (149, 153, 26)

**Why they all look alike:** both goblins use the same Tripo paint, and its skin is a strong yellow-green. The old goblin looks just as yellow in Studio's own frames (`tools/film/old`, PC frame `(120, 127, 20)`). The olive look in the Blender sheets came from Blender's flat render.

**Not changed:** I did not recolour the texture. The rigged goblin is already within dE 10 of the old one in game. Matching the texture itself would mean making it brighter, the opposite of what was asked. If the goblins should be more olive, that is a repaint of the skin for both models. It is a taste call (target colour?), not a rig fault.

## Files

| file | what it shows |
|---|---|
| `phone_run_side.jpg`, `phone_run_34.jpg` | the bouncy run, 10 frames/s |
| `phone_hit_from_side.jpg` | the rock-back from the hero's side, then the fall |
| `phone_knockout_alone.jpg` | the fall, 14 frames/s |
| `clip_phone.mp4` | the whole run |
| `numbers_phone.txt` | the measurements |

Frame time: Studio in the background plays at 15 fps whatever is on screen (66.7 ms mean, the same as in round 1), so this run cannot show the rig's cost.
