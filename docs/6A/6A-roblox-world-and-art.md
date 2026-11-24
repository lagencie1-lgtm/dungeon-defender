# 6A for Roblox: worlds, geometry, objects and animation

What it takes to build Roblox maps, 3D objects, characters and motion at the "6A" bar, two notches past AAA. Every
rule here comes from shipped or playtested Roblox work: arena shooters, simulators, a wave-defence game with island
maps, a brawler and a racer, built by AI agents for an owner who judged everything by playing on a phone. Facts
marked **[M]** were measured in Studio between September and November 2026; unmarked numbers were tuned by feel and
approved in playtests. Engine behaviour changes, so recheck the [M] facts on your Studio version.

Units: 1 stud ≈ 0.28 m. The default avatar is about 5.5 studs tall with eyes at about 4.75. It walks 16 studs/s.

---

## 0. The bar on Roblox

The judge is a 9-to-13-year-old on a cheap phone, in the first minutes. 6A means 9/10 or better on each of these:

- **Readable at phone size.** You know where you are, where you can go and what matters, without reading.
- **Honest.** What looks solid is solid, what looks open is open, and what looks walkable is walkable.
- **Signature.** A landmark and a look that belong to this game only. Never generic or mirrored.
- **Tactile.** Bodies and objects push, grip, lean and squash; nothing floats, slides or stands still while things move for it.
- **Clean.** Zero z-fighting, popping, clipping, stuck spots, invisible walls or late-loading holes.
- **Light.** The frame rate holds on the weakest phone; joins are small; nothing hitches when it appears.

---

## I. Principles

1. **A person leads the concept; tools check it.** A map drawn by an optimizer to hit sightline numbers was "absolute
   ai slop ... cluttered for no reason". Start from a sketch, a reference or a few words (offer 2-3 pictured options).
   Simulators and checkers verify; they never design.
2. **Every piece has a reason, and the place has a landmark** you can name the moment you spawn. Colour comes from
   contents (goods, boats, signs, lamps), not from painting walls.
3. **Nothing lies.** No painted doors, windows or blind arches. A dark pane on a wall reads as an enemy watching. An
   opening is real or it is not drawn. Anything that could hide a body or stop a bullet has real collision.
4. **Barriers go as invisible collision only.** "Remove barriers" never means deleting visible geometry. Everything
   that looks walkable becomes walkable.
5. **Flow over realism.** Not every building needs a second floor and a window. One signature high place per half
   is enough. Rooms are shaped for movement and fights, not for architecture.
6. **No twins dressed alike.** Mirrored halves with identical dressing were named by blind reviewers unprompted, and
   players can't call out a position in them. Keep symmetry only where fairness needs it, and vary the dressing,
   colours and contents.
7. **Fit the reference to the game; don't copy it.** Trees copied literally from reference pictures failed: "focused
   too much on replicating ... instead of understanding what I want". When the ask is "1:1", match layout, scale and
   camera first (read the reference frame by frame), then the finish, then simplify to the game's clean look.
8. **Bright, bold and readable beats dark and "premium".** A relief-material pass got "I like the old look way more".
   Add information (signs, lamps, furnished rooms, ground paint) instead of replacing a base look that reads well.
   Photoreal is welcome when it stays bright and calm; it is never an excuse for clutter or darkness.
9. **Sun beats night; gameplay beats mood.** "Why so dark." Night was cut from 30% to 10% of the day. A low sun glaring
   down the main lanes was rejected; carry the time of day with colour (warm lit faces, violet shade, gold haze).
10. **Rooms are calm, outsides may be vivid.** Saturated brick under warm lamps was "harsh ... too vibrant".
11. **Big and obvious beats subtle.** A paid item shrunk to a half-stud sliver was "bought twice, never seen".
    Muscle stages were "not big enough". Size worn items against the whole body. Then check they don't clip the
    floor ("a bit too big haha and gets cut by the floor").
12. **The player keeps their own avatar.** Show progress as scale, aura or muscle carved onto the player's own parts,
    clothes kept, head in proportion. A mascot body replacing the avatar was rejected ("a Roblox character game").
