# Barricade fight on a phone: option C2 in the game (2026-11-26)

Lemp chose C2 (see `../barricade_options`). It is in PR #6, client only:
- **Climbing:** half of the goblins in the back rows climb onto the shoulders of the ones in front and swing from up there (`MonsterMoves.Pile.Climb`, `ClimbIn`, `ClimbTuck`; `MonsterAnim`).
- **The wall reacts:** every blow at a wall shakes it with the top boards flexing back, knocks 2-3 small chips off on about 1 blow in 3, and flashes the health bar. Numbers in `MonsterMoves.WallHit`; code in the new `src/client/WallFx.client.luau`. The wall is left alone while it is broken or being rebuilt.
- **The camera:** while a wall the hero can see is under attack, the run camera looks down 8 degrees more and springs back to the normal 32 degrees when the attack ends (`Config.RunCamera.WallTilt`, `TiltTime`, `WallRange`; `RunCamera.client.luau`). Only the change of the tilt is applied each frame, so the player's own camera turns stay theirs.

**Confirmed at phone size with the game's own follow camera** (throwaway local merge with the barricade branch 6283328, hero 28 studs from the wall, 8 goblins):
- goblin points above the wall: **46%** (target 35%+)
- pile height on screen: 56 px of 388 (14.5%)
- camera pitch: 40.0 while the wall is under attack, 32.0 again after it broke

**Files:** `c2_frame.jpg` (one phone frame), `c2.mp4` (3 s of the pile), `c2_wall_breaks.mp4` (the wall breaking and the camera going back), `c2_sheet.jpg`, `numbers.txt`.
