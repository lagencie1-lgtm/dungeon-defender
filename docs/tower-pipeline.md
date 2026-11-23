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

## The pipeline, per tower (Blender from code, no Tripo; Lemp 2026-11-23)

Lemp 2026-11-23: "you make a better workflow to make something amazing ... without the need of Tripo". Hub buildings
stay the Tripo models they are; every tower is built in Blender from code.

1. **Target pictures (Codex).** One image with the three levels side by side, same three-quarter view from slightly
   above, white background, the game's painted style (art/STYLE.md). Cut into `art/ref3d/tower_<kind>_l1..l3.png`
   (`art/make_tower_sheets.py`). Lemp makes the taste call on the sheet before anything is built.
2. **Part list from the picture.** Every part the picture shows, with its size measured off the picture (studs, the
   picture's height = the level's height): written as the size table `DEFAULTS` at the top of the builder
   (`art/blender/tower_<kind>_detail.py`) and checked by eye against the picture part by part.
3. **Real detail in the model** (`art/blender/tower_kit.py`): separate cut stones in offset rows on a tapering wall, a
   bell roof of overlapping shingles in tiers, lattice balconies with corbels and riveted brass plates, arched doors
   with voussoirs, banners with sag and emblems, ivy vines with heart leaves, swags, brass bands, ribs, crowns, the
   archer as built pieces. So light and occlusion already read like the picture before paint.
4. **Shape loop** (`scripts/tower_fit.py <kind> <level>`): builds the outline only, renders it at the picture's angle
   and tries every size a few percent bigger and smaller, keeping what overlaps the picture better (with rules such as
   "a wall never widens toward the top"), with smaller steps each round. Results: `art/blender/params/*.json`.
5. **Paint from our own views** (`scripts/tower_paint.py model.fbx picture.png`): the model is baked with the kit's
   painted textures and occlusion, rendered from four sides (`art/blender/tower_project.py views`: the picture's own
   angle plus three sides 90 degrees apart), Codex repaints that sheet in the look of the picture keeping every outline,
   and the paint is projected back onto the model (each texel from the view that sees it best). A separately painted
   picture never lines up with a model; a repaint of the model's own render does. The plain bake stays as
   `<model>_base.png`.
6. **Measured match, every round logged** (`scripts/tower_round.py <kind> <level> <round> model.fbx "what changed"`):
   `reviews/towers/<kind>_l<level>/round_XX.png` (picture | model | outline diff, four sides, the numbers),
   `round_XX_flicker.gif` (picture and model flipping in one frame) and `rounds.md`.
   Gates (`scripts/match_score.py`): outline IoU >= 90%; region colour (mean CIE Lab per cell of a 6 x 12 grid) <= 10,
   calibrated on the picture itself (`scripts/match_calibrate.py`: the picture 6% lighter or darker and softened scores
   3-6); detail (edge density inside the outline) 0.85-1.3 of the picture's; every part of the part list present; a
   blind Gemini comparison of 8 or more. At least 8 rounds per level.
7. **In game:** each level has its own model (`tower_<kind>_l1..l3`, `LEVEL_LOOKS` in TowerService with height and
   muzzle); upgrading swaps the look with a short spring settle and a small dust ring. The upgrade panel shows the
   next level's picture. Triangles about 8-12k per level (one Body MeshPart plus glowing c_ parts).
8. **Judged** on the phone view in a real run (film rig, Gemini) and by Lemp.

Pilot: the Ranger, all three levels, end to end, before the other four.

## Tools

Everything above runs on what is on this PC: Blender 5.2 (bevel, lathe, bmesh, Cycles bake), Python with Pillow and
numpy, Codex image generation (Lemp's ChatGPT login), Gemini for blind judging (free key). Nothing to install.

| Tool | What it would add | Cost |
|---|---|---|
| Roblox SurfaceAppearance (PBR maps) | real roughness and normal detail on stone and metal | free; one more texture set per model (memory on phones), must be judged on a phone |
| An image upscaler (e.g. Real-ESRGAN) | sharper 2048 paint from the 1024 painted sheets | free; needs Lemp's OK to install |
| Tripo image-to-3D | not used for towers any more (Lemp 2026-11-23) | - |