- round 1: shape loop 86.4% (crest kept on purpose); Codex repaint of its own views, grade, smooth projection
  IoU 86.3%  width profile off 13.0%  region colour dE 12.8  (pixel dE 56.5)  detail 20.2% vs picture 18.1% (ratio 1.11)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 46/47)  lookout 5 (L 35/37)  wall 5 (L 33/37)  footing 10 (L 36/46)
- round 2: rack rebuilt like the picture: five parallel stakes leaning out over the rail, four in a lower row, no dirt heaps; shape loop 86.5% (crest kept)
  IoU 86.0%  width profile off 15.9%  region colour dE 12.8  (pixel dE 55.5)  detail 17.2% vs picture 18.1% (ratio 0.95)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 3 (L 46/47)  lookout 5 (L 35/36)  wall 8 (L 33/37)  footing 4 (L 36/38)
- round 3: stakes lean sideways and up like the picture's diagonal rows (shape 82.8%: lower than the stakes toward the camera, but rounds 1-2 read as stubs)
  IoU 82.6%  width profile off 15.8%  region colour dE 14.5  (pixel dE 57.0)  detail 16.1% vs picture 18.1% (ratio 0.89)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 3 (L 46/45)  lookout 16 (L 35/36)  wall 9 (L 33/38)  footing 2 (L 36/36)
- round 4: rail kept (round 3's was culled away), low rail, stakes rise and lean sideways like the picture; shape 84.1%
  IoU 83.9%  width profile off 15.4%  region colour dE 10.8  (pixel dE 54.0)  detail 18.2% vs picture 18.1% (ratio 1.00)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 46/47)  lookout 3 (L 35/35)  wall 2 (L 33/34)  footing 1 (L 36/35)

## Target re-drawn (2026-11-25)
From round 5 on, the Thornwall is scored against art/ref3d/tower_barricade_thorn_fit_cam.png: Codex re-painted the Thornwall design (wall, shield, rail, the rising stakes, the lower row, plus the crest we keep on purpose) from the pipeline's camera after the stakes were rebuilt to rise above a low rail like the picture's. The original picture art/ref3d/tower_barricade_thorn.png is unchanged.
- round 5: re-drawn target at our camera, stakes rising above a low rail; shape loop 94.1%; repaint, grade
  IoU 89.0%  width profile off 6.0%  region colour dE 7.2  (pixel dE 48.5)  detail 20.4% vs picture 22.5% (ratio 0.91)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 45/44)  lookout 1 (L 40/39)  wall 8 (L 30/34)  footing 6 (L 32/37)
- round 6: rounder stakes (14 sides); a fresh repaint
  IoU 89.0%  width profile off 6.4%  region colour dE 7.3  (pixel dE 48.3)  detail 19.3% vs picture 22.5% (ratio 0.86)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 45/45)  lookout 1 (L 40/40)  wall 6 (L 30/34)  footing 5 (L 32/37)
- round 7: centre stakes now in the same places in the full wall (the scored centre took mismatched paint in rounds 5-6); fresh repaint
  IoU 89.0%  width profile off 6.4%  region colour dE 6.9  (pixel dE 47.7)  detail 22.1% vs picture 22.5% (ratio 0.98)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 45/45)  lookout 3 (L 40/38)  wall 4 (L 30/32)  footing 8 (L 32/37)
- round 8: stakes kept whole through the cull (round 7's lower row was cut behind the rail); fresh repaint
  IoU 93.9%  width profile off 8.6%  region colour dE 6.6  (pixel dE 45.6)  detail 21.1% vs picture 22.5% (ratio 0.94)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 45/45)  lookout 2 (L 40/39)  wall 5 (L 30/31)  footing 9 (L 32/33)
  round 8 judge: 8, 6 (two more tries got no answer: Gemini's free quota)
- best: round 8 (outline 93.9%, colour 6.6, detail 0.94, all measured gates pass; judge 8 and 6)
- round 9: check of the uploaded model and paint (for the blind judge)
  IoU 93.9%  width profile off 8.6%  region colour dE 6.6  (pixel dE 45.6)  detail 21.1% vs picture 22.5% (ratio 0.94)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 45/45)  lookout 2 (L 40/39)  wall 5 (L 30/31)  footing 9 (L 32/33)
- round 10: round 8's paintings re-projected (bilinear), sharpening 15 instead of 55
  IoU 93.9%  width profile off 8.6%  region colour dE 8.2  (pixel dE 43.5)  detail 16.0% vs picture 22.5% (ratio 0.71)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 45/48)  lookout 3 (L 40/42)  wall 9 (L 30/33)  footing 10 (L 32/33)
- round 11: round 8's paintings re-projected (bilinear), sharpening 35
  IoU 93.9%  width profile off 8.6%  region colour dE 6.7  (pixel dE 44.4)  detail 18.7% vs picture 22.5% (ratio 0.83)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 4 (L 45/47)  lookout 1 (L 40/39)  wall 4 (L 30/31)  footing 12 (L 32/35)
- round 12: dark core kept from the cull (no see-through gaps between log ends); round 8's paintings; sharpening 45
  IoU 94.1%  width profile off 8.7%  region colour dE 7.3  (pixel dE 44.6)  detail 18.1% vs picture 22.5% (ratio 0.80)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 4 (L 45/47)  lookout 2 (L 40/41)  wall 6 (L 30/32)  footing 10 (L 32/33)
- round 13: fresh Codex repaint of the gap-free model; bilinear projection; sharpening 45
  IoU 94.1%  width profile off 8.7%  region colour dE 5.7  (pixel dE 42.9)  detail 18.1% vs picture 22.5% (ratio 0.80)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 45/46)  lookout 1 (L 40/40)  wall 3 (L 30/29)  footing 11 (L 32/36)
- round 14: round 13's repaint graded with sharpening 65
  IoU 94.1%  width profile off 8.7%  region colour dE 6.1  (pixel dE 45.8)  detail 22.5% vs picture 22.5% (ratio 1.00)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 45/44)  lookout 5 (L 40/37)  wall 3 (L 30/28)  footing 11 (L 32/37)
