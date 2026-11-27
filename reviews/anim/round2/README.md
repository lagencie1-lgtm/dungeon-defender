# Knock-out fix, round 2 (2026-11-25)

The rig is `test/anim-ko.project.json`. It knocks the Swordmaster out three times in a real run and films it at iPhone 13 landscape:

1. beside the stone wall and grass bank near the hero spawn
2. the same spot again
3. the middle of the goblins' path (open, flat ground)

The clip starts 8 s after the marks' zero.

## What was wrong

- **Joints went limp on death.** On death the upgraded joints (AnimationConstraint) went limp. For a moment, before the server's anchor arrived, the body tipped over as one piece and sank about 0.8 studs into the ground.
- **The Root joint stopped working.** Once the hero was dead, turning the Root joint no longer tipped the body. The root part turned, but the torso stayed upright or lost its link to it.

## Fix

- **Joints stay driven.** On Died, the server (HeroService) and every client (HeroAnim) set every AnimationConstraint `IsKinematic = true` and `Enabled = true`. The client also anchors the root part at once instead of waiting for the server.
- **The fall tips the root part.** The fall now tips the anchored root part itself, on each computer and for looks only. It turns about a line under the hips, `HeroMoves.FallPivot` (0.6 studs at scale 1) above the ground, so the back rests on the ground. The death clip has a new `Fall` value (90 degrees, settling to 86). The Root joint now only does the knee buckle and the wobble.
- **The ground behind limits the tip.** Before falling, the game samples the ground 1-5 studs behind the hero. If it rises (a bank or a wall), the body only tips as far as the slope allows, between 50% and 115% of the fall. On flat ground it lies fully on its back.

## Numbers (`numbers_ko_phone.txt`, lowest point of each body part over the 3 s after death)

The terrain is bumpy: standing, the lowest foot already measures -0.04 to -0.23 against the ray under it. Read every number against the "standing lowest before" value of its take.

| take | lies | torso (lowest) | head | arms | legs/feet |
|---|---|---|---|---|---|
| 3, flat path (standing -0.23) | on its back, torso up 0.06, chest up 0.98 | -0.04 / -0.05 | -0.03 | L -0.39, R -0.03..+0.55 | -0.01..-0.33 |
| 1, beside the bank (standing -0.04) | reclined 47 degrees against the slope | +0.57 / +0.68 | +1.46 | +0.5..+1.6 | -0.03..-0.18 |
| 2, same spot (standing -0.05) | the same as take 1 | +0.58 / +0.69 | +1.50 | the same | the same |

- **Flat ground:** the body lies on its back with the torso and head at -0.05..-0.03 raw. That is +0.18..+0.20 above the standing baseline, inside the -0.05..+0.25 band.
- **Left arm:** lowest at -0.39 raw (-0.16 against the baseline). The ground on that side is lower too.
- **Before the fix:** the head was at -0.75 to -1.05 and the torso at -0.24 to -0.33.
- **Beside the bank:** nothing goes into the ground any more. The sword tip measures -1.16 because it hangs over the bank's edge.
  The hero reclines against the slope instead of lying flat, and on the phone sheet that pose can read as leaning on air. The fix there is to sample the ground under the head too, or to slide the body forward off the bank: a taste call.

## Files

- `phone_ko_flat_ground.jpg`: take 3, 5 frames a second from the press.
- `phone_ko_beside_bank.jpg`: take 1, 5 frames a second from the press.
- `clip_ko_phone.mp4`: the whole run.
