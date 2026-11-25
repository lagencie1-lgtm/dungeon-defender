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
