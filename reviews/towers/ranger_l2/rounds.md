- round 0: baseline: the model in the game now (primitives + own paint)
  IoU 83.0%  width profile off 26.7%  region colour dE 19.0  (pixel dE 52.4)  detail 18.0% vs picture 21.3% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 18 (L 45/39)  lookout 7 (L 40/41)  wall 13 (L 58/49)  footing 16 (L 63/52)
- round 1: kit build, shape loop 90.3%, own bake paint (no repaint yet)
  IoU 90.3%  width profile off 10.5%  region colour dE 17.1  (pixel dE 51.6)  detail 13.5% vs picture 21.3% (ratio 0.63)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 19 (L 45/43)  lookout 8 (L 40/36)  wall 10 (L 58/52)  footing 17 (L 63/52)
- round 2: stepped shingle tiers, archer face out of the hood; Codex repaint of our own views
  IoU 90.1%  width profile off 10.5%  region colour dE 11.0  (pixel dE 45.8)  detail 18.4% vs picture 21.3% (ratio 0.86)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 12 (L 45/49)  lookout 8 (L 40/43)  wall 6 (L 58/63)  footing 4 (L 63/63)
- round 3: colour grade: each height band matched to the picture's mean colour
  IoU 90.1%  width profile off 10.5%  region colour dE 8.1  (pixel dE 44.3)  detail 17.8% vs picture 21.3% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 6 (L 45/49)  lookout 2 (L 40/39)  wall 1 (L 58/59)  footing 3 (L 63/66)
- round 4: grade plus a light unsharp mask for crisp painted edges
  IoU 90.1%  width profile off 10.5%  region colour dE 10.1  (pixel dE 49.3)  detail 23.4% vs picture 21.3% (ratio 1.10)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 45/51)  lookout 3 (L 40/43)  wall 8 (L 58/64)  footing 8 (L 63/70)
- round 5: sharpen first, then grade (gains kept within 20% so hues stay)
  IoU 90.1%  width profile off 10.5%  region colour dE 8.8  (pixel dE 46.0)  detail 21.2% vs picture 21.3% (ratio 1.00)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 45/47)  lookout 3 (L 40/38)  wall 2 (L 58/57)  footing 1 (L 63/62)
- round 6: bigger banner and archer, lusher ivy; repaint, sharpen, grade
  IoU 88.9%  width profile off 11.3%  region colour dE 9.4  (pixel dE 49.9)  detail 22.3% vs picture 21.3% (ratio 1.05)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 45/49)  lookout 4 (L 40/39)  wall 2 (L 58/57)  footing 5 (L 63/66)
- round 7: ivy back to the picture's spread; archer half a stud forward between the posts; repaint, sharpen, grade
  IoU 89.0%  width profile off 10.0%  region colour dE 9.9  (pixel dE 49.8)  detail 21.9% vs picture 21.3% (ratio 1.03)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 45/47)  lookout 2 (L 40/39)  wall 3 (L 58/56)  footing 5 (L 63/60)
- round 8: hidden faces culled (texture room for what is seen), green banner like the picture, full-size front painting projected; sharpen, grade
  IoU 88.9%  width profile off 10.1%  region colour dE 9.0  (pixel dE 46.5)  detail 23.7% vs picture 21.3% (ratio 1.11)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 45/47)  lookout 3 (L 40/39)  wall 1 (L 58/57)  footing 4 (L 63/65)
- round 9: big archers at the rail between the roof posts (one post behind the banner), threshold slab, softer grass; repaint, sharpen, grade
  IoU 89.3%  width profile off 10.0%  region colour dE 9.5  (pixel dE 48.3)  detail 24.7% vs picture 21.3% (ratio 1.16)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 45/48)  lookout 4 (L 40/40)  wall 3 (L 58/57)  footing 5 (L 63/66)
- round 10: refit with the new archer and banner (90.2%: narrower bell roof); repaint, sharpen, grade
  IoU 89.9%  width profile off 9.0%  region colour dE 8.9  (pixel dE 44.9)  detail 23.2% vs picture 21.3% (ratio 1.09)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 45/47)  lookout 2 (L 40/40)  wall 2 (L 58/58)  footing 5 (L 63/65)
- round 11: chunky kit (fewer, bigger, thicker parts, soft bevels), roof/props in their own textures, the archer now its own model (not in this render); repaint, sharpen, grade
  IoU 88.8%  width profile off 12.0%  region colour dE 10.5  (pixel dE 46.8)  detail 22.4% vs picture 21.3% (ratio 1.05)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 45/48)  lookout 3 (L 40/39)  wall 1 (L 58/58)  footing 5 (L 63/67)
- round 12: elevation pass: Codex flat front/side/back sheet painted onto the kit model, hybrid rule (painting on door, banner, ivy, flag; calm colour + painted light on stone, shingles, timber)
  IoU 88.8%  width profile off 12.0%  region colour dE 11.6  (pixel dE 50.0)  detail 16.6% vs picture 21.3% (ratio 0.78)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 12 (L 45/49)  lookout 9 (L 40/47)  wall 4 (L 58/61)  footing 5 (L 63/63)
- round 13: height rule (coordinator 2026-11-26): lower to fit the phone screen at the run camera; fixed paint tools
  IoU 85.9%  width profile off 17.2%  region colour dE 11.1  (pixel dE 51.9)  detail 22.8% vs picture 21.3% (ratio 1.07)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 45/48)  lookout 3 (L 40/39)  wall 3 (L 58/58)  footing 5 (L 63/67)
- round 14: screen fit: roof flatter (level 3 also a slightly lower wall)
  IoU 79.8%  width profile off 27.9%  region colour dE 10.4  (pixel dE 50.4)  detail 23.6% vs picture 21.3% (ratio 1.11)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 45/48)  lookout 5 (L 40/37)  wall 3 (L 58/58)  footing 7 (L 63/69)
- round 15: screen fit: level 2 roof back up half way (levels 1 and 2 overlapped 81.3 %)
  IoU 83.4%  width profile off 21.1%  region colour dE 10.8  (pixel dE 50.7)  detail 21.5% vs picture 21.3% (ratio 1.01)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 45/49)  lookout 4 (L 40/40)  wall 3 (L 58/57)  footing 4 (L 63/67)
- round 16: levels apart: level 2 roof 10 % wider (levels 1 and 2 overlapped 80.5 %)
  IoU 82.2%  width profile off 24.2%  region colour dE 11.0  (pixel dE 51.8)  detail 22.2% vs picture 21.3% (ratio 1.04)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 9 (L 45/48)  lookout 4 (L 40/38)  wall 2 (L 58/59)  footing 7 (L 63/69)
- round 17: Codex notes: level 3 0.9 as wide, calmer smooth gold, archers larger; level 2 longer flag (levels 1-2 at 80.0 %)
  IoU 80.1%  width profile off 26.7%  region colour dE 11.6  (pixel dE 53.8)  detail 22.6% vs picture 21.3% (ratio 1.06)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 9 (L 45/48)  lookout 5 (L 40/39)  wall 3 (L 58/59)  footing 7 (L 63/69)
