# Every device pass (2026-11-25)

`python scripts/device_pass.py` plays the Rule 1 route (Outpost, Shop, Pets, Backpack, a run with a Ranger, its
upgrade panel) once per device in Studio's Device Emulator, measures every screen (`test/devices/Devices.client.luau`)
and takes a screenshot at each step. Sheets: `<key>-sheet.jpg`, all devices: `overview.jpg`, numbers: `results.json`.
Blue outlines = Roblox's thumbstick and jump button, green frame = TV-safe 90%.
Ratings (judged as a 9-13 year old on that device) are in `ratings.json`.

The checks: **Cut** (nothing outside its screen area), **TV safe** (controller: inside the middle 90%), **Thumbs**
(touch: no button on the thumbstick or jump button), **Tap** (touch: 44 px always on screen, 36 px in a panel),
**Text** (11 px phone/tablet, 12 PC, 18 per 1080 lines TV), **Fits** (no cut text), **Overlap** (no two buttons on
each other), **Road** (in a run, at most 8% of the road ahead, the middle 40% of the width 18-45% down the screen,
under our UI, see-through chips and text counted; orange outline).

## Emulator ids used

Studio's own list (`StudioDeviceSimulatorService:GetDeviceListAsync()`, 43 presets). Studio has no 4K preset and no
custom devices through the API, and the "oldest" presets are the iPhone 7 and the Galaxy A06.

| key | Studio id | UI size measured | problems before -> after | rating |
|---|---|---|---|---|
| iphone_se | iphone_7 | 666x374 | 40 -> 1 | 6 |
| iphone_new | iphone_16_pro_max | 830x439 | 23 -> 1 | 7 |
| android_old | samsung_galaxy_a06 | 705x338 | 39 -> 0 | 6 |
| android_new | samsung_galaxy_s25_ultra | 685x338 | 39 -> 0 | 6 |
| ipad_old | ipad_6th_generation | 1023x768 | 2 -> 0 | 8 |
| ipad_pro | ipad_pro_M5_13in | 1375x1032 | 0 -> 0 | 8 |
| xbox_1080 | xbox | 1919x1079 | 193 -> 0 | 7 |
| xbox_4k | ps5 (no 4K preset) | 1919x1079 | 193 -> 0 | 7 |
| tv_touch | hd_1080 + touch | 1919x1079 | 0 -> 0 | 6 |
| pc_laptop | average_windows | 1365x768 | 0* -> 0 | 7 |

