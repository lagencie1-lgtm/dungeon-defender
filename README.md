# Heroes Tower Defense

A co-op tower defense game for Roblox (first called Realm Guardians). The game idea is in `Game_Idea`.

The scripts live in `src/` as normal files. Rojo copies them into Roblox Studio live while you work.

## How to play (first version)

- Goblins walk from their camp to your magic portal. Every goblin that gets through hurts the portal.
- You start with 200 gold. Before each wave you get 20 seconds (30 before wave 1) to build. **Start wave now** skips the wait.
- **Defenders** (buttons at the bottom, or keys **1 / 2 / 3**):
  - **Ranger** (60): cheap, long range, hits one goblin
  - **Flame Cannon** (120): blasts groups and sets them on fire
  - **Frost Crystal** (90): slows every goblin near it, can freeze them at level 3
- Move the mouse to place it (green = okay, red = not allowed), click to build. Hold **Shift** to build several. **Q** or right click cancels.
- Click a defender to **upgrade** it (up to Lv 3) or **sell** it for 70% back.
- **Your hero, the Swordmaster**: **F** = sword hit, **E** = whirlwind. Kills give xp, every level gives +15% damage.
- 10 waves: Goblins, fast Goblin Runners, big Goblin Brutes, and the **Goblin King** boss in wave 10.
- Win or lose, press **Play again** to start over.

## New in the big update

- Sounds, hit flashes, damage numbers, gold/gem pops, screen shake, wave banners, combo counter
- Talking goblins, the **Loot Goblin** (catch it for gems), meme wave names, GG / skill issue end screens
- **Storm Obelisk** (key 4) and **Ballista** (key 5): unlock them in the Shop with gems
- Hero **Leap Strike** (R), sword skins (yes, a baguette) and titles over your head
- **Gems** are saved between games: from drops (walk over them), every wave and wins
- **Shop** (B), **Daily reward** with a 7-day streak, **Wins / Gems / Best Wave** in the player list
- **Difficulty** (Easy / Normal / Hard, before wave 1) and a **2x speed** button
- **Phones**: tap a defender, tap the ground, press "Build here"; round attack buttons on the right

Saving gems in Studio needs: Game Settings > Security > Enable Studio Access to API Services (after publishing once).

## Loot (roadmap phase 1)

- Goblins sometimes drop gear for you (everyone gets their own drops). Walk over it to pick it up. Rare and better drops have a light beam.
- The Goblin King always gives a **Victory Chest** with a Rare or better item.
- 6 rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic. 5 slots: Weapon, Helmet, Armor, Boots, Trinket.
- Stats: Power (hero damage), Command (your defenders' damage), Engineering (your defenders' speed and range), Crit, Gold Find.
- Weapons change the sword hit: Longsword (balanced), Greatsword (slow, hits a crowd), Twin Blades (very fast, one goblin).
- **Backpack** (button or I): equip, compare, upgrade +1 to +10 with **gold**, salvage into **scrap** (needed from +8).
- **Shop → Gear Looks**: choose a weapon, armor, helm, boot or amulet appearance and turn its 3D preview before
  equipping it. Eight matching sets are free to mix and match without changing your gear stats.
- **Shop → Skins → Outfits**: preview and equip a full five-piece set in one click. Original gear restores the
  default appearance of all five slots.
- **Shop → Skins**: the five defenders each have a free matching finish for new builds. Wear any of the four Pet
  looks to give your equipped companion the set's colors.
- Gold is earned at the end of every run and kept. The building money during a run is now called **mana**.
- Harder difficulty = better items.

## Roadmap phase 2 and 3

- **The Outpost** hub: start pad, Blacksmith (backpack), Gem Shop, Hero Altar, Map Board, Pet Corner, Quest Board, Daily Chest, Trophy Wall.
- **Heroes**: Swordmaster, Rune Mage, Machine Engineer. Levels (up to 50) and stat points are saved per hero (Power, Vitality, Command, Engineering).
- Goblins now hurt heroes standing in their way; heroes respawn after a few seconds.
- **Maps**: Cursed Forest and Magma Fortress (fire-proof imps, armored knights, splitting slimes, Molten Golem boss).
- **Build Points** limit how many defenders the team can build; more players = tougher goblins.
- **Modes**: Campaign, Endless (world leaderboard on the Trophy Wall), and 3 challenges with a first-clear reward.
- **Nightmare** difficulty, **daily quests**, **pets** (eggs cost gold, chances shown), **Rebirth** at level 50 and **Ascension** points after it.

## Testing

`bash scripts/autotest.sh` plays the game by itself in Studio at 8x speed and prints any script errors.

## Publish without Studio

Put the game's ids in `scripts/publish.json` and your Open Cloud API key in `tools/roblox-api-key.txt`, then run
`powershell -ExecutionPolicy Bypass -File scripts\publish.ps1`.

## Files

- `src/shared/Config.luau`: all the numbers (path, gold, enemies, waves, defenders, hero). Change balance here.
- `src/shared/Remotes.luau`: messages between the players' computers and the server
- `src/server/MapBuilder.luau`: builds the Cursed Forest map when the game starts
- `src/server/EnemyService.luau`: goblins, moving them, health bars, burning/slowing/freezing
- `src/server/TowerService.luau`: defenders: build, upgrade, sell, shoot
- `src/server/HeroService.luau`: the Swordmaster, abilities and levels
- `src/server/GameService.luau`: waves, gold, portal health, win and lose
- `src/server/Effects.luau`: arrows, explosions, rings, floating text
- `src/client/Hud.client.luau`: the game screen and controls

## Start working

1. In a terminal in `C:\Projects\RealmGuardians` run `tools\rojo.exe serve` and leave it open.
2. Open `RealmGuardians.rbxl` in Roblox Studio and click **Plugins > Rojo > Connect**.
3. Press **Play**. Errors show in **View > Output** (red text).

To make a fresh place file from the scripts: `tools\rojo.exe build -o RealmGuardians.rbxl`.
