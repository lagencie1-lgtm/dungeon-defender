# Heroes Tower Defense (ours): pets

Source: cycle5-sheet1.png, cycle5-sheet2.png (Gemini model gemini-3.5-flash)

### Part A: Pet Evaluations

1. **Green Slime:** Good glossy sheen, but shape is a generic, featureless blob.
2. **Sprout:** Cute facial layout, but top leaf stem looks awkwardly attached.
3. **Rock Puppy:** Solid stone texture, but body silhouette merges into an unreadable lump.
4. **Leaf Cat:** Detailed fur shading, but leaf collar clips lazily into body mesh.
5. **Bee Bug:** Bright glowing accents, but spindly legs look disconnected from body.
6. **Fox:** Warm palette and cute face, but oversized tail masks rear silhouette.
7. **Ice Owl:** Distinct ice crystals, but wing geometry blends muddily into torso.
8. **Rock Golem:** Clear construct theme, but head lumps lack a defined focal point.
9. **Baby Dragon:** Cute body proportions, but wings clutter side-view reading.
10. **Rainbow Unicorn:** Vibrant hair colors, but torso model looks like flat plastic.
11. **Phoenix:** Eye-catching fire motif, but feather geometry creates messy visual noise.
12. **Royal Dragon:** Strong star accents, but surface detail is too busy for small renders.

---

### Part B: Category Ratings

* **Silhouette: 4/10** — Poses overlap heavily, making icons unreadable as black shapes.
* **Face appeal: 6/10** — Large eyes drive decent appeal, though expressions lack range.
* **Form quality: 4/10** — Soft, lumpy meshes give an auto-generated, unpolished look.
* **Surface: 5/10** — Painted details look fine, but lighting gradients feel muddy.
* **Rarity read: 6/10** — Radiance and wings clearly separate higher tiers from commons.
* **Set cohesion: 5/10** — Render style ties them together, though material gloss varies.
* **Motion and life: n/a** — Still renders only.

---

### Part C: Top 8 Priority Fixes

1. **Soft, lumpy geometry** $\rightarrow$ Looks like cheap, unedited generative models $\rightarrow$ Retopologize meshes to sharpen edges and reduce vertex noise by 30%.
2. **Cluttered silhouettes** $\rightarrow$ Tails and limbs blur together at thumbnail size $\rightarrow$ Flare limbs outward by 15 degrees and raise tails 20 units above torso.
3. **Muddy surface gradients** $\rightarrow$ Pets look dull and lack Roblox pop $\rightarrow$ Increase color saturation by 15% and boost specular highlights by 25%.
4. **Clipping mesh attachments** $\rightarrow$ Leaves, ice, and collar pieces cut through bodies lazy-style $\rightarrow$ Offset attachment points by 3mm or weld geometry directly.
5. **Repetitive eye styles** $\rightarrow$ Faces feel manufactured rather than handcrafted $\rightarrow$ Create 4 distinct eye geometry templates across the set.
6. **Noisy feather and fur detail** $\rightarrow$ High-frequency detail turns into visual mush on mobile screens $\rightarrow$ Reduce small fur/feather polygons by 40% into larger, stylized clumps.
7. **Inconsistent material roughness** $\rightarrow$ Slime is ultra-glossy while unicorn looks like dry matte plastic $\rightarrow$ Standardize roughness maps within a strict 0.2–0.4 range.
8. **Boring common pets** $\rightarrow$ Base pets lack hook for new players $\rightarrow$ Add 1–2 ambient particle emission nodes to common tier models.
