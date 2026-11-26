# Goblins hitting the Oak Barricade (round 2, 2026-11-26)

These were filmed in a test-only local merge of the barricade branch (`claude/project-thread-0sosm7`); none of its code is committed here. 5 goblins were sent at a Level 1 barricade, at phone size.

- **Result:** they stop in rows and the front ones play the attack. Up to 3 bashed at once (`numbers.txt`).
- **Grade:** hitting 5/10. The swings read, but the five goblins crowd into one blob at the wall. A stone pillar of the ruins also hides part of the side shot.
- **What made it work (on our branch, `HeroService`):** `SetBashing(e, bashing[e] or e.bashing == true)`. The barricade's `e.bashing` now drives the attack, so the barricade branch needs no new line for that.
- **The one line the barricade branch needs (in the merge):** `if e.bashing and not e.rigged then` around its forward-chop lean in `EnemyService`. Without it the server also tips the whole rigged goblin model forward on top of MonsterAnim's swing.
