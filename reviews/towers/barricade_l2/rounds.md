- round 1: shape loop (outline 91.6%), single posts, 5 logs; kit bake only, no repaint yet
  IoU 91.4%  width profile off 11.2%  region colour dE 16.6  (pixel dE 54.7)  detail 10.4% vs picture 17.5% (ratio 0.59)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 44/50)  lookout 13 (L 35/47)  wall 14 (L 33/45)  footing 20 (L 31/50)
- round 2: shield raised to the picture's height, lower bands at 42% of the post; kit bake only
  IoU 91.4%  width profile off 11.2%  region colour dE 15.9  (pixel dE 54.8)  detail 10.8% vs picture 17.5% (ratio 0.61)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 9 (L 44/50)  lookout 13 (L 35/46)  wall 13 (L 33/45)  footing 21 (L 31/50)
- round 3: Codex repaint of its own four views + front, projected
  IoU 91.4%  width profile off 11.2%  region colour dE 13.8  (pixel dE 50.3)  detail 15.0% vs picture 17.5% (ratio 0.85)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 44/47)  lookout 10 (L 35/41)  wall 14 (L 33/40)  footing 11 (L 31/36)
- round 4: colour grade by height band + sharpen
  IoU 91.4%  width profile off 11.2%  region colour dE 8.6  (pixel dE 46.7)  detail 17.9% vs picture 17.5% (ratio 1.02)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 3 (L 44/45)  lookout 3 (L 35/34)  wall 3 (L 33/33)  footing 7 (L 31/33)
- round 5: logs pressed tighter (step 1.56), shorter log ends, smooth 24-sided bands; refit, repaint, grade
  IoU 91.9%  width profile off 11.5%  region colour dE 10.0  (pixel dE 47.4)  detail 17.6% vs picture 17.5% (ratio 1.00)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 3 (L 44/46)  lookout 3 (L 35/34)  wall 4 (L 32/33)  footing 9 (L 30/33)
- round 6: log ends no longer thinner (no light between them), dark core to the log ends, shorter overhang 0.3, rounder studs
  IoU 91.8%  width profile off 11.8%  region colour dE 10.0  (pixel dE 49.7)  detail 16.9% vs picture 17.5% (ratio 0.97)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 44/45)  lookout 3 (L 35/35)  wall 3 (L 33/34)  footing 7 (L 31/34)
- round 7: sawn end caps no wider than the log (no pale crescents round the far ends), log ends reach further past the posts (0.6)
  IoU 90.7%  width profile off 13.4%  region colour dE 9.8  (pixel dE 50.7)  detail 18.8% vs picture 17.5% (ratio 1.07)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 44/45)  lookout 4 (L 35/34)  wall 3 (L 33/33)  footing 8 (L 31/34)
- round 8: logs stacked tighter (step 1.5); back to azimuth 105 (a refit at the mirrored 75 only reached 87% outline)
  IoU 89.3%  width profile off 14.5%  region colour dE 9.2  (pixel dE 48.6)  detail 17.3% vs picture 17.5% (ratio 0.99)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 44/44)  lookout 3 (L 35/35)  wall 2 (L 33/33)  footing 6 (L 31/34)