13. **Visible parts are rigid and mechanically true.** A sight that stretched while aiming, a barrel stretched to
    reach a muzzle instead of attaching a suppressor: both rejected. Optical tricks go on separate hidden pieces.
14. **Effects with restraint.** Flashes every 1.8-3.4 s, half the first instinct's size, never near the gun, hands or
    crosshair. A skin carries no light of its own (a glow light outshone the sun and lit the character from below).
15. **Judge in the game's light, in a real run, from uploaded assets.** Gold judged on a store stage read brown in
    the game's sun. Edit mode and Blender previews lie (section VII).

---

## II. Maps and level design

**Clearances** [M, then enforced by tests]
- At least 8 studs over every walked place; 7 reads as "hitting your head".
- Door lintel 8-9. Rooms 12-14 clear. Cellars 10, beams at 9. A storey is 13.
- Doors at least 4 studs wide, with level floor 8 studs deep on both sides, and always wall above (never a slot to the sky).
- Slopes rise at most 2.6 per 4 studs.

**Stairs**
- Steps rise at most 2.6 studs.
- Run along a wall, with a level landing at the head and at the foot. The foot landing is not a doorway, and there is no door behind the run.
- On the open side, a stepped parapet about 3 studs high, standing 0.05-0.25 proud of the ramp so the faces never tie.
- Never two staircases from one room into the same room upstairs.
- Make stairs walk smoothly with thin invisible collision treads (0.27) under the drawn steps. Feet and camera then ease over the steps.

**Doors and windows**
- No two doors into one room on the same wall within 24 studs. No decor across an opening from floor to head height.
- Every room has two exits.
- Windows: sill at most 3.6, 6 studs clear above, 3.5 wide. A thin parapet you can see, shoot and jump through, never
  a hole in a thick wall. At most two upstairs rooms per map look out.

**Views and clutter** (the most common failure)
- The busiest 90° view from a spot holds at most 3 "places to watch" (ways in plus windows within 140 studs), on at
  least 90% of the floor.
- A lane narrower than 28 studs keeps its floor clear. No gap beside cover narrower than 6.
- **Cut sightlines with a few large pieces, never many small ones.** Measured [M]:

  | Map | Pieces per 1,000 sq studs | Floor with under 4 studs of room | Longest straight run | Verdict |
  |---|---|---|---|---|
  | Before | 6.0 | 79% | 4 studs | "cramped" |
  | After | 2.6 | 57% | 8 studs | "much better" |

- Cover comes in two heights only: low at 4 (head shows, you can jump on it) and full at 8 or more. Cover within
  9 studs on average, 16 at the worst tenth.

**Arena benchmarks** (11 fan-favourite shooter maps measured at true scale with the same bots [M])
- 130-200 m² per player (1,600-2,400 m² for 12); 70-120 m end to end.
- A spot sees 8-20% of the map, and no spot sees all of it.
- First enemy in sight at least 1 s after spawning; under 5% of deaths within 5 s of a spawn; no spawn visible from a window.
- At most 45% of floor within 1.1 m of a wall or cover (the "cramped" maps measured 57-79%).
- 2-5 separate passages at every cross-section, and at least 2 routes between far spawns that share no place.
- 15-25% of the floor roofed. The route between ends at most 1.2x the straight line.
- Middle sightline about 31 studs, long tenth about 70. At most one deliberate long shot.
- A signature high place took about 2% of play time [M]: it is a landmark, not a camper's tower.

**Other worlds** (simulators, hubs, rides)
- Themed areas read from the walls alone. Wide canyon stages (about 300 studs) with 48-high themed walls and
  shelters cut into them every 30 studs; gates 24 wide and 24 clear.
- Parkour islands at least 41 studs apart, with a clear lane down the middle for newcomers.
- For speed, far things are a painted backdrop and near things are real 3D: close parallax is what sells speed. An
  endless road repeats every few kilometres with the seam hidden in a flash of light.
- Cheap life everywhere: chimney smoke, swaying banners, flowing water, clouds.

**Vegetation**
- Bushes are walk-through. Trim trunk collision so no gap is between 1.0 and 1.45 studs (no traps). Trees "never get stuck".
- Grass underfoot: a patch turns at most 0.08 rad per frame, roots float under 0.09 studs, nothing pops.
- Fade tree trunks on the line from the camera to the player.

