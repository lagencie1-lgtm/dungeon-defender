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

### What the player sees change in the shot (2026-11-24, research brief: "each level looks different and fights visibly differently")

Where a level adds a visible weapon, the shot comes from it. Damage per second stays exactly as it was: the damage of
one shot is split across the visible weapons (src/server/TowerService.luau `shoot`). Nothing is rebalanced.

| Tower | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| Ranger | one archer draws and looses an arrow | one archer, the same | both archers draw and loose, an arrow each, 0.12 s apart, half the damage each |
| Flame Cannon | the mortar kicks and lobs a fire shell | the bronze cannon, the same shot | the two barrels fire in turn, half a cooldown apart, half the damage each; each blast still sets goblins burning |
| Frost Crystal | a frost ring spreads from the tower and slows | the same ring, more slow | the same ring; the orb glows (no separate shot) |
| Storm Obelisk | lightning leaps from the rune | from the rod's tip | from the orb between the horns, then goblin to goblin |
| Ballista | one bolt | one heavier bolt | the two ballistae loose a bolt each, a quarter second apart, half the damage each |

Each level's muzzles come from the builders' MUZZLE lines (`LEVEL_LOOKS[...].Muzzles` for the two-weapon levels).

### Visible while art loads, and on low effects (2026-11-24)

- **Preload:** as the models load on the server, ArtService writes each tower look's mesh and texture ids to
  `ReplicatedStorage.TowerAssets`; `src/client/TowerStandIn.client.luau` fetches them all (ContentProvider:PreloadAsync)
  as a run starts loading.
- **Stand-in:** every placed tower carries a `StandIn` model (TowerService `setStandIn`): a body, a top and a weapon
  block in the tower's own colours, its footprint and its look's height. Each client shows it until that look's meshes
  and textures are fetched, then hides it (no pop: same footprint and height). Upgrades set a new one for the new look.
- **Measured in the film** (Studio on Lemp's PC; its asset cache is warm, a phone's first run will be slower):
  stand-in drawn 0.05-0.10 s after the tap, swapped for the real look 0.37-0.65 s after it (gates 0.3 s and 1 s).
- **Low effects:** a LocalScript may not set Roblox's graphics level ("lacking capability RobloxScript"), so the
  film's low-effects pictures are an approximation: shadows and every post effect (bloom, sun rays, colour grading,
  depth of field) turned off on that client. Materials and draw distance, which graphics level 1 also lowers, cannot be
  changed from a script.

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
## Painterly paint, shared with pets (Lemp 2026-11-23: "use the painterly workflow from the pets thread")
What makes the pets look painterly (read from scripts/pet_paint.py and art/blender/pet_project.py; we call them, we
never copy or edit them):
- **Views.** `pet_project.py views` renders the model's own plain bake straight from four sides (front, its left,
  back, its right) into one 2 x 2 sheet, orthographic, 512 px per view, white ground. Not 16 views and no top view.
- **Painter.** Codex image generation repaints that sheet with the target painting as the second picture: "soft
  painterly strokes, rich warm shading, small painted details, clean dark-brown outline", every view kept in place,
  size, pose and outline. `--noface`: the painter gets the model with eyes and mouth already filled with the skin
  round them (`no_face`, a diffusion inpaint of the `_keep.png` marks) and is told to paint none, so it never draws a
  second face. One painting job at a time.
- **Bad views.** `align` stretches each painted view's outline box onto the rendered one and measures the overlap;
  a view under 62 % is not projected (`skip=`), so paint never lands on the wrong parts.
- **Brush tone.** `--crisp N` (optional) median-filters the painter's small strokes into clean patches, doubles and
  sharpens the sheet. Without it the strokes stay as painted.
- **Seams between views.** Each texel takes its colour from the views that see it (depth test, facing > 0.3),
  weighted by facing^8, the front view x6: one side wins clearly (no ghost faces from blending two paintings). The
  painter's dark outline round each view is cut off (7 px rim refilled from inside) before projecting.
- **Gaps.** Texels no view paints well get `painter_tone`: the plain bake shifted by a small 3D colour table learnt
  from where the paint did land (a colour grade), so they match instead of showing flat patches.
- **The base is protected.** The plain bake is copied once to `<name>_base.png` and never overwritten; the painted
  result goes to the texture the game loads. Eyes and mouth (`_keep.png`) come back untouched from the base.
- **Measure.** `pet_match.py` "detail": mean edge strength (FIND_EDGES) inside the outline at 256 px, as a percent of
  the target picture's (Baby Dragon gen2 last: 71 %).

For the archer (several parts, one picture each): `scripts/archer_paint.py` packs Head, Body and both arms into one
temporary mesh with one atlas (`art/blender/archer_project.py pack`), runs the pets' views, painter (our own
humanoid wording of the no-face prompt), `align` and `project` on it unchanged, then cuts the atlas back into the
parts' own pictures. The bow and quiver are not sent to the painter and keep their paint. The face keeps the front
painting only: eyes, brows and mouth are the `_keep.png` marks.

**Towers: tried and stopped (coordinator 2026-11-24, round C).** The pets' pass lost to the towers' current paint on
every level tried, on colour dE against the level's painting and on the detail measure:

| Level | colour dE before -> after | detail ratio before -> after |
|---|---|---|
| Ranger 1 | 9.6 -> 15.9 | 1.07 -> 0.78 |
| Ranger 2 | 10.5 -> 13.1 | 1.05 -> 0.94 |
| Ranger 3 | 9.1 -> 12.8 | 0.98 -> 0.80 |
| Flame Cannon 1 | 14.7 -> 17.3 | 1.27 -> 0.88 |
| Flame Cannon 2 | 15.6 -> 16.9 | 1.23 -> 0.88 |

Why: four views see too little of a tower straight on. Only 20 to 37 % of the surface got direct paint; the rest got
the painter's tone (a colour grade of the old paint), which flattens it. Twelve views (8 round, 4 from above,
`art/blender/project12.py`, `scripts/tower_painterly12.py`, checked with the renders themselves as the painting) still
see only 13 % of Flame Cannon level 2's atlas within the facing needed: much of a tower's surface is under roofs,
between parts and inside. Towers keep their paint; the pass stays a pet and archer tool. Results:
`reviews/towers/painterly/`.
