# Realm Guardians

A co-op tower defense game for Roblox. The game idea is in `Game_Idea`.

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
