# Goblins pile up at the Oak Barricade, round 4 (2026-11-26)

Lemp: "they should all attack the wall so the wall breaks faster and they should pile up before the barricade and smash onto it - once the barricade is gone they should run down the trail as a blob".

Filmed at phone size in a throwaway local merge of `claude/project-thread-0sosm7` at 6283328, which has the pile and the broken/repair wall; none of its code is committed here. The camera sits where the hero's run camera does (12 studs behind, 9 up), held on the wall. The film runs: 8 goblins pile up and smash, the wall breaks (damage x12 for the test), the blob runs on over the stump, the wall is repaired (repair time set to 4 s for the test), 6 new goblins pile up and smash it again.

| shot | sheet | grade |
|---|---|---|
| pile-up, all smashing | `phone_pile.jpg` | 7 |
| the wall breaks, beat, burst into a running blob | `phone_breaks.jpg` | 8 |
| repair rising from the stump | `phone_rebuilt.jpg` | 7 |
| new arrivals pile up again | `phone_pile_again.jpg` | 7 |

**Measured:** all 8 of 8 smash at once (rows: 4 in front, 4 behind). The wall broke after 1.3 s of x12 damage. The repair worked, and 6 piled up again (4 in front, 2 behind). The barricade branch's server code ran without errors.

**Animation (PR #6, client only):**
- **The pile:** the round 3 sideways spread and cheering are gone. Everyone standing next to one that is hitting the wall swings on their own beat. Rows behind (`PileRow` > 0, from the server's `e.pileRow`) lean on the one in front, reach higher overhead, and about half of them hop up on the wind-up. Each blow surges the pile forward a little (`MonsterMoves.Pile`).
- **The break:** when the wall breaks, all of them stop hitting at once. They gather for 0.15 s (a crouch), then burst forward leaning in, each starting 0-0.1 s apart (`MonsterMoves.Burst`). The server keeps them as one blob.
- **The stump:** monsters crossing a broken wall hop over its stump with their knees tucked (`MonsterMoves.StepOver`). In this film the blob crosses the low stump in about half a second, so the hop is hard to see on the sheets.

**Open:** the hero stands between the camera and the pile and hides part of it.
