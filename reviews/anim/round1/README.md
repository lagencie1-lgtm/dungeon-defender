# Hero animation test, round 1 (2026-11-25)

A real run as the Swordmaster in Studio (Cursed Forest): sword combo (3 presses 0.56 s apart) from the side and from 3/4, ready stance, Whirlwind (3/4 and side), Leap, hurt (2 server hits, then real goblin hits on the path), a long idle, and a knock-out.
I filmed it at iPhone 13 landscape in the device simulator (graphics 1) and in the plain Studio window (750x635 viewport). The rig is `test/anim.project.json` and `test/anim/`.
The clips start 10 s after the marks' zero, so subtract 10 from each time in `clip_*.marks.txt`.

## Found and fixed

1. **The hero did not animate at all.** New Roblox places give characters the upgraded joints: `AnimationConstraint` instead of `Motor6D`.
   HeroAnim only looked for `Motor6D`, so it found no joints and returned every frame. You can see this in `before_fix_phone_combo.jpg` (the body stays still, only the slash effect shows) and in `numbers_before_fix_phone.txt` (the rest lines list no joints).
   HeroAnim now takes either kind: both have a `Transform`, and for an AnimationConstraint it reads C0/C1 from its two attachments.
2. **The feet floated, then sank, in crouches and lunges.** The leg bend assumed straight legs, but Roblox's idle already bends the knee about 30 degrees.
   - With the first fix, the feet floated 0.2 studs in the ready stance and up to 0.22 in the combo.
   - A straight-leg variant sank them 0.36 studs.
   - The bend is now solved on the leg as it is posed: thigh and shin lengths, the current hip and knee angles and the lunge angle. The ankle also counters the lunge.
   - Feet vs the ground, idle range -1.00 to -0.97 (the spawn pad's top is 1 stud above the floor the hero stands on):

   | | combo | stance | whirlwind |
   |---|---|---|---|
   | before | -1.11..-0.75 | -0.97..-0.77 | |
   | after | -1.03..-0.92 | -1.00..-0.95 | -1.00..-0.95 |

## Checked, fine

- **No drift (Transform piling up):** after every move each joint returns to its idle angle within 3-4 degrees (the `rest ...` lines), the same as idle's own sway. Large values right after Whirlwind 2 are the ready stance still easing out; they are back after the leap.
- **No body flip on the spin:** the torso's up vector never drops below 0.97 during Whirlwind.
- **Leap:** the torso leans to 0.44-0.54 (about 60 degrees) in the overhead hold, which is meant. The head stays at least 1.3 studs above the ground. In my framing the wall hides the landing, so the clip shows it badly.
- **Hurt:** the flinch reads (rock back, arms out, spring back) both for server hits and for real goblin hits.
- **Script errors:** none from HeroAnim, HeroMoves or HeroService in the autotest or any of the 5 filmed runs.

## Still broken (not fixed: I need to check the cause first)

- **Knock-out goes under the ground.** The knees buckle, then the body lies flat and sinks about 0.8 studs into the ground: head and torso at -0.75 to -0.86, only the sword sticking up (`pc_ko.jpg`, `phone_ko.jpg`).
  It looked the same before the fix, when HeroAnim did nothing, so it is probably Roblox letting the upgraded joints go limp on death (a ragdoll with non-colliding parts and the root anchored), not the `death` clip.
  The next step is to test setting the AnimationConstraints kinematic on Died, or lowering the clip's Drop.
- **Autotest controller check:** "Readable FAILED" (11 HUD texts under 10.6 px in a 750x635 viewport). This has nothing to do with the animation change.
- **Combo body twist:** the forehand and backhand turn the whole body 50-70 degrees in under 0.1 s. It reads as energetic at phone size but could snap. That is a taste call, tuned in `HeroMoves.luau`: Root/Waist `y`.
- **Whirlwind:** the smoke ring hides the hero for most of the turn on a phone.
