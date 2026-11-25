- round 1: shape 77.1% (pouring roots, tips clear); Codex repaint of its own views, grade, smooth projection
  IoU 76.9%  width profile off 32.9%  region colour dE 9.4  (pixel dE 58.6)  detail 29.9% vs picture 25.7% (ratio 1.16)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 4 (L 50/52)  lookout 3 (L 37/37)  wall 5 (L 39/41)  footing 4 (L 51/55)

## Target re-drawn (2026-11-25)
From round 2 on, the Rootwall is scored against art/ref3d/tower_barricade_root_fit_cam.png: Codex re-painted the Rootwall design from the pipeline's camera. The original picture art/ref3d/tower_barricade_root.png is unchanged.
- round 2: re-drawn target at our camera, roots beside the shield; shape loop 91.1%; repaint, grade
  IoU 90.9%  width profile off 15.1%  region colour dE 6.7  (pixel dE 48.5)  detail 28.9% vs picture 23.4% (ratio 1.23)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 49/50)  lookout 3 (L 37/35)  wall 2 (L 36/38)  footing 6 (L 50/55)
- best: round 2 (outline 90.9%, colour 6.7, detail 1.23, all measured gates pass; blind judge not available: Gemini's free quota)
- round 3: pouring roots along the posts' inner edge, the whole shield shows like the picture; refit, repaint
  IoU 90.1%  width profile off 16.6%  region colour dE 7.9  (pixel dE 49.9)  detail 27.9% vs picture 23.4% (ratio 1.19)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/48)  lookout 3 (L 37/35)  wall 5 (L 36/40)  footing 8 (L 50/57)
- round 4: round 3's paintings re-projected: grade sharpening 70%
  IoU 90.1%  width profile off 16.6%  region colour dE 7.9  (pixel dE 49.1)  detail 26.9% vs picture 23.4% (ratio 1.15)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/49)  lookout 2 (L 37/36)  wall 6 (L 36/41)  footing 8 (L 50/57)
- round 5: round 3's paintings re-projected: grade sharpening 110%
  IoU 90.1%  width profile off 16.6%  region colour dE 7.3  (pixel dE 50.2)  detail 28.7% vs picture 23.4% (ratio 1.23)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/48)  lookout 3 (L 37/35)  wall 3 (L 36/39)  footing 5 (L 50/54)
- round 6: round 3's paintings re-projected: colour spread 0.1 in the grade
  IoU 90.1%  width profile off 16.6%  region colour dE 7.3  (pixel dE 49.2)  detail 27.6% vs picture 23.4% (ratio 1.18)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 49/48)  lookout 3 (L 37/35)  wall 3 (L 36/39)  footing 6 (L 50/54)
- round 7: a fresh Codex repaint of the same model (whole shield), grade spread 0.1
  IoU 90.1%  width profile off 16.6%  region colour dE 8.3  (pixel dE 49.4)  detail 28.0% vs picture 23.4% (ratio 1.20)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/48)  lookout 4 (L 37/34)  wall 5 (L 36/41)  footing 9 (L 50/57)
- round 8: round 7 with the pencil tips toned to a darker, warmer wood (like Level 1)
  IoU 90.1%  width profile off 16.6%  region colour dE 8.7  (pixel dE 50.1)  detail 27.9% vs picture 23.4% (ratio 1.19)  PASS  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 3 (L 49/47)  lookout 4 (L 37/34)  wall 5 (L 36/40)  footing 9 (L 50/57)
- best: round 8 (outline 90.1%, all measured gates pass; blind judge not available yet: Gemini's free quota)
- round 9: roots wind from below the upper band, tall clear pencil tips (rule tip >= 1.2), fresh repaint, tips toned, leaves graded to a deeper green
  IoU 89.3%  width profile off 16.0%  region colour dE 10.6  (pixel dE 53.4)  detail 27.1% vs picture 23.4% (ratio 1.16)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/45)  lookout 4 (L 37/34)  wall 2 (L 36/38)  footing 6 (L 50/55)
- round 10: round 9's paintings re-projected; tips left as painted (pale wood like the picture); only the leafy tufts graded to a deeper green
  IoU 89.3%  width profile off 16.0%  region colour dE 9.8  (pixel dE 53.0)  detail 27.5% vs picture 23.4% (ratio 1.17)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 49/47)  lookout 4 (L 37/34)  wall 2 (L 36/38)  footing 6 (L 50/55)
- round 11: refit with post_up 0.525 (tips still 1.27 tall); paintings reused; leafy tufts graded deeper green
  IoU 89.6%  width profile off 15.5%  region colour dE 9.6  (pixel dE 52.7)  detail 27.5% vs picture 23.4% (ratio 1.17)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 49/47)  lookout 4 (L 37/34)  wall 2 (L 36/38)  footing 7 (L 50/55)
- round 12: fresh Codex paint of the refit (taller, freer tips); leafy tufts graded deeper green
  IoU 89.6%  width profile off 15.5%  region colour dE 9.3  (pixel dE 53.4)  detail 27.8% vs picture 23.4% (ratio 1.19)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 7 (L 49/46)  lookout 4 (L 37/34)  wall 2 (L 36/37)  footing 5 (L 50/54)
- round 13: round 12's paintings; smaller leaf balls so the right post tip keeps its wood
  IoU 89.6%  width profile off 15.5%  region colour dE 8.9  (pixel dE 53.2)  detail 27.9% vs picture 23.4% (ratio 1.19)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 5 (L 49/47)  lookout 4 (L 37/34)  wall 2 (L 36/37)  footing 5 (L 50/54)
