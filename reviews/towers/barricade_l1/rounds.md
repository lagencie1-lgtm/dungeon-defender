- round 1: shape loop (outline 84.6%): post pairs, 3 logs lifted 0.7 off the road like the picture; repaint + grade
  IoU 84.6%  width profile off 17.6%  region colour dE 10.6  (pixel dE 48.9)  detail 17.1% vs picture 20.0% (ratio 0.85)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/50)  lookout 5 (L 38/38)  wall 4 (L 37/40)  footing 6 (L 32/35)
- round 2: log ends reach further past the posts (0.9, like the picture's right end); grade keeps colours (channel spread 0.05: no green rope, no pink ends)
  IoU 85.7%  width profile off 18.5%  region colour dE 11.7  (pixel dE 48.9)  detail 16.6% vs picture 20.0% (ratio 0.83)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/51)  lookout 8 (L 38/39)  wall 5 (L 37/40)  footing 12 (L 32/38)
- round 3: rope warmer tan and rounder (8-sided strands, 20 steps a turn), 16-sided posts
  IoU 85.5%  width profile off 19.1%  region colour dE 12.1  (pixel dE 48.8)  detail 16.9% vs picture 20.0% (ratio 0.84)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 49/50)  lookout 10 (L 38/40)  wall 7 (L 37/42)  footing 12 (L 32/37)
- round 4: warmer, darker pencil tips (pale tips were the brightest thing on the phone), stronger round shading on the logs
  IoU 85.5%  width profile off 19.1%  region colour dE 11.7  (pixel dE 47.0)  detail 15.8% vs picture 20.0% (ratio 0.79)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 2 (L 49/50)  lookout 10 (L 38/41)  wall 6 (L 37/42)  footing 11 (L 32/38)
- round 5: full-strength grade (range 0.7-1.3): the model's middle was 4-5 lightness steps brighter than the picture
  IoU 85.5%  width profile off 19.1%  region colour dE 12.4  (pixel dE 47.6)  detail 15.8% vs picture 20.0% (ratio 0.79)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 1 (L 49/49)  lookout 10 (L 38/40)  wall 5 (L 37/40)  footing 13 (L 32/39)
- round 6: softer log shading again (round 4's harder contrast read as noise), chunkier rope (0.17)
  IoU 83.7%  width profile off 19.8%  region colour dE 11.7  (pixel dE 44.4)  detail 7.1% vs picture 20.0% (ratio 0.35)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 49/55)  lookout 3 (L 38/39)  wall 6 (L 37/41)  footing 9 (L 32/40)
- round 7: back to the 105 view (the mirrored 75 fit only reached 77%); rope back to 0.14 thick (0.17 read lumpy), soft log shading, warm tips
  IoU 85.1%  width profile off 18.6%  region colour dE 11.9  (pixel dE 45.7)  detail 7.8% vs picture 20.0% (ratio 0.39)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 49/56)  lookout 4 (L 38/42)  wall 8 (L 37/44)  footing 12 (L 32/43)
- round 8: same model, a fresh Codex repaint (rounds 6-7 came back blurry: detail 0.35-0.39)
  IoU 85.1%  width profile off 18.6%  region colour dE 11.9  (pixel dE 45.7)  detail 7.8% vs picture 20.0% (ratio 0.39)  not yet  [pass: IoU >= 90%, region dE <= 10.0, detail ratio 0.85-1.3]
  bands (dE, lightness picture/model): roof 8 (L 49/56)  lookout 4 (L 38/42)  wall 8 (L 37/44)  footing 12 (L 32/43)
- note: rounds 6-8 had NO repaint. Codex hit its usage limit ("try again at Nov 28th, 2026 9:55 PM") from round 6 on and tower_paint.py stopped before projecting, so those rounds score the plain kit bake (hence detail 0.35-0.39). The best real rounds are 1-4 (outline 84.6-85.7%, colour 10.6-12.1, judge 6); their paints were overwritten. The committed tower_barricade_l1_paint.png is still the uploaded round 7 art from before the pipeline.