**Decor with checkable promises.** Give every decor piece a kind, and check each kind's promise automatically:

| Kind | Promise |
|---|---|
| skin | within 1 stud of a solid |
| ground | at most 1.3 high |
| thin | under 1 stud thick |
| veil | above upstairs eye height and off every sightline |
| back | never over the play floor |
| sky | above 40 studs |

Room contents sit "a hand deep" against the walls. Never a copy-pasted rug in every room, and never hangar-sized
empty rooms. Put invisible lids over roofs a player shouldn't reach.

---

## III. Look: light, palette, materials

**What worked**
- One hero texture per surface (brick); worn stencils, signs and painted ground markings.
- A frame before the wall (pilasters 0.6 proud); a hood and a lantern at every real door.
- True cylinders for drums, wheels and bollards; faceted crowns on trees and rocks (that faceting is charm, not a flaw).
- Saturated accents on neutral ground, 2-3 tones per material.
- A colour language: real doors framed in one colour; white always means stairs.
- Terrain water over flat planes ("looks way more premium"). Waterfalls as Beams on the true parabola from the lip,
  with foam rings and spray (a flat sheet was "cheap af").

**What failed**
- Stock photographic materials (Brick, Cobblestone) beside clean shapes.
- Relief too strong ("quilted mat"); fine grain reading as stucco at arm's length.
- Leaf textures on spheres (gumdrops); plank textures on uprights (read as bricks).
- Navy floors (read as holes); red houses beside a red enemy outline.
- Near-white Neon plus bloom (white-out); a colour-grade effect left on after a ceremony.
- String lights ("annoying").

**Values.** Ground about 35-45% grey, walls 55-85%, white only as trim. Never darken a map that already reads well.
Calm rooms measure roughly 0.2-0.4 mean saturation on stills [M].

**Light** [M unless judged]
- Future lighting. Room lamps must cast shadows: a shadowless lamp shines through walls under Future.
- Room lamps: brightness 0.45-0.56, range 30-34, colour near white (255, 238, 220). A first try at 1.5 burnt the room out.
- Sun brightness about 3, shadow softness about 0.14. Keep the engine sun at least 7° up (the skybox fades to black
  as it sets), and place it with ClockTime and latitude.
- EnvironmentDiffuseScale above 0.2 tints shaded walls with the sky (teal plaster at 0.75).
- SmoothPlastic mirrors the sky at EnvironmentSpecularScale 0.6, so whites turn blue.
- Reflectance mirrors the skybox even inside closed rooms, and EnvironmentSpecularScale 0 does not stop it. A
  showroom needs its own black sky, or gold renders white or blue.
- Colours that read: deep colours for neon. Gold is saturated paint plus a soft glow (emissive about 0.7, halved at night).

---

## IV. 3D objects and characters

**The pipeline that worked: models as code**
- **Write every model as a Blender Python script**, run headless, in studs and Roblox axes, modelled around the pivot
  the game places it by. Each moving part is its own node, and the nodes are the game's pivots. Export the anchors
  (grip, muzzle, sockets) as data. Helpers: lathe, sweep, bevelled box, and signed-distance sculpting (muscles as
  melted ellipsoids, grooves pressed in).
- **Bake shading into vertex colour.** A grey ambient-occlusion and edge-lift shade goes into the mesh's vertex
  colours, and Roblox multiplies it by the part's Color, so one mesh serves every colour scheme with no re-bake.
  - Keep the AO weight low (about 0.22-0.3): Roblox reads greyer than Blender.
  - Bake swappable parts one at a time, or they shade each other dark.
- **Convert and bake.** Export glb → convert to Luau data so Studio builds it live in edit mode for looks → a Studio
  job uploads meshes and images as private assets, keyed by content hash.
  - Bake once at the end of a pass: AO noise re-hashes meshes on every rebuild.
  - Fresh uploads don't load for 5-15 minutes.
  - A full bake of ~600 meshes took ~25 minutes.
