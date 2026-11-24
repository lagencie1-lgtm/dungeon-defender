# Battle maps: layout review (started 2026-11-24)

Lemp, 2026-11-23: "Improve the map layouts like make some obstacle courses (look at dungeon defenders how their
maps are built with much more obstacles and environment)".

## What Dungeon Defenders maps do
Read from eight map plans of the first game (The Deeper Well, Foundries and Forges, Magus Quarters, Alchemical
Laboratory, The Ramparts, Glitterhelm Caverns, The Throne Room, Endless Spires) and what the Awakened remakes keep.
Other games' pictures stay out of this repo.

1. The field is never a rectangle. Walls give every map its own outline.
2. Four to eight enemy doors round the edge, each with a short lane; the lanes meet at the crystal.
3. Two to four floor levels joined by stairs. The crystal sits at a junction, often on the lowest or highest level.
4. Big things you cannot cross split the floor: lava pits, pillars, long walls.
5. Good building spots are few and obvious: the head of a stair, the mouth of a hall, a bridge.
6. One landmark per map that you can name (the forge's lava, the throne, the spire).

## Scores (1-10, harsh; 10 = a shipped Dungeon Defenders map, 5 = an average Roblox tower defense map)

| | Before (my read) | Before (outside judge) | After cycle 2 | After cycle 3 | After cycle 4 (placement redone) |
|---|---|---|---|---|---|
| Cursed Forest | 3 | 3, then 2 | 4 | 5 | 3 |
| Magma Fortress | 3 | 4, then 3 | 3 | not judged | 5 |
| Crystal Caves | 3 | 2 | 4 | not judged | 4 |

The judge contradicts itself between runs (the same old Forest got 3 one night and 2 the next morning), so the
numbers are a direction, not a measure. Its note on the cycle 4 Forest: "lane edges remain bare", "wide-open
sides". That is the price of a clean floor where a lane has no bank, wall or water beside it; the next step
there is a second walled bank and footpaths that tie the set pieces to the road (not more loose objects).

The outside judge is Gemini, blind (two unlabelled sets, order shuffled), on phone-size stills:
`python scripts/map_bench.py before cycle2`, full answers in `bench-before-vs-cycle2.md`,
`bench-before-vs-cycle3.md` and `bench-before-vs-cycle4.md`. Only the small flash
model answered that night; it squeezes scores and misreads things (it took a frozen golem for a statue and a
defender for a ramp), so its numbers order the work and its claims were checked against the stills. What held up:
- the raised ground did not read as height at phone size (grass on grass, 4 studs) -> cycle 3: stone retaining
  walls on the edges of raised ground, stairs;
- Magma is dark from above and its lava did not read as lava -> cycle 3: the lava river glows;
- every map is still ONE lane from one gate -> open question for Lemp (needs wave code, another thread's area).

## What changed
- Cycle 1, the ground: each map is designed data (`src/server/MapLayouts.luau`): raised ground the lane climbs,
  a river / lava river / glowing canals that nothing can be built in, rock masses that fill the corners no lane
  uses, a rise the portal stands on. Found on the way: every pond and lava pool of the old maps was a rock bump
  with no water in it (thin fills on a 4-stud voxel grid; measured in `scripts/terrain_lab.py`).
- Cycle 2, the kit: 18 painted Blender models (`art/blender/map_kit.py`): ruined wall, low battlement, gate arch,
  broken pillar, bridge, and one set piece per map (standing stones, fire brazier, crystal cart), in three paints.
  Placed by hand with a reason each. What is solid is an invisible box; tall pieces fade while they hide the hero.
- Cycle 3, height you can see: retaining walls and stairs round every raised floor (6 more models: `face`,
  `stairs`), the glowing lava river.

- Cycle 4, built instead of scattered (after Lemp: "some here look like you just threw in random objects
  everywhere"): see `placement-rules.md`. Every piece belongs to a named set (`MapLayouts.Sets`); loose rocks,
  single trees, formula pillars and braziers, free-standing gates and wall fragments are gone. The retaining
  walls carry a flagstone rim that covers the terrain's bevel, with parapets on top where the layout asks;
  stairs are flights that run along a wall (the old ones came down onto the road).

- Cycle 5 (Forest only): the two lane sides that had no edge at all get a wood each, 20 studs back from the road
  (the building ground beside the lane stays clear), and two footpaths tie the chapel's well and the standing
  stones to the road. A footpath is terrain paint: it must be written 4 wide and 0.1 proud of the ground to show
  (measured: level with the ground it does not show at all, 2 wide it does not show either).

- Cycle 6, after the research briefs and Lemp's map audit (`dungeon-defenders-layout-audit.md`):
  - Real edges. Each map has an outline (`src/shared/MapOutline.luau`) about 24 studs behind its lanes; outside it
    the ground rises in steps with rock faces and grass / ash / cave-floor treads, woods and crystals massed on it,
    the rivers and the lava coming out of gorges: the forest is a valley, the fortress a crater, the caves have
    cave walls (before: a rectangle of lawn inside a ring of trees). Heroes stop 5 studs short of it, so the camera
    behind a hero who looks back into the field stays over the rise (the tour checks the line); nothing within 4
    studs of it can be built, on the server and in the build ghost alike.
  - Lemp's Forest first pass. Keep lookout: the keep tower (`map_kit.py tower`: a broken keep with an old tree grown
    up through its broken corner, roots down its walls) at the hill's north end; heroes arrive facing north-east,
    so the first view has the tower on the left and the first ford on the right; the tutorial's first build spot is
    a round of flagstones (`pad`) between the hero and the tower, where a Ranger covers the road on all four sides
    of the hill. Chapel yard: a broad yard of trodden earth before the door with the well and a build spot, and the
    hero's shortcut, a footpath from the keep's stairs across the road down the chapel's side into the yard (about
    70 studs against the goblins' 130). Shrine bridge: a build spot at the near landing of the last bridge, the wood
    on its far side cleared for the fight near the portal.
  - Building on a phone: a tap (or a controller's ghost) a little off a free spot takes the nearest free one within
    4.5 studs; choosing a card near the map's first spot shows the ghost there; a refused build names what is in
    the way ("The well is in the way", "A wall is in the way", "Too close to the water"...).
  - Not done (by the briefs): no new lanes before there is a boss mechanic.

## Checks (they run in `python scripts/map_tour.py <take>`, and the ground test)
- the first build spot (`MapOutline.Start`) takes a Ranger, lies within 16 studs of the spawn, and 3 of the 8
  spots 1.5 studs round it are free too; the lane and the spawn keep 10 studs from the outline, nothing by or
  beyond it takes a defender, and the rise stays under the camera's line;
- every raised floor is flat at its height and takes a defender; every channel holds liquid; the lane's ground
  never steps more than 1.2 studs per 2 walked; nothing built stands alone (`MapLayouts.Loose`: 0 on all maps);
- `test/ground`: PASS, 0 of 4653 checks outside the limits: no defender and no monster sinks or floats on any
  map. The first try had 3 misses: the three biggest monsters stood 0.11-0.14 studs low where the ramp to the
  Forest's portal bends (enemies walk a height profile sampled every 2 studs). The lane ramps are now 30 studs
  long instead of 20 (`MapLayouts.LaneProfile`, reach 11), which fixed it.
- the full game test (`bash scripts/autotest.sh`) wins all three maps with the portal at 100. Its own placing
  rule (exactly 11 studs from the lane) now finds only 5 spots on the Forest (10 on the other two maps): walls stand there.
- room to build. Share of the whole field that takes a defender: Forest 67% -> 32%, Magma 47% -> 22%,
  Caves 59% -> 29% (most of the loss is the corners no lane reaches). Share of the ring beside the lane
  (8.5 to 18 studs from its middle): Forest 84% -> 40% (cycle 3) -> 47% (cycle 4), Magma 73% -> 39% -> 49%,
  Caves 91% -> 45% -> 41%, which is room for about 104 / 163 / 164 defenders where a run holds 15 at most.
  Rule in the tour: at least a third of the ring, and room for 45.

## Pictures
`img/compare-<Map>.jpg` (before | now, phone size), `img/compare-plans-now.jpg` (the three plans from above),
`img/built-<Map>.jpg` and `img/built-phone-<Map>.jpg` (cycle 3 | cycle 4: scattered against built),
`img/<take>-<Map>-sheet.jpg` (all ten views of a take), `img/kit-<theme>.jpg` (the kit in Blender).

## Open
- Magma (the audit): a furnace court with a visible lava feed, lighter paving and bridge landings, a choice between
  holding the front bridge and the back one. Crystal: a loading platform with a timber hoist, paler usable floor,
  a high perch against a low melee route. A second enemy approach (Magma first) waits for a boss mechanic.
- The fast enemy that teaches the Forest's shortcut is the features thread's (first-wave rescue).
- Defenders shoot through walls (no line of sight in the game).
- The kit's stone is soft up close (512 px paint on a 14-stud wall).
