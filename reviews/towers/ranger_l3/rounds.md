- round 1: kit build, shape loop 91%, own bake paint (no repaint yet)
  IoU 90.9%  width profile off 11.6%  region colour dE 17.3  (pixel dE 59.4)  detail 15.3% vs picture 24.6% (ratio 0.62)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 14 (L 49/44)  lookout 9 (L 54/46)  wall 15 (L 61/51)  footing 20 (L 64/50)
- round 2: Codex repaint of our own 4 views, projected back
  IoU 90.9%  width profile off 11.6%  region colour dE 11.7  (pixel dE 55.0)  detail 20.6% vs picture 24.6% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 10 (L 49/50)  lookout 9 (L 54/55)  wall 4 (L 61/62)  footing 10 (L 64/57)
- round 3: bigger banners and archers, deeper swags, more grass; new repaint
  IoU 89.3%  width profile off 12.3%  region colour dE 11.8  (pixel dE 54.7)  detail 20.7% vs picture 24.6% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 11 (L 49/48)  lookout 8 (L 54/55)  wall 3 (L 61/61)  footing 11 (L 64/57)
- round 4: banner emblems large enough to read; new repaint
  IoU 89.3%  width profile off 12.3%  region colour dE 10.7  (pixel dE 55.0)  detail 20.5% vs picture 24.6% (ratio 0.83)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 49/50)  lookout 6 (L 54/54)  wall 4 (L 61/60)  footing 12 (L 64/57)
- round 5: footing stones cover the top to the wall; archers bigger and at the rail; new repaint
  IoU 89.3%  width profile off 12.2%  region colour dE 11.2  (pixel dE 53.9)  detail 20.6% vs picture 24.6% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 13 (L 49/48)  lookout 9 (L 54/53)  wall 3 (L 61/60)  footing 9 (L 64/58)
- round 6: archers under the eave so both heads show; no chamfer on stones/shingles, 14k triangles so small parts survive; new repaint
  IoU 89.4%  width profile off 12.2%  region colour dE 12.2  (pixel dE 55.0)  detail 19.5% vs picture 24.6% (ratio 0.79)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 13 (L 49/49)  lookout 8 (L 54/52)  wall 5 (L 61/58)  footing 13 (L 64/56)
- round 7: projection: surfaces seen only at a low angle (footing and lookout tops) now take the repaint too
  IoU 89.4%  width profile off 12.2%  region colour dE 10.9  (pixel dE 53.3)  detail 20.6% vs picture 24.6% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 13 (L 49/49)  lookout 9 (L 54/52)  wall 4 (L 61/61)  footing 7 (L 64/62)
- round 8: bigger crown and gem like the picture; redder shingles under the paint; new repaint
  IoU 87.2%  width profile off 14.3%  region colour dE 10.6  (pixel dE 53.6)  detail 20.2% vs picture 24.6% (ratio 0.82)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/50)  lookout 9 (L 54/53)  wall 3 (L 61/64)  footing 6 (L 64/62)
- round 9: squat gem and crown sized off the picture; new repaint
  IoU 89.3%  width profile off 12.6%  region colour dE 10.1  (pixel dE 54.4)  detail 20.5% vs picture 24.6% (ratio 0.83)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 10 (L 49/51)  lookout 8 (L 54/55)  wall 4 (L 61/64)  footing 6 (L 64/63)
- round 10: shape loop 91%, hidden faces culled, softer grass, full-size front painting; sharpen, grade
  IoU 90.8%  width profile off 11.5%  region colour dE 7.8  (pixel dE 54.7)  detail 25.2% vs picture 24.6% (ratio 1.02)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 4 (L 49/49)  lookout 5 (L 54/53)  wall 3 (L 61/60)  footing 3 (L 64/63)
- round 11: big archers at the rail between the roof posts (one post behind the banner), threshold slab, softer grass; repaint, sharpen, grade
  IoU 91.0%  width profile off 12.2%  region colour dE 7.6  (pixel dE 52.8)  detail 25.4% vs picture 24.6% (ratio 1.03)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 3 (L 49/49)  lookout 5 (L 54/52)  wall 4 (L 61/61)  footing 3 (L 64/62)
- round 12: chunky kit (fewer, bigger, thicker parts, soft bevels), roof/props in their own textures, the archer now its own model (not in this render); repaint, sharpen, grade
  IoU 90.8%  width profile off 14.5%  region colour dE 9.1  (pixel dE 55.5)  detail 24.2% vs picture 24.6% (ratio 0.98)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/48)  lookout 4 (L 54/52)  wall 3 (L 61/62)  footing 2 (L 64/66)
- round 13: height rule (coordinator 2026-11-26): lower to fit the phone screen at the run camera; fixed paint tools
  IoU 86.6%  width profile off 17.6%  region colour dE 9.6  (pixel dE 57.1)  detail 24.0% vs picture 24.6% (ratio 0.98)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/47)  lookout 7 (L 54/53)  wall 1 (L 61/61)  footing 5 (L 64/68)
- round 14: screen fit: roof flatter (level 3 also a slightly lower wall)
  IoU 84.0%  width profile off 21.6%  region colour dE 11.0  (pixel dE 59.5)  detail 23.5% vs picture 24.6% (ratio 0.96)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 6 (L 49/48)  lookout 12 (L 54/55)  wall 1 (L 61/62)  footing 7 (L 64/70)
- round 17: Codex notes: level 3 0.9 as wide, calmer smooth gold, archers larger; level 2 longer flag (levels 1-2 at 80.0 %)
  IoU 88.7%  width profile off 15.3%  region colour dE 10.1  (pixel dE 59.5)  detail 24.4% vs picture 24.6% (ratio 0.99)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/46)  lookout 8 (L 54/53)  wall 1 (L 61/61)  footing 7 (L 64/71)
- round 18: levels apart (75 % target): level 2 1.12 wider; level 3 wide overhanging roof and broader base, as painted
  IoU 80.7%  width profile off 28.4%  region colour dE 10.6  (pixel dE 59.7)  detail 23.0% vs picture 24.6% (ratio 0.94)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/47)  lookout 6 (L 54/52)  wall 1 (L 61/62)  footing 8 (L 64/71)
- round 19: archers read: walls lower, roof higher and slimmer so the hooded archers show under the roof edge
  IoU 79.8%  width profile off 26.6%  region colour dE 10.9  (pixel dE 57.7)  detail 24.7% vs picture 24.6% (ratio 1.00)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/51)  lookout 14 (L 54/47)  wall 1 (L 61/61)  footing 5 (L 64/69)