\* pc_laptop ran without emulation the first time (Studio's own window, 2030x1121); its sheet showed the problems
listed below that the checks don't count.

## What was broken and what I fixed

**Phones (all four)**
- Panel buttons were 16-34 px tall (Shop tabs and buy buttons, Pets close/Hatch/x3/Equip/Release, Backpack close,
  Save, Set 1-3, Auto-salvage, Equip/Upgrade/Salvage). Now at least 36 px on the smallest phone: touch sizes in
  `Hud` (`PANEL_TAP` 64, shop rows 76), `Pets` (`PET_TAP` 74, rows and egg cards taller), `Loot` (`TAP` 68,
  Equip/Upgrade/Salvage side by side at the bottom of the details, grid and details moved down).
- Start wave, Speed and the three abilities were 37-43 px on the Androids: they now grow to 44 px on small phones
  only (`fitTaps` in Hud, sized from the real screen scale, so bigger phones keep the old size and the run UI
  stays within the mobile test's 30%).
- The next-goal line was 9-10 px: now at least 11 px on every phone.
- The map button and the leftmost defender card lay on the thumbstick on the iPhone 7: lobby bar and defender
  cards moved 24 right on touch.
- The defender's Sell button lay on the jump button (iPhone 7): the info panel now sits under the wave buttons,
  170 from the right edge.
- Backpack's "Click an item..." text was 9-10 px and then didn't fit: 21 on touch in a taller box.

**iPad**
- The lowest ability (Leap) lay on the jump button (tablets put it 210 px up): the ability column now always sits
  above the jump button.

**Xbox / PlayStation (controller)**
- 26-47 buttons and texts per screen were in the outer 5% a TV can cut off (dock, abilities, defender cards, hint
  line). With a controller every screen now keeps to the middle 90% (`Ui.fitRoot`), text stays the same size.
- The B badge on the defender panel ("Circle" on a PlayStation) stuck out: the panel moved in.
- The tutorial line lay on the defender cards: it sits higher with a controller.
- The hero panel was half under the taller menu dock: it moves right of the dock when they meet.

**Every device**
- The next-goal chip covered the Start wave / Speed buttons in a run on PC and controller: moved under them.
- Locked defender cards showed "160 mana · 4 bp" and "60 gems" on top of each other: only the gem price shows now.
- Shop tabs were in name order (Codes, Gear Looks, ... Defenders last): now in their real order, Defenders first.
- The tutorial hint lay across the middle of any open screen (Shop, Pets, Backpack): it hides while a screen is open.

**Test tools**
- `device_pass.py`: real emulator ids, measured sizes, screenshots from the right Studio by file name (the first
  run took them from another open Studio), PC laptop preset, finds its own log even with other Studios open.
- The device plugin only turns phones and tablets (TV presets refused the orientation and reported a failure).
- The route opens one screen at a time and builds the Ranger on the map's first building spot (the spawn is on the
  path).
- `autotest.sh` and `studio_test.ps1` picked the newest Studio log, which can be another open Studio's: one run
  "finished" at once on an old log. They now take the log their own Studio made.

## Road ahead (2026-11-25, second pass)

The orange RoadAhead box sits over the lane past the hero, the stretch 30+ studs down the road (the bridge and the
lane behind it on the Cursed Forest run camera), so I left the box as it was.

| key | Road before (Run / Defender) | after |
|---|---|---|
| iphone_se | 30% / 33% | 0 problems |
| iphone_new | 22% / 27% | 0 problems |
| android_old | 33% / 33% | 0 problems |
| android_new | 33% / 33% | 0 problems |
| ipad_old | ok / 22% | 0 problems |
| ipad_pro | ok / 18% | 0 problems |
| xbox_1080 | 38% / 38% | 0 problems |
| xbox_4k | (not in the first list) | 0 problems |
| tv_touch | (not in the first list) | 0 problems |
| pc_laptop | 21% / 21% | 0 problems |

What covered it and what I changed:
- **Touch (phones, tablets, touch TV): the run bar** (wave, mana, build points, portal) sat under Roblox's top bar,
  right over the road. It now sits up in the band of Roblox's top bar, whose middle is free (Roblox's buttons are at
  its left end). It has its own screen, `RunBar`, with DeviceSafeInsets, so it still keeps out of the notch and the
  home bar (the mobile test's rule is about those). Nothing was dropped from it. Mana orbs still fly to its mana line
  (ManaFly converts between the two screens). The phone run screen's UI cover went from 30% to 23%.
- **Tablets: the defender panel** sat in the road box: on a tablet it now sits just above the defender cards (phones
  keep it under the wave buttons, clear of the jump button). It is placed again when the screen size changes, not
  only when the HUD scale does (the iPad Pro kept its old place, its scale stays at the 1.3 cap).
- **PC and controller:** the run bar moved to the top-right corner, Start wave and Speed under it, and the goal chip
  to the left of the bar at the top. They had sat in the middle over the road (Start wave, Speed, the bar and the chip).
- The phones' goal chip hides 5 s after it changes (commit 0acab79).
- The Cut check now measures each screen in its own coordinates (a screen that reaches into the top bar band starts
  above the usual (0,0)).

## What is left (not fixed)

- **Thumbs, Pets (iPhone 7 and 16 Pro Max)**: when the egg list scrolls, a Hatch button can sit over the
  thumbstick's resting place. While a panel is open the button gets the touch first and the stick isn't used, so I
  left it, but the rule counts it. I did not weaken the check.
- **4K**: Studio can't emulate it. The 4K scale (up to 3x) is checked by test/gamepad's Readable step instead.
- **The Text check skips text that scales to its box** (TextScaled): the Pets index numbers (+100...), item
  captions and shop descriptions pass but look tiny on phones and from a sofa. A rule with a number for scaled
  text would be the next check to add.
- **Touch TV and iPad Pro**: the touch HUD stops at 1.3x, so on a big screen it sits small in the corners.
- **Ability names** sit under their painted icons on PC and controller ("S/ord").
- **Tutorial names**: with a PlayStation pad the tutorial says "LT" while the badges say "L2".
- The DEV tab (owner only) overlaps the ability column on phones and iPads; players never see it, so the checks
  skip it.
- The route doesn't open the Shop's Gear Looks/Skins tabs, Heroes, Quests or Season on each device; their touch
  sizes weren't measured here (the controller test reaches every button in them).
