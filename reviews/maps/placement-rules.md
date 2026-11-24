# How obstacles are placed (rules from other games' maps)

Lemp, 2026-11-24, on the cycle 3 maps: "some here look like you just threw in random objects everywhere".
He was right. Cycle 1-3 was planned from Dungeon Defenders' map PLANS only (top-down minimaps), and the pieces were
placed by formula ("a pillar on the outside of every turn", "a brazier on every turn", rocks and stumps on spare
ground, single trees dotted over the field, gates standing free).

Then studied: 86 store screenshots (not in this repo: other games' pictures) of Dungeon Defenders, Dungeon
Defenders II, Dungeon Defenders: Awakened, Orcs Must Die! 3, Kingdom Rush Vengeance, Bloons TD 6, Defense Grid 2,
Element TD 2, Sanctum 2. What their maps have in common:

## The rules

1. **The floor is clean.** Where you walk, fight and build there is nothing. In Orcs Must Die and in every
   Dungeon Defenders hall the floor is bare paving; in Kingdom Rush and Bloons the open ground is plain grass
   with tiny flowers. Decoration is never an object standing in the middle of open floor.
2. **Edges do the work.** What stops you is a continuous line: a wall, a balustrade, a bank, water. The Awakened
   garden map bounds every walkway with one unbroken low stone wall. You never wonder where you can go.
3. **One architecture, and its pieces connect.** A gate stands IN a wall. A wall runs from something to something
   (tower to gate, bank to bank). Stairs lead to a floor. A bridge joins two banks. Nothing built stands alone.
4. **Few big set pieces, each one story.** Three to five per map, in the pockets between the lanes: the barn with
   its hay and field (Kingdom Rush), the tent camp (Dungeon Defenders II), the furnace (Awakened). Small props
   exist only as satellites of a big thing: big, medium, small together.
5. **Soft things are massed.** Trees, bushes, crystals stand in clumps and bands, at the border or behind a set
   piece, never one by one across the field.
6. **Repeats are a rhythm on a line, never a formula on the plan.** Torches along one wall, lanterns along the
   lane: yes. The same pillar on every turn of the path: no.
7. **One landmark you can name**, bigger than everything else, where the eye should go (the keep, the furnace).

## What broke them on our cycle 3 maps

| Map | Thrown in (removed or regrouped in cycle 4) |
|---|---|
| Cursed Forest | 2 gate arches standing free; 4 "milestone" pillars on the turns; one wall fragment on the green with a lone pillar; one wall fragment on a bank; a lone trilithon, well, watchtower and ruin; 12 rocks, stumps, bushes and mushroom patches on open ground; 17 single trees dotted over the field; 8 random boulders; barrels and crates along the lane |
| Magma Fortress | 8 braziers, one on every turn; 4 curtain-wall fragments joined to nothing; 4 lone pillars; a gate joined to a wall on one side only; 12 random boulders |
| Crystal Caves | 3 carts on rails to nowhere; 4 wall fragments; a gate standing free at the rift; 14 crystal clusters and 9 rock spires dotted over the floor |

## What each map is now (cycle 4)

`src/server/MapLayouts.luau`, `Sets`: every built piece belongs to a named set with its reason.

| Map | Sets |
|---|---|
| Cursed Forest | The keep (the hill you start on: stone-rimmed, its broken tower at one end, parapet and stairs at the other) · The Hollow Gate (a gate IN the canyon wall: its piers end the two banks' walls) · The chapel (three walls, the door's two columns, the well before the door, trees behind) · The standing stones (three trilithons round a mushroom ring, with their trees) · The shrine (the portal's walled platform: gate in its west wall, parapets, two columns) · six woods of three or four trees, two of them set 20 studs back along the lane sides that had no edge · two footpaths from the chapel's well and from the stones to the road |
| Magma Fortress | Four walled courts with a parapet on the lava river's side · The south gate (between the heart bastion's wall and a curtain wall that runs to the rocks) · The keep gate (the portal keep's whole west side, a fire either side) · The demon gate's fires |
| Crystal Caves | Two walled terraces with a low wall across each end · The ledge gate and its colonnade of four · The loading dock (three carts on ONE track along a wall, the crystals they were loading) · crystals in clumps of big, middle, small where the glowing water rises and where it pools |

## The check

`MapLayouts.Loose(layout)` lists every piece that stands alone: nothing of its own set within 22 studs, not
touching a plateau, not at a bridge. `python scripts/map_tour.py <take>` prints it per map and fails on any.
It reads 0 on all three maps. Loose boulders are only generated in the 16-stud band at the field's edge; the
forest's random soil patches, ponds, single trees, barrels and crates are gone. So is the "trail marker" an older
version stood on every map's open floor (five plain blocks, `MapProps`): the phone test and the full game test
that looked for it now check that the designed layout is on the ground instead, and the game test also fails on
any loose piece.

## Two things about walls and stairs (measured, `scripts/terrain_lab.py`)

- Raised ground cannot stand upright. A floor raised 4 studs is 2 high AT its edge and only reaches 4 studs
  4 studs behind it (grass, ash); the caves' floor is full height at the edge and slopes 4 studs outside it.
  A wall on the edge line therefore looked like a loose low wall with a dip behind it. Now each retaining wall
  carries a rim of flagstones 5 studs deep that lies over the bevel: the floor ends in stone.
- A flight of stairs standing out from a wall needs 6.5 studs, and the walls are 9 studs from the lane's middle:
  the old stairs ended on the road. Stairs are now flights that run along the wall's face, 2.8 studs deep.
