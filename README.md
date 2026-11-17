# Realm Guardians

A co-op tower defense game for Roblox. The game idea is in `Game_Idea`.

The scripts live in `src/` as normal files. Rojo copies them into Roblox Studio live while you work.

- `src/shared/Config.luau`: all the numbers (path, goblin health and speed, waves)
- `src/server/MapBuilder.luau`: builds the Cursed Forest map when the game starts
- `src/server/EnemyService.luau`: spawns goblins and moves them along the path
- `src/server/Main.server.luau`: starts everything and sends a test wave
- `src/client/`: scripts that run on each player's screen (the game screen comes here later)

## One-time setup

1. Download `rojo-7.7.1-windows-x86_64.zip` from https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1
   and put the `rojo.exe` from inside it into `C:\Projects\RealmGuardians\tools\`.
2. Open Roblox Studio, open the **Toolbox**, search **Rojo** in Plugins and install the one from **rojo-rbx**
   (version 7.7). A "Rojo" button appears under the **Plugins** tab.

## Every time you work on the game

1. Open a terminal in `C:\Projects\RealmGuardians` and run `tools\rojo.exe serve`. Leave it open.
2. In Studio open your place (start with a new **Baseplate**), click **Plugins > Rojo > Connect**.
3. Press **Play**. The forest gets built and 8 goblins walk to the portal.
   The **Output** window (View > Output) shows "Portal health: 99", 98...
4. Save the place with **File > Save to File** so you don't lose it. Scripts are saved in this folder anyway.
