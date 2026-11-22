# Tower look pipeline (spec, vetoable)

Lemp 2026-11-22: "upgrading should also upgrade the asset look ... make a pipeline with codex to get amazing upgrade
tower pictures and use blender or other tools to build until you come extremely close to the picture".

## What changes per level

Every defender has 3 levels (Config.Towers.*.Levels). Each level gets its own look; the silhouette grows first, so a
kid sees the level from across the lane on a phone. Glow only at the top level.

| Tower | Level 1 | Level 2 | Level 3 (max) | Colours |
|---|---|---|---|---|
| Ranger | a small wooden watch post on a stone footing, one archer | a round stone tower with a timber lookout and a shingled cone roof (today's model) | taller: a second stone storey, brass-banded, green banners, two archers, a glowing green gem on the finial | wood brown, warm stone, forest green |
| Flame Cannon | a squat iron mortar on a stone ring | a bigger bronze cannon with a coal hopper | twin barrels on a turning brass turret, glowing vents | iron, bronze, fire orange |
| Frost Crystal | one ice shard on a frosted stone | a crystal cluster with a silver ring | a tall crown of crystals around a floating core that glows | pale stone, ice blue, silver |
| Storm Obelisk | a short rune stone | a carved obelisk with a copper rod | a tall obelisk with a floating storm orb and copper coils | slate, copper, storm violet |
| Ballista | a light wooden bow on a stand | a heavier ballista with iron arms | a double ballista on a stone bastion with a crank and banners | oak, iron, crimson |

Rules: same footprint at every level (it stands on the same plinth and keeps its spot), height grows about 15% per
level, the turning head and the muzzle stay separate nodes on the game's pivots, feet on the ground (test/ground).

## The pipeline, per tower

1. **Target pictures (Codex).** One image with the three levels side by side, same three-quarter view from slightly
   above, white background, the game's painted style (art/STYLE.md), so the family reads as one. Cut into three files
   `art/ref3d/tower_<kind>_l1..l3.png`. Lemp makes the taste call on the sheet before anything is built.
2. **Build in Blender** (`art/blender/towers_hand.py`, kinds `<kind>1`, `<kind>2`, `<kind>3`): models as code with the
   painted textures, the game's pivots and muzzle points as data.
3. **Measured match** (`scripts/match_score.py`): render the model at the picture's angle and score
   - silhouette overlap (IoU) of the two outlines, both scaled to the same height,
   - width profile row by row,
   - colour difference (CIE Lab) where both are solid.
   Iterate until IoU >= 85%; report the numbers with a picture-vs-model sheet.
4. **In game:** each level has its own model (`tower_<kind>`, `_l1`, `_l3`); upgrading swaps the look with a short
   settle (the new model springs from 90% to 100% size in about 0.3 s) and a small dust ring; no ceremony. The upgrade
   panel shows the next level's picture.
5. **Judged** on the phone view in a real run, film rig plus Gemini, and by Lemp.

Pilot: the Ranger, all three levels, end to end, before the other four.

## Tools that could raise quality (none installed yet; Lemp decides)

| Tool | What it buys | Cost |
|---|---|---|
| Tripo image-to-3D from the level pictures | a closer first shape for complex tiers (Lemp generates, I clean as with the hub) | Lemp's Tripo credits; texture is baked in (lighting stains), needs the same clean-up as the hub models |
| Roblox SurfaceAppearance (PBR maps) | real roughness and normal detail on stone and metal | free; one more texture set per model (memory on phones), must be judged on a phone |
| Blender add-on: none needed | the sculpt kit already covers bevel, lathe, membranes | - |
| An image upscaler for painted textures | sharper 1024 maps from 512 bakes | free tools exist (e.g. Real-ESRGAN); needs Lemp's OK to install |
