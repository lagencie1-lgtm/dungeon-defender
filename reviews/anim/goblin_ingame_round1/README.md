# Rigged goblin in game, round 1 (2026-11-25)

**Run:** a real run in Cursed Forest with wave 1, filmed at iPhone 13 landscape (device simulator, graphics 1). The rig is `test/anim-goblin.project.json`. The clip starts 12 s after the marks' zero.

**Order of shots:**

1. the goblin walking, filmed from 3/4
2. the same goblin from the side
3. the hero steps into its way, so it bashes
4. two sword-sized hits, sent by the test as a server cue rather than the hero's own swing, so they land every time
5. then hits until it dies and falls

## Upload

Lemp approved the upload ("upload the rigged goblin"). Both assets are private, and nothing was published.

| what | asset id | where in `src/shared/Art.luau` |
|---|---|---|
| `art/models/rigged/goblin_rigged.fbx` (Model) | 130565995983817 | `Art.Models.enemy_goblin_rigged` |
| its paint, 1024 (Decal) | 90498830454310 | `Art.Textures.paint_enemy_goblin_rigged` |

- **Upload method:** the project's own Open Cloud calls from `scripts/upload_models.py` and `scripts/upload_art.py`. The API key was copied into the worktree only for the upload and deleted right after.
- **The import keeps the skeleton:** one MeshPart called Body with all 18 Bones under it (Root → Hips → …). ArtService keeps them because it moves the MeshPart, bones and all.
- **The paint loads:** it arrives as `rbxassetid://91768115255613`.

## Wiring

- **The rigged model takes over once loaded:** `EnemyService.goblinMesh` picks `<model>_rigged` when it has loaded, else the old one. So the Goblin uses `enemy_goblin_rigged`, and `enemy_goblin` stays as the fallback.
- **Rigged looks are marked:** a Look with bones gets the `Rigged` attribute. The server then leaves out the whole-model waddle, lean and hop, and the topple on death.
- **The rig faces the right way:** `MonsterAnim` reads the rig's facing from its feet. It matched the walking direction exactly: "rig forward vs walking direction: 0 degrees".

## Numbers (`numbers_phone.txt`)

- **Foot slide:** the planted foot slid 0.03-0.08 studs per frame while the body moved about 0.6 studs per frame (9 studs/s at 15 fps). That is 0.015-0.047 studs per step, against a step of about 1.6 studs. Only frames well inside a step count.
  - Before the planted leg's angle was solved from where the foot must stay, it was 0.46-0.58 studs per step with a sine swing.
- **Cadence:** the goblin takes about 5.5 steps a second. It is 7.9 studs tall with legs about 1.5 studs long, and it walks at 9 studs/s. Feet that do not slide need this cadence at the current 32-degree swing: it reads as a scurry. Longer, slower steps would need a running gait with both feet off the ground, which is a taste call.
- **Ankle bone above the ground:** standing 0.27. While walking, the lowest ankle stays between 0.10 and 0.45 (the terrain is bumpy). While bashing it dips to -0.02..-0.04 at the lunge.
- **Stretch at the real angles:** from `reviews/anim/goblin_rig_round2` (Blender).

  | pose | edges over 1.6x (visible) |
  |---|---|
  | arms up 60 | 21 |
  | swing 100 | 25 |
  | knees 45 | 0 |
  | head turn 25 | 11 |

  These are about half the counts at the stress angles. All of them sit at the jaw, collar and armpits, and none shows on the phone sheets.
- **Frame time:** Studio in the background caps play tests at 15 fps (66.7 ms), the same with no monsters as with 8 rigged goblins on screen (mean 66.7 ms, worst 69.8 ms). This Studio run cannot measure the cost of the rig. A phone or the Studio window in front is needed for that.
- **Bashing:** on as soon as the goblin touched the hero.
- **Hits and the fall:** HitAt was written on each hit. The goblin fell and was removed 0.7 s after Dead.

## Sheets (`phone_*.jpg`)

- **`phone_walk_34.jpg`, `phone_walk_side.jpg`:** legs swing and the knees lift, arms counter-swing. The body stays level, with no whole-model waddle.
- **`phone_bash.jpg`:** the attack loop at the hero. Several goblins are in the shot, each on its own beat.
- **`phone_hit.jpg`:** the rock-back from two hits.
- **`phone_fall.jpg`:** the fall. Other goblins crowd this shot, so the fall itself is hard to read here. The numbers confirm the Dead attribute, the 0.6 s clip and the removal. A cleaner shot needs a lone goblin.

## Open

- **Barricade:** the barricade branch's logic was not merged for this test. Bashing came from hero contact. That branch should call `EnemyService.SetBashing(e, true/false)` where it sets `e.bashing`.
- **Hit direction:** HitAt carries no direction. The client rocks the goblin away from the nearest hero within 30 studs, otherwise backwards. Tower hits from far away therefore rock it backwards.
- **Stepping:** the 5.5 steps a second scurry is a taste call. Options are a bigger swing (longer steps, slower cadence, a little foot slide) or a running gait.
