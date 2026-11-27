# Shared problems across the towers (2026-11-27)

Codex, as an outside art director, saw all 15 phone views next to their paintings (one grid) and named the problems
shared across most towers. Each one is then measured on the phone pictures of film r2c (the game as committed) with
`scripts/phone_measure.py` (the painting scaled so the tower is as tall in pixels as on the phone).

## What Codex named

1. **Tall, narrow silhouettes lose the concepts' chunky proportions** (All five tower families, especially Ranger, Ballista, Flame Cannon and Frost Crystal). The models repeatedly rise from a narrow footprint into thin vertical structures. The paintings spread their roofs, weapons and crystals across a broad, squat mass, making each tower type readable at a glance. Suggested fix: Apply a shared proportion pass: widen the main tower mass and its defining feature, reduce unnecessary pedestal height, and keep the widest feature clearly separated from the supporting structure.

2. **Small details merge into noisy, low-contrast shapes** (All five tower families, particularly their higher levels). Rails, braces, coils, trim and supports crowd together in the phone crops. Their similar brightness and color make the focal shapes harder to distinguish, while the paintings use larger, cleaner color blocks and stronger separation between foreground and interior. Suggested fix: Create a shared phone-scale detail budget: remove or merge small repeating parts, enlarge the defining shapes, darken recessed areas, and add a restrained light edge to major forms.

3. **Pale, oversized footings weaken the connection to the tower** (Most towers across all five families). A bright white ring surrounds many models and competes with the tower above it. The concepts use broader, lower stone footings with darker seams and warmer earth contact, so the structure reads as planted rather than perched. Suggested fix: Standardize a low, wide footing with warm stone colors, visible darker joints and a contact shadow. Reduce the brightness and thickness of the current pale rim across the tower set.

## What the numbers say

| tower level | sharpness phone/painting | edge step (L) | saturation phone/painting | value range phone/painting | width/height phone/painting | footing L step phone / painting |
|---|---|---|---|---|---|---|
| ranger 1 | 1.60 | 14.1 | 0.58/0.61 = 0.95 | 1.47 | 0.64/0.67 = 0.96 | +15.3 / +23.7 |
| ranger 2 | 1.37 | 12.1 | 0.64/0.57 = 1.13 | 1.09 | 0.63/0.50 = 1.26 | +15.5 / +13.4 |
| ranger 3 | 1.26 | 19.1 | 0.63/0.56 = 1.13 | 1.14 | 0.63/0.55 = 1.15 | +7.5 / +7.3 |
| ballista 1 | 1.36 | 17.1 | 0.60/0.53 = 1.13 | 1.14 | 0.77/0.85 = 0.91 | -2.1 / +21.9 |
| ballista 2 | 1.38 | 15.0 | 0.60/0.52 = 1.14 | 0.99 | 0.78/0.88 = 0.88 | +8.0 / +24.0 |
| ballista 3 | 1.28 | 19.3 | 0.51/0.51 = 0.99 | 1.15 | 0.90/0.95 = 0.95 | +11.8 / +14.7 |
| storm 1 | 1.17 | 30.0 | 0.34/0.41 = 0.83 | 1.24 | 1.00/1.05 = 0.96 | -13.8 / +0.7 |
| storm 2 | 1.22 | 17.4 | 0.55/0.43 = 1.29 | 1.38 | 0.57/0.62 = 0.92 | +21.9 / +9.9 |
| storm 3 | 1.38 | 16.9 | 0.59/0.47 = 1.26 | 1.20 | 0.51/0.58 = 0.88 | +6.2 / +4.1 |
| flame 1 | 1.52 | 16.8 | 0.51/0.51 = 1.00 | 1.21 | 0.91/1.00 = 0.91 | -1.2 / +20.0 |
| flame 2 | 1.16 | 11.6 | 0.67/0.63 = 1.07 | 1.27 | 0.95/0.89 = 1.07 | +6.3 / +17.7 |
| flame 3 | 1.05 | 15.1 | 0.70/0.65 = 1.07 | 1.25 | 0.77/0.81 = 0.95 | +18.3 / +13.9 |
| frost 1 | 1.12 | 25.0 | 0.40/0.43 = 0.94 | 1.29 | 0.69/0.77 = 0.90 | +1.0 / +3.4 |
| frost 2 | 1.07 | 26.5 | 0.40/0.44 = 0.91 | 1.18 | 0.65/0.74 = 0.88 | -2.2 / -0.5 |
| frost 3 | 1.00 | 27.7 | 0.37/0.42 = 0.87 | 1.21 | 0.58/0.67 = 0.88 | +1.4 / -4.1 |
| **mean** | 1.26 | 18.9 | 1.05 | 1.21 | 0.96 | +6.3 / +11.3 |

- Tall and narrow: the phone silhouettes are 0.96 of the paintings' width/height on average (worst 0.88): a small
  difference, not the main cause.
- Pale footing: the footing is +6.3 L lighter than the tower on the phone, +11.3 in the paintings: not paler than
  painted.
- Busy small detail: the phone shows 1.26 times the paintings' fine contrast (gradient inside the tower) and 1.21
  times their lightness spread, on 14 of 15 levels: this one holds.

## Tried: an edge-preserving simplify pass on every level's painted texture

One bilateral pass over the body, roof and props sheets of all 15 levels (scripts/paint_simplify.py; gold, silver and
weapon sheets left alone). Film r3b, blind Codex before/after per level: all 15 tied (same score both sides). The
measured fine contrast did not move either:

| **mean** | 1.26 | 19.0 | 1.04 | 1.21 | 0.96 | +6.3 / +11.3 |

So the busy look on the phone does not come from the painted grain: it comes from the geometry (many small parts,
rails, bands, studs) and the game's lighting at that size. The pass was not kept (no level won). A next try must cut
small parts or merge them into bigger shapes, not soften the texture.