- **Until the upload,** draw primitives in the same slots and swap the whole rig to meshes at once (all or nothing).
- **For maps, the picture is the collision.** Export the layout from the game's own data, and let Blender stand each
  piece inside its collision box. Merge static art into a few big groups (a hub of 210k triangles in 16 parts).
  Run the z-fight scan and triangle count on every build. Apply preview-only offsets after export, never into the mesh.

**AI-generated models**
- Whole AI bodies lose. Their messy texture layouts break decimation, and they break the 20k-triangle and 4-bone limits.
- Use an AI model only as hard pieces riding one bone each. A whole AI body works only if it is already a machine of hard parts.
- In a head-to-head scored against a reference sheet [M], the raw AI model scored 67, the AI model cut per bone
  61, and a Blender remodel 47. The owner still picked the remodel on looks. Scores advise; the owner's eye decides.
- The best route: AI images as references, rebuilt in code on one skeleton, keeping code-driven motion.
- Generate on paid plans: free tiers can carry attribution licences, and some open models are not licensed in the EU.
- Studio's built-in mesh generator produced "a toy" with blotchy textures.

**Measured matching** beats eyeballing.
- Render the model at the reference's own angles and score:
  - silhouette overlap (IoU)
  - width profile, row by row
  - glow overlap
  - colour difference (CIE Lab)
  - light/shade correlation
- Feed an outline diff (shared / reference-only / model-only) to a strict reviewer.
- Silhouette overlap went from 29% to 88.5% in six rounds. Surface material (worn iron, rivets) stays the hardest
  gap, and Roblox flattens materials further.

**A painted picture as the body** (about an hour per item)
- Cut out the image, level it, and map it onto the in-game model's measurements (grip on the hand, muzzle on the
  muzzle; nothing bent more than 8%).
- Extrude the outline into two sheets plus a wall, with per-region thickness and a 55% chamfer at the edge.
- Use the picture itself as the paint, slightly darkened, with a light floor of about 0.42 (the painter already lit it).
- Model whatever the picture can't show (top, far side, moving parts) the painted way.

**Premium item recipe**
- Start from one sentence and three colours. Load the game's own model and build the kit on exactly what the game draws.
- Keep added pieces inside measured zones, clear of hands, controls and the sight line, and enforce that with a test.
- Cull faces no ray can see (a fifth to a quarter of them).
- Pack the UVs giving the most space to what the eye sees most. Bake colour, normal, roughness, metal and glow maps
  at twice the shipping size.
- Clad the most-seen side first; add one silhouette breaker and one moving or breathing part. Glow on about a third
  of the surface.
- Sizes: weapon kits 13-27k triangles with 1024 maps; small items 1-3k with 512 maps.

**Icons**
- Painted in one house style: signed-distance shapes, a dark ink rim at about 5%, a gradient fill per part, a bevel
  lit from the top left, a gloss streak, a drop shadow. Drawn at 4x and filtered down to 256 px.
- Or a toy-like 3D render with a thick outline grown around the silhouette (5-6.5% of the side, no inner lines).
- Render item icons from the game's own models and paint, so a tile can't show a finish the item doesn't have.
- Rarity is the frame and the light behind the icon, never inside the picture.
- Every icon must read at 128, 64 and 32 px and as a black silhouette. No emoji anywhere ("looks so AI and not 6A").

---

## V. Animation and feel

- **Procedural first.**
  - Drive held objects and limbs every frame from blended poses whose weights are springs: no AnimationTracks, no
    uploads, and the same code runs in tests.
  - A robot built as about 45 rigid shells, one per bone, moved entirely in code.
  - Tentacle-like limbs: a curve fitted to exact length, a "life" wave, then springs plus IK (FABRIK). Feet slide
    under 0.02 studs, joints stay under 110°, both enforced by tests.
- **Springs everywhere, solved exactly**, so 30 fps matches 240 fps [M]. Never linear tweens. Examples (frequency in
  Hz / damping ratio):

  | Motion | Spring |
  |---|---|
  | Weapon kick back | 10.5 / 0.46 |
  | Aiming sights | 8.5 / 0.6 |
  | Landing | 4.6 / 0.52 |
  | Weapon raise on spawn | 2.1 / 0.74 |
  | A loose latch (meant to rattle) | 5.5 / 0.22 |

  Use a curve on a clock, not a spring, when metal should stop dead on a pin and ring.
