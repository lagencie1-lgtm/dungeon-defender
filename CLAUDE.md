# Heroes Tower Defense (Roblox) — notes for every session

The owner (Lemp) is a Roblox beginner: explain in plain words, hand over playable builds with a short summary,
and batch taste calls as 2-3 options with your pick.

## The quality bar: 6A (always)
Read and follow the 6A guides before any game, art, UI, effect, audio, map or monetization work:
- `docs/6A/6A-principles.md` — the 25 principles (short, read first)
- `docs/6A/6A.md` — numbers and cases from five Roblox games
- `docs/6A/6A-roblox-world-and-art.md` — Roblox worlds, models as code, animation, engine facts

The rules that matter most for this game:
- Judge as a 9-13 year old on a phone, in the first 10 minutes. The weakest visible part sets the grade.
- Restraint: effects rare, small (about half the first instinct), short, away from where the player aims.
  Camera shake only on real impacts. If you can name the effect, it is too strong.
- No emoji or symbol glyphs as icons. One painted art set in one style (see `art/STYLE.md`).
- Motion with springs or `1 - exp(-k*dt)`, never linear tweens or per-frame lerp. UI 90-160 ms, reveals 280-450 ms.
- Hits: short hit-stop, knockback that really moves the target. Bosses never go quiet (telegraphed, chained attacks).
- Rewards fly to the counter they are counted in; each payout shown once; one banner at a time; nothing over the hero.
- Always show a visible next goal.
- Money: no paid luck, no countdowns or false scarcity, kid prices, a free path to everything.
- Turn every complaint from the owner into a rule with a number that a tool checks.

## How we build
- Code: Luau in `src/` synced with Rojo (`tools/rojo.exe serve`). Settings in `src/shared/Config.luau`,
  shop and Robux items in `src/shared/Store.luau`, art asset ids in `src/shared/Art.luau`.
- Test before every publish: `bash scripts/autotest.sh` (plays the game in Studio by itself, prints errors).
- Publish: `powershell -ExecutionPolicy Bypass -File scripts/publish.ps1` (Open Cloud). Never publish from Studio.
- Art: painted images with Codex (owner's ChatGPT Pro login), 3D models as Blender Python scripts in `art/blender/`
  (see `art/README.md`). Upload with `scripts/upload_art.py`.
