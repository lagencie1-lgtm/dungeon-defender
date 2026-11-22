# Hub benchmark: popular Roblox TDs and two hub giants

Made 2026-11-22. Scores are Gemini's harsh 1-10 ratings (Part C of each review, `scripts/yt_review.py`), judged only on
what the chosen video shows. "n/a" = the video showed no match. Gemini invents details: the "Own read of stills" section
at the end of each file is checked against real frames in `img/`. Player numbers: Roblox games API, "playing now" on
2026-11-22 around 18:30 CET (Saturday evening), plus lifetime visits.

| Game | Hub | Towers | Monsters | Map | UI | Mobile/console | Effects | Playing now / visits | Video |
|---|---|---|---|---|---|---|---|---|---|
| Anime Vanguards | 6 | n/a | n/a | n/a | 5 | 4 | 7 | 4 / 2.11B (place renamed "Vanguards: Embers of Justice") | https://www.youtube.com/watch?v=oNjSbx3BCc0 |
| Toilet Tower Defense | 4 | n/a | n/a | n/a | 5 | 4 | 3 | 46.6k / 6.24B | https://www.youtube.com/watch?v=US_r8nhxgXs |
| Tower Defense Simulator | 6 | 7 | 6 | 7 | 8 | 7 | 7 | 16.9k / 5.10B | https://www.youtube.com/watch?v=M1Lp6hOBeSI |
| Anime Adventures | 7 | 6 | 4 | 6 | 5 | 6 | 4 | 81k / 2.66B | https://www.youtube.com/watch?v=fXmaOwZ1ohc |
| Anime Last Stand | 7 | 6 | 5 | 6 | 6 | 4 | 7 | 34 / 1.08B | https://www.youtube.com/watch?v=AfB9AHbDsf0 |
| Garden Tower Defense | 6 | n/a | n/a | n/a | 7 | 5 | 5 | 8.0k / 837M | https://www.youtube.com/watch?v=jAvZ0O__ShY |
| All Star Tower Defense (OG) | 6 | n/a | n/a | n/a | 5 | 6 | 4 | 2.0k / 7.97B | https://www.youtube.com/watch?v=KYVut17R78A |
| Five Nights TD (2) | 8 | 7 | 7 | 8 | 6 | 6 | 7 | 357 + 314 (FNTD2 / After Hours) / 757M + 114M | https://www.youtube.com/watch?v=hSjQ9bEoLBo |
| Pet Simulator 99 | 8 | n/a | n/a | 6 | 8 | 9 | 7 | 55.5k / 2.72B | https://www.youtube.com/watch?v=qASqgaTCKzo |
| Grow a Garden | 3 | n/a | n/a | 2 | 5 | 4 | 4 | 18.6k / 36.0B | https://www.youtube.com/watch?v=NhqxbiQ0ZoY |
| *Ours (earlier clip, ours-before-phonehq-crop.md)* | 4 | 4 | 3 | 3 | 5 | 6 | 3 | - | - |

Notes on the picks:
- Over 100k playing right now: none of these. Anime Adventures (81k), Anime Crusaders X (74k, not reviewed), Pet Sim 99
  (55k) and TTD (47k) are the biggest today; all peaked far higher (billions of visits). Anime Vanguards (4) and
  Anime Last Stand (34) are effectively dead now, so their hubs show what worked at their peak.
- All Star TD: the first video (fX1bACoPZlQ, "NOVO LOBBY") was a facecam/Discord leak video with no gameplay; it was
  replaced by a 2026 codes video filmed in the OG lobby.
- Gemini's size estimates are loose (it called the AV plaza 250-300 studs; frames show ~60-80 studs to the back wall of
  the spawn stage). Treat sizes below as rough.
- Store images (img/*-2..6.png) are almost all key art, not hub shots. The useful stills are img/*-frame1..3.jpg.

## Recurring hub patterns (3+ games)

1. **Big 3D wordmarks over every station** (AV, TDS, FNTD, AA, ASTD, GAG, TTD billboards): extruded or neon text
   2-3 character heights above the doorway, readable across the hub and in a thumbnail; Gemini puts the main ones at
   "20+ studs wide". One word each: PLAY, SUMMON, UPGRADES, EVENT, MODIFIERS, QUESTS.
2. **Spawn facing the main play/summon station, core within ~10-15 steps** (AV, TDS, FNTD, ASTD, ALS, AA). Gemini's
   recommended radius for the whole hub is ~150 studs; play, summon and shop sit in the first view.
3. **Physical match start with a visible party count** (TTD "0/5" pads under per-map billboards, ALS "0/4" doorways
   and "1/1 Players" wall text, GTD "0/4" pads, AV portals with "Party 1/4"), always backed by a **HUD PLAY button**
   (TDS, GTD, AV, AA). Walk-in for feel, button for speed.
4. **Summon/gacha as the architectural landmark** (AV crystal altar, FNTD "SUMMON!" marquee, GTD pergola, AA,
   TDS prize wheel on a plinth). What you spend on is what you see first.
5. **Edge-column HUD + bottom loadout bar** (all TDs): 6-8 labelled square/round buttons per screen edge, a 5-6 slot
   unit bar with placement costs bottom centre, currencies beside it, event timer top centre. Locked slots show
   their unlock level (ASTD, FNTD). Denser HUDs (AV ~20 buttons) get marked down for phones.
6. **Timers and claimables that pull you back**: daily prize wheel (TDS, ALS), 31-day calendar / "READY" gift
   (TTD, PS99), shop restock countdowns (GTD, GAG, FNTD), red notification badges (PS99, ALS, AV).
7. **Bright daylight, saturated palette** (TTD, TDS, GTD, ASTD, PS99, GAG, AV). The exceptions (FNTD, AA) are dark
   rooms lit by many coloured neon emissives, never plain dark.
8. **Secondary modes routed off the main path** (TTD archway to Ranked/Speedrun, PS99 separate trade plaza, AV/GTD/ALS
   AFK chamber or portal): the first view stays simple, depth is one walk away.
9. **Shop boards that show the actual goods** (GTD tall unit-card boards with countdown, FNTD pedestal unit, TTD
   map-preview billboards, AV mirror-frame portals with boss art): you see what you get before opening a menu.