- **Keyframed clips written in code** over the Animator, for any R15 body.
  - A new clip starts from where the last one left off, so mashed inputs chain.
  - A jab makes contact at 0.065 s and lasts 0.22 s. A haymaker shows its wind-up over 0.42 s.
  - Limbs always turn the short way, checked by a test.
- **Hit feel.** Hit-stop 0.055-0.12 s; knockback eased over 0.28 s. Stop the hit NPC's MoveTo, or it walks straight
  back: 0.9 studs of net knockback before that fix, 4 after [M]. The body rocks away from the hit (5.5°, 9° for a headshot).
- **Life on held poses.**
  - Shoulders counter-rotate ±5° against the stride, read from the legs' own track position so they never drift.
  - Breathing.
  - A visible tell before an action: a bot lifts its weapon to the shoulder about 0.25 s, most of a second before it fires.
- **Squash comes from bones, never a scale tween.**
  - Bone.Transform drops scale [M], so local squash needs many bones moving.
  - Soft toys used a ~98-point soft body driving bones, with material behaviour fixed by tests: butter recovers in
    1.8 s and keeps a dent; jelly recovers in 0.2 s and wobbles at 6.3 Hz.
  - Things press flat against walls and rollers instead of passing through, spring back with a little overshoot,
    and land with a small squash.
- **The character acts with the object.** An avatar standing still while a machine works reads as fake; give it the
  handwheel. A reviewer flagged exactly this.
- **What the owner rejected:**
  - stiff recoil that never falls back
  - bots as "statues on running legs"
  - placeholder poses ("all very lame ... make them actually crazy exciting for roblox kids")
  - long ceremonies
  - "very cheap" NPC walks
  - morphing bodies outside the one mode that needs it

---

## VI. Engine facts (Roblox Studio, autumn 2026, mostly [M])

**Meshes and parts**
- 20,000 triangles per mesh (imported and EditableMesh); EditableMesh also caps at 60k vertices.
- Up to 4 bone influences per vertex. Nothing over 2,048 studs in extent (bigger meshes stay invisible in play).
- Remove zero-area faces and check winding (a lake mesh wound face-down was invisible from above). Back faces are culled.
- Built-in Ball and Cylinder parts are expensive: about 100k triangles across one arena, and the scene went from 253k
  to 150k after replacing them. A 20-sided bud mesh costs 20 triangles. Measure with `Stats.SceneTriangleCount`.
- A live EditableMesh casts no shadow, and neither do alpha cut-out parts. Clients run out of EditableMesh memory
  (a 35k-triangle model failed partway).
- **Server-built meshes:** on the server, build an EditableMesh, call `CreateDataModelContentAsync`, then
  `CreateMeshPartAsync`, and the result replicates as a normal MeshPart. 23 parts took 0.18 s; 155 images took about
  3 s. Published games need an ID-verified owner and "Allow Mesh & Image APIs".
- Precise render fidelity on long road meshes (automatic level of detail sagged them under terrain).

**Textures and surfaces**
- 4K textures are allowed (phones get smaller copies). EditableImage caps at 1024.
- A game Script cannot set SurfaceAppearance, MaterialVariant or Decal maps. Plugin and MCP contexts can, which gives
  false positives: test in a real Script.
- `CreateSurfaceAppearanceAsync` with EditableImages gives full PBR plus glow, but each client must build its own (a
  server-built one draws as a checker or wrong colours). It ignores EmissiveMask, so set the mask after creation.
- Glow = colour map × mask × tint × EmissiveStrength. Strength can be written every frame (breathing); bloom starts at about 1.6.
- A SurfaceAppearance replaces vertex colours, so its maps must carry all the shading. Taking an SA off a clone of a
  part blanks that mesh everywhere.
- MaterialVariants instead of Texture layers cut one map from 2,043 layers to 151.
- Particles, Trails and Beams draw only uploaded images. A textured Beam with Segments = 1 draws nothing.
- **A loaded image is not a drawn image.**
  - A new texture pops white, then flat, for about 0.4 s.
  - Draw the object unseen at its real on-screen size first (transparency 0.999, shadows and lights off).
  - Before giving a served image to a mesh, show it on a 1-pixel ImageLabel and wait for IsLoaded, or it stays blank for good.

