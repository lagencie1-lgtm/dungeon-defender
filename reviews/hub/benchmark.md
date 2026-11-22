# Hub benchmark (2026-11-22)

How the Outpost compares with the hubs of the biggest Roblox tower defense games, what they do that we don't, and the
plan for the rebuild. Sources: one lobby video per game reviewed by Gemini with the same questions as our own clip
(`scripts/yt_review.py`, full answers in `bench/*.md`, summary in `bench/SUMMARY.md`), plus my own read of stills.
Other games' pictures stay out of git (this repo is public); only our own pictures are committed here.

## Ratings (1-10, harsh, against the best of 2026)

| Game | Hub | Towers | Monsters | Map | UI | Mobile/console | Effects | Playing now / visits |
|---|---|---|---|---|---|---|---|---|
| Five Nights TD 2 | 8 | 7 | 7 | 8 | 6 | 6 | 7 | ~0.7k / 870M |
| Pet Simulator 99 | 8 | - | - | 6 | 8 | 9 | 7 | 55k / 2.7B |
| Anime Adventures | 7 | 6 | 4 | 6 | 5 | 6 | 4 | 81k / 2.7B |
| Anime Last Stand | 7 | 6 | 5 | 6 | 6 | 4 | 7 | (dead) / 1.1B |
| Tower Defense Simulator | 6 | 7 | 6 | 7 | 8 | 7 | 7 | 17k / 5.1B |
| Anime Vanguards | 6 | - | - | - | 5 | 4 | 7 | (dead) / 2.1B |
| Garden Tower Defense | 6 | - | - | - | 7 | 5 | 5 | 8k / 0.8B |
| All Star TD | 6 | - | - | - | 5 | 6 | 4 | 2k / 8.0B |
| Toilet Tower Defense | 4 | - | - | - | 5 | 4 | 3 | 47k / 6.2B |
| Grow a Garden | 3 | - | - | 2 | 5 | 4 | 4 | 19k / 36B |
| **Ours, Gemini** | 4 | 4 | 3 | 3 | 5 | 6 | 3 | |
| **Ours, my read** | **4** | **4** | **3** | **4** | **4** | **3** | **4** | |

"-" = the video shows no match. None of these has 100k playing today; all had billions of visits at their peak.

My read of ours (frames in `ours-before-phone.png`, iPhone 13 size, graphics 8):
- **Hub 4.** A meadow with props and a small portal arch. From spawn you see a campfire, a block-built gatehouse and
  stalls with no names (the labels were removed in the last change, the prompts only appear close up). Open horizon
  of hills on three sides: nothing says "this is the place". The gatehouse is grey-box parts against painted props.
- **Towers 4.** Good painted models, but **every one stood 2 studs deep in the ground** (only the tops showed). Fixed in
  phase 2 (`ground-towers-before-after.png`).
- **Monsters 3.** Same 2-3 studs sunk; and with the default camera (12 studs behind the hero) a wave is mostly off
  screen: in 20 s of wave 1-2 the clip shows almost no goblins.
- **Map 4.** Flat dark-green field with a red strip; at low graphics it is very dark.
- **UI 4.** On a phone: five text pills on the right ("Sword", "Whirl", "Leap"), a text "Menu" button, three lines of
  small yellow text over the hero ("Goal: ...", "This week: ..."), and the joke banner "The tutorial nobody asked for".
- **Mobile/console 3.** Touch works; **there is no gamepad support at all** (no code for it in `src`).
- **Effects 4.** Little to judge; level-up text and flame streams read fine.

## What the top hubs do that ours doesn't

1. **One big word over every station** (PLAY, SUMMON, UPGRADE, SHOP): 3D or neon letters 2-3 avatars high, readable
   from spawn. 7 of 10 games. Ours: no signs, tiny prompts.
2. **Spawn faces PLAY, and PLAY is the biggest, brightest thing**, 10-15 steps away. Ours: a campfire and gatehouse
   stand between spawn and a smallish arch.
3. **Walk-in play pads with the map name and a party count** ("0/4"), always backed by a PLAY button on screen.
   Ours: one pad, no map name in the world, no party count.
4. **A compact, enclosed plaza** (about 60-150 studs) where play, shop and the summon/upgrade spot are all in the first
   view, framed by buildings and walls: **no empty horizon**. Ours: an open meadow, hills, nothing behind the stations.
5. **A landmark that is the game's own core** (a summon altar, a prize wheel, a SUMMON marquee). Ours: generic arch.
6. **Bright, saturated daylight with emissive accents** (cyan floors, pink and gold signs). Even the dark hubs are lit
   by many coloured signs. Ours: muted green-brown, dark on phones.
7. **Boards that show the goods**: units on pedestals, shop cards, map billboards with art. Ours: nothing shows a tower
   or a map until a menu opens.
8. **Life**: NPC keepers at stations, other players, moving things. Ours: one campfire and a practice arrow.
9. **HUD**: icon buttons with one word, down the screen edges; the loadout bar bottom centre; one PLAY button; no
   sentences in the middle. Ours: text pills and sentences over the hero.
10. **Run camera**: the TD games show the lane from higher up, so the wave and your towers are on screen. Ours starts
    close behind the hero.

## Hub concept for the rebuild: "The Watch Keep"

A compact walled frontier courtyard, about 110 x 90 studs, everything visible from the spawn camera.

- **Spawn** at the south gate, facing north. Straight ahead, 30 studs away: **the Portal Gate**, the biggest and
  brightest thing (portal ring 18 studs, soft violet glow), with the word **PLAY** above it and three **walk-in map
  pads** in front (map name, painted map picture, "0/4" party count, locked maps show what unlocks them).
- **The landmark**, in the middle: **the Beacon Tower**, a tall stone watchtower (about 40 studs) with a big crystal
  beacon on top that turns slowly and glows. It is the Outpost's own and is seen from every map's loading screen idea:
  "the keep that watches the realm". (Alternatives for Lemp: a giant hero statue with a sword raised; a huge ballista
  on a bastion.)
- **Stations on a ring** around the plaza, each a painted building with one big word and a walk-in ground ring
  (no tiny prompts): FORGE (west), HEROES (west), SHOP (east), PETS (east), QUESTS and REWARDS by the spawn,
  a **tower showcase** (the five real tower models on pedestals with their names) along the north wall, a
  **trophy board** with the real leaderboard by the gate.
- **Walls all round**: a timber palisade on stone footing with corner watchtowers; big trees and cliffs behind as
  the skyline. Bright warm afternoon light, saturated paint, emissive only on the portal, the beacon and the signs.
- **Life**: banners and trees sway, chimney smoke at the forge, three idle keepers (smith, merchant, pet keeper),
  ambient birds and the forge hammer.
- **Phone and console first**: the PLAY button on the HUD walks you to the portal pads (or teleports after 1 s), all
  stations reachable by gamepad and touch, words big enough at 10 feet.
- The old Outpost stays playable behind `Config.HubVersion` until the new one is approved.
