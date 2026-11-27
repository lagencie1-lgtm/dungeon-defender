# Tower shots: benchmark (2026-11-27)

Gemini (video only) watched public YouTube footage of two top Roblox tower defense games and, with the same questions,
two of our level 3 clips (film sh12). Their footage and Gemini's full notes stay out of git (tools/shotbench/).
Gemini estimates by eye; treat the numbers as rough, and check claims against our own frames before acting on them.

Sources: Tower Defense Simulator, "The Best Level of EVERY Tower in TDS" (youtube.com/watch?v=0FXFQ8LJRGM);
Tower Defense X, "Cryo Mortar Showcase" (youtube.com/watch?v=DM7cGFqt7-s).

## What makes their shots read on a phone

| | Tower Defense Simulator / Tower Defense X (as Gemini saw them) | ours before round 2 (sh12) |
|---|---|---|
| Projectile size | 10-25 % of the tower's height (rockets, shells); beams about 5 % of the tower's width but extremely bright | Ballista bolt about 25 % (Gemini); arrows much less |
| Contrast | bright glowing colours (cyan, neon yellow, orange) with dark outlines or a dark body against green and brown ground | warm wood and orange against brown ground: low |
| Trail | 50-100 % of the flight for rockets and beams; smoke trails linger 0.2-0.5 s | bolt streak 12 % of the flight; fireball embers about 35 %, 0.25 s |
| Wind-up | 0.1-0.3 s, the pose held a few frames (launcher lifts, hammer raised, orb charges up to 0.5 s) | 0.12-0.2 s, the pose not held (springs still moving at release) |
| Release | muzzle puff about 2x the barrel's width, 0.1 s; recoil 10-15 % of the tower's height, settled in 0.2-0.3 s | small flash; recoil settled in 0.53 s (over our 0.4 s rule) |
| Flight | hitscan 0 s, rockets 0.3-0.4 s straight, mortars 0.8 s on a high arc | 0.25-0.35 s on a slight arc |
| Hit | explosions 1.5-3x the enemy's height; frozen enemies encased in ice; knockback rarely visible | a small spark, the damage number; no knockback |

Their five rules, in short: very high contrast; trails long enough to survive a phone's frame rate; a held wind-up
pose; impact effects scaled to the target; distinct paths for distinct roles (beams straight, mortars high).

## What we took (round 2, within 6A: effects at most a fifth of the shot distance, small and short)

- Recoil spring stiffer and damped (settles in 0.33 s); the draw/squash spring reaches its pose early in the wind-up
  and holds it.
- Ballista bolt chunkier, a brighter trail a third of the flight long; a small knockback (0.8 studs) and a 60 ms
  hit-stop on the goblin hit. Blind Codex: after preferred, scores level.
- Flame fireball larger (2.4 studs) with a dark-red rim round the bright fire, longer embers; the blast pushes
  goblins back 0.4 studs. Blind Codex: reads 5 -> 6, fireball 4 -> 6.
- Storm lightning thicker and more jagged with a white core, held 0.28 s. Blind Codex: reads 5 -> 8, lightning 5 -> 7,
  impact 4 -> 6.
- Ranger: the chunkier arrow and longer trail lost (before slightly preferred) and were put back; only the hit spark
  is now sized to the shot distance (6A rule).
- Frost: unchanged look; ties.

## Not taken (6A)

Explosions 1.5-3x the enemy's size and trails over the whole flight: 6A keeps effects small and short (at most a
fifth of the shot distance). Long lingering smoke trails: kept short.