**Characters and rigs**
- **Default R15 rig.** `CreateHumanoidModelFromDescription` joints are AnimationConstraints: C0 is read-only, and a
  Transform written once reverts. To pose, replace the joint with a Weld (C0 = joint C0 × turn); legs keep animating.
  Renaming parts loses clothes and body colours.
- **R15 dimensions.** Arm reach about 1.9 studs (upper arm 0.92, forearm 0.81). Root 3.18 above the soles, HipHeight
  2.19. A two-handed rifle needs the chest turned about 40°. Short-armed bodies need a "seated" hold (stock on the
  chest, compact weapon) to avoid clipping.
- **NPCs.**
  - NPCs built from a HumanoidDescription have no working Animate script: play animation packs server-side, or they
    stand or slide. Default walk, run and idle ids play anywhere.
  - Free bundles give varied avatars; base bodies need layered clothing (classic shirts don't show).
  - Dynamic heads ignore Face: weld a card with the face decal.
  - Never use a real person's likeness.
- **Morphing the player's avatar.**
  - ApplyMesh the new part onto each of the avatar's own parts, with UVs on Roblox's R15 per-part layout so clothing lands on the muscles.
  - Clothing shows only on uploaded meshes, not EditableMesh ones.
  - Turn off AutomaticScalingEnabled, size each limb chain by its joints, call BuildRigFromAttachments, then set
    HipHeight from the soles.
  - Use ball joints at elbows and knees, and give morphed parts their own collision group.
  - Budget: about 13-22k triangles per body.
- **Mesh swap stall.** The first ApplyMesh of an uncached mesh on a Humanoid freezes the server for about 0.19 s per
  mesh, then each client about 2 s later. About 700 other meshes evict it from the cache.
  - Preload with `ContentProvider:PreloadAsync({part})`, one spawn per part. On id strings it hangs forever on the server.
  - Announce the change, fetch on both sides, and swap about 0.35 s later.
  - The worst frame went from 2.6 s to 92 ms.
- **Viewmodels.** `Camera.NearPlaneZ` differs by device and is wrong in the first moment; read it late, or the weapon
  draws 3.5x too big.
- **Level of detail.** Pose the 5 nearest characters every frame, the rest at 15 Hz, at 8 Hz past 100 studs. Detail
  steps by distance with hysteresis.

**Terrain, culling, z-fighting**
- **Terrain water** draws only about 250 studs from the camera. Use it out to about 150, then a separate sea surface
  with a matching seam colour.
  - Keep the painted bed shallow (0.45-2.25 studs) or it reads dark teal. Fill ponds in whole voxel columns.
  - Low-end phones draw water as an opaque sheet.
- **Terrain streams in after parts.** Hold the loading cover until the ground under the camera exists ("frames under
  the map ... chopped up stuff").
- **Culling.** At render quality 1-3, parts stop drawing at about 300 studs, and a merged chunk vanishes whole, so put
  tall landmarks into parts that span the map.
- **Phone settings sweep.** Render quality 1 cut frame cost 32%, shadows off 20%, hiding near parts under 4 studs
  18%. Distance-culling far parts gave about nothing.
- **Z-fighting.** Only exact ties flicker. On a desktop GPU, a 0.002-stud gap never flickered. Part faces by
  0.01-0.03 (some teams use 0.09 for phones, unmeasured).
  - Usual culprits:
    - a stair block topped at tread height, or the last tread level with the floor
    - decals 0.01 proud
    - trim flush with its box
    - awning stripes, sign plates and gutters
    - neighbouring roofs on one slope plane
    - slabs lying exactly on a slope
    - crate frames at the box's own size
    - ties inside one mesh
  - Fixes:
    - Move the decor, never the collision box.
    - A stair block stops under its tread, and the last tread sinks into the floor.
    - A deck sits on its carrier; a wall stops at the face of the wall it meets; rails run between posts.
    - Decals sit at least 0.08 off the surface; put a dark sheet under plank decks.
    - Stand signs proud of the deepest bump on their wall.
  - **Not z-fighting:** shadow-edge crawl, aliasing on thin far lines, and phone text vanishing (that is the font
    atlas overflowing).

**Budgets** (these held at 60 fps on desktop, and were the starting point for phones)
- Arena maps: up to 3,000 decor parts, 25-65 draw calls, about 2.4 ms CPU.
- Island maps: 120-170 draw calls, 445-520k triangles at quality 8.
- Stage nodes under 12k triangles each.
- First-person scene: 54k triangles, 48 draw calls.
- Keep art data in ServerStorage, not ReplicatedStorage: that took a join from 39.6 MB to 2.7 MB.
- Switch things off by distance: emitters past 150 studs, lights past 4x their range, signs past 170; lights lit
  nearest-first with a cap per device tier.

---

## VII. Verifying the look

- **Judge from uploaded assets, in a real play session, in the game's light.** Edit mode lies:
  - Poses written as Transforms don't show.
  - Sign text is missing until one play session has run.
  - Meshes under water render without the water.
  - Live EditableImages drop glow late.
  - Blender's preview is far kinder than Studio. "Judge it in the game, not in Blender."
- **Look sheet.** About 6 fixed eye-height cameras (outside and inside), shown as before / after / reference. Never
  judge a pass by part count.
- **Film the real window.** Studio's own screen capture can lag up to 3 s and hide engine buttons; film the actual
  window instead. Film catches what stills miss:
  - a dark showroom washing out glows
  - a trail drawn as a white wedge across the view
  - blinking surfaces
  - crawling shadows
- **Flicker hunt with two eyes.**
  - A geometry scan for coplanar face pairs within a tolerance.
  - A pixel diff from a camera nudged a fraction of a pixel.
  - A ray that names both parts at each flickering spot.
  - Zero z-fighting is a hand-over gate.
- **Walking benches.**
  - Walk up every stair flight.
  - Run a grass walk that counts snaps, floating roots and pops.
  - Run a stuck test on every tree.
  - Run a headless walk survey that finds invisible blockers.
- **Map as data, a simulator and a critic.**
  - Draw a map as data (rows of characters with a legend, or a generator) and check it before any art.
  - 12 headless bots play a round in about 1.4 s, calibrated on recorded real play.
  - A layout change is kept only if it wins on two sets of random seeds, and a map may never get more cramped than
    the best-loved one.
  - The owner's complaints run as a critic test that blocks the build and draws a colour-coded plan.
  - When the owner feels something the numbers miss, add that measure.
- **Blind reviewers.** Fresh agents, told nothing of the intent, given shuffled unlabelled before/after pairs and
  eye-level stills, and framed harshly ("the owner thinks parts reek of AI slop"). Four of five found the fake
  openings unprompted. Check every claim against its frames.
- **Gates in tests.**
  - no-pop checks (no part moves more than it should between frames at 240 fps)
  - triangle and extent budgets
  - add-ons clear of the sight line
  - limbs taking the short path
  - feet on the ground at every body stage
  - the worst frame per 10 s in real rounds
- **Owner's eye last**: the run, the sun, a kid's phone. Hand over a playtest place every time, with the old version
  still playable beside the rework.

---

## VIII. Order of work

**A map**
1. Concept from a person: a sketch, a reference or words. Pick one of 2-3 pictured options.
2. Layout as data, with the scale constants and clearances above.
3. Simulate and check: flow, sightlines, room, spawns, the critic rules.
4. Grey-box in Studio, and walk it on a phone-sized view.
5. Art in Blender from the same data, with the picture as the collision. Run the z-fight scan.
6. Light and look pass, judged from uploads in play. Run the look sheet and the flicker hunt.
7. Blind review, fix, then hand over a playtest place.

**An object or character**
1. A reference plus one sentence and three colours. Measure the reference.
2. Model in code on the game's pivots and limits. Build the primitive stand-in first.
3. Measure the match against the reference (silhouette, width, colour), then fit it to the game's style.
4. Animate procedurally with springs, and give the character something to act with.
5. Bake once, upload, and judge in a real run in the game's light. Film it.
6. Run the budget, clipping and no-pop tests, then hand over.
