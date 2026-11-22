# Toilet Tower Defense

Source: https://www.youtube.com/watch?v=US_r8nhxgXs (Gemini model gemini-3.8-flash)

### Part A — Lobby / Hub

1. **Layout and size:** A linear city-street corridor (roughly 100–150 studs long) bounded by blocky building facades, opening via a tunnel arch [03:06] into an upper courtyard for PVP, Ranked, and Raids [03:15–04:05]. The skyline consists of generic flat-textured Roblox high-rises [00:50].
2. **First 5 seconds:** Spawns on a concrete sidewalk facing a two-lane road lined with massive map billboards ("Cameraman HQ", "Toilet City") and walk-in pads [00:00–00:05].
3. **The landmark:** The towering wall of billboard displays directly across the central road [00:07, 01:43].
4. **Match starting:** Walk-in rectangular pads on raised curbs [01:21, 01:28]. Map names sit on giant screen billboards above, with pad occupancy shown via clear text counters ("0/5") [01:28].
5. **Stations:** Signed with bold billboard headers, glowing ground rings ("Trading Plaza" portal [00:03]), 3D props (giant Titan Cameraman laser-firing at a toilet [03:35]), and framed text booths ("Post Office" [00:54], "Raid Shop" [03:55], "Speed Run Mode" [04:18]).
6. **Lighting and colour:** Blinding noon daylight, harsh directional sun, high-saturation blue sky, and stark primary-color textures [00:00–00:30]. 
7. **Life:** Mostly lifeless and static. Aside from player movement, blue sparkle mount trails [02:25], a static laser beam [03:35], and the spinning trade portal ring [00:03], the hub lacks moving ambient NPCs or dynamic environment animation.
8. **HUD layout:** Left edge has five stacked buttons (Units, Shop, Trading, Clans, Traits) [00:00]; top center displays claimable gift timers [00:00]; top right holds Event and Log buttons [00:00]; bottom center hosts a compact hotbar (slots 1–5, tool slot R) and currency counters [00:00]. Keyboard keybind prompts (`1`–`5`, `R`, `E`) are visible [00:00, 00:06].

---

### Part B — Match Gameplay
Not visible. The video showcases only lobby walk-throughs, UI menus, and developer panels.

---

### Part C — Ratings (1–10, Harsh 2026 Standards)

* **Hub (4/10):** Functional layout, but visually archaic with primitive block geometry and flat building facades [00:50].
* **Towers (Not visible in match):** n/a
* **Monsters (Not visible in match):** n/a
* **Map (Not visible in match):** n/a
* **UI (5/10):** Standard bloated simulator aesthetic; inventory menus [05:14] are cluttered, though stat tooltips are readable [04:31].
* **Mobile/console UX (4/10):** Heavy reliance on small clickable icons along screen borders; small tap targets will feel cramped on phones [00:00].
* **Effects (3/10):** Extremely basic static particle emitters, flat laser cylinders, and standard Roblox beam instances [02:25, 03:35].

---

### Part D — 5 Hub Elements to Copy

1. **Giant Billboard Map Displays:** Mounting oversized (approx. 20×10 studs) billboards directly above queue pads [00:07, 01:43] removes the need for pop-up match menus.
2. **Clear Player-Count Floor Pads:** Using distinct raised rectangular pads marked with explicit capacity counters (e.g., "0/5") [01:28] ensures instantaneous readability without menu navigation.
3. **Partitioned Gameplay Zones:** Funneling standard queues along the main road while routing advanced modes (Ranked, Raids, Speedruns) through an archway [03:06–03:15] prevents UI clutter and guides new players naturally.
4. **Low Part-Count Optimization:** Keeping hub architecture primitive (capped around 3,400 parts) [01:21] ensures fast loading and high frame rates across lower-end mobile devices.
5. **Physicalized Mode Portals:** Placing distinct, thematic 3D dioramas (such as the Titan statue for Ranked [03:35] or the raid conveyor setup [03:55]) makes secondary modes recognizable from a distance.

## Own read of stills

Stills: img/toilet-tower-defense-1.jpg (video thumbnail), img/toilet-tower-defense-frame1..3.jpg (YouTube auto frames at about 25/50/75% of the video), img/toilet-tower-defense-2..6.png (Roblox store images, key art).

- Hub is a blue-sky city street. Match start is a row of identical queue pads under one big billboard per map ("Toilet HQ", "Palm Paradise", "Apocalypse City"). Billboards are about 3x the pad width and tilted toward the player; small labels over each pad repeat the map name.
- Secondary modes (Speed Run, Ranked PvP) get their own blue tower board with a leaderboard, plus grass and a paved path leading to them.
- Landmark: the oversized billboards and the toilet/cameraman statues on the Ranked PvP stage.
- HUD is light: 3 round icon buttons left (Units, Shop, Trading), Clans/Traits pills bottom left, a 5-slot loadout bar with costs bottom centre, a 31-day reward calendar right, gift "READY" top centre.
- Lighting: flat noon, white/blue palette. Simple block geometry and stripes; reads clearly on a phone.
