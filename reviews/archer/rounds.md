- round 1: first build: pet kit, hood as an open shell, face as crisp paint, separate arms+bow
  IoU 69.3%  width profile off 15.9%  region colour dE 20.4  (pixel dE 62.0)  detail 8.1% vs picture 13.5% (ratio 0.60)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 2: bigger fringe and side locks, thinner lining on the hood edge, taller hood and longer tip, flared tunic, wider stance, bigger boots, hands, quiver and bow
  IoU 68.9%  width profile off 17.3%  region colour dE 20.3  (pixel dE 61.8)  detail 8.7% vs picture 13.5% (ratio 0.64)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 3: bigger head set forward in the hood, wider hood opening, the lining rope exactly on the cut edge, face turned less
  IoU 72.1%  width profile off 14.9%  region colour dE 19.3  (pixel dE 61.4)  detail 8.2% vs picture 13.5% (ratio 0.61)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 4: smaller determined eyes and brows, fringe of pointed strands, hood peak rising up and back, more triangles for the skin
  IoU 64.3%  width profile off 22.5%  region colour dE 20.5  (pixel dE 65.8)  detail 8.7% vs picture 13.5% (ratio 0.64)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 5: hood peak falls back; Codex repaint of both parts (face kept crisp), fitted to the outlines
  IoU 70.4%  width profile off 16.5%  region colour dE 18.6  (pixel dE 63.5)  detail 11.1% vs picture 13.5% (ratio 0.82)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 6: face with a chin, hair as real strands, wider build, longer legs and wider stance, broader shoulders (own bake, no repaint yet)
  IoU 71.7%  width profile off 15.9%  region colour dE 18.7  (pixel dE 61.1)  detail 8.4% vs picture 13.5% (ratio 0.62)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 7: Codex repaint of round 6 (face kept crisp)
  IoU 71.7%  width profile off 15.9%  region colour dE 18.7  (pixel dE 61.1)  detail 8.4% vs picture 13.5% (ratio 0.62)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 8: quiver over his right shoulder; body repainted by Codex; arms+bow: the painter refused (violence filter), so the round 5 arms painting is fitted and projected
  IoU 71.7%  width profile off 15.9%  region colour dE 16.5  (pixel dE 62.7)  detail 12.1% vs picture 13.5% (ratio 0.89)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 9: eyes like the picture (dark iris, one small shine, no blush), longer legs; previous paintings fitted and projected
  IoU 69.6%  width profile off 18.3%  region colour dE 17.9  (pixel dE 68.1)  detail 14.2% vs picture 13.5% (ratio 1.05)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
- round 10: eyes with whites, brown iris, one small shine; new repaint of the new shape (body; arms if the painter accepts)
  IoU 69.6%  width profile off 18.3%  region colour dE 19.6  (pixel dE 64.9)  detail 6.6% vs picture 13.5% (ratio 0.49)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]

- 2026-11-23 21:36  painterly (pets' detail measure) 69%  rich 90%  Baby Dragon 71%  band +-20: PASS  tools\archer3\ranger_archer.fbx  before this pass (lofted v1, archer3)
- 2026-11-23 21:36  painterly (pets' detail measure) 87%  rich 100%  Baby Dragon 71%  band +-20: PASS  tools\archer5\ranger_archer.fbx  geometry pass, plain bake (archer5)
- 2026-11-23 21:37  painterly (pets' detail measure) 87%  rich 100%  Baby Dragon 71%  band +-20: PASS  |  stroke texture 12.42 (painting 14.05, Baby Dragon 9.74)  tools\archer5\ranger_archer.fbx  geometry pass, plain bake (archer5)
- 2026-11-23 22:25  painterly (pets' detail measure) 103%  rich 102%  Baby Dragon 71%  band +-20: FAIL  |  stroke texture 13.71 (painting 14.05, Baby Dragon 9.74)  tools\archer6\ranger_archer.fbx  painterly pass (pets' workflow, two runs), archer6
- 2026-11-24 00:25  painterly (pets' detail measure) 105%  rich 101%  Baby Dragon 71% (logged)  |  stroke texture 14.11 (painting 14.05, Baby Dragon 9.74; band 9.7-15.5): PASS  tools\archer8\ranger_archer.fbx  round A: teardrop hood, softened hood paint (archer8)
- 2026-11-24 00:47  painterly (pets' detail measure) 105%  rich 98%  Baby Dragon 71% (logged)  |  stroke texture 14.26 (painting 14.05, Baby Dragon 9.74; band 9.7-15.5): PASS  tools\archer8\ranger_archer.fbx  round A, repainted after the chin fix (archer8)