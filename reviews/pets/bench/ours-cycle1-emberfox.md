# Heroes Tower Defense (ours): pets

Source: _cycle_emberfox.png (Gemini model gemini-3.5-flash)

### Part A: Pet Evaluation

* **Flame Fox**: The warm 2D concept artwork is appealing, but the 3D translation suffers from rigid topology, flat texturing, and unrefined geometry.

---

### Part B: Roblox Pet Ratings (1–10 Scale)

*Note: Scores are calibrated against Roblox standard tiers.*

* **Silhouette**: **4/10** — Basic fox outline is readable, but the tail flame loses definition at smaller sizes.
* **Face appeal**: **4/10** — Large pupil concept is cute, but flat 3D projection lacks depth and expression.
* **Form quality**: **3/10** — Visible faceting, blocky fur spikes, and unpolished mesh transitions degrade form.
* **Surface**: **4/10** — Texture maps are flat with weak gradient transitions and minimal painted highlight detail.
* **Rarity read**: **4/10** — Tail element adds interest, but lacks emission effects or premium sheen.
* **Set cohesion**: **5/10** — Fits general chibi platform styles, though geometry execution falls behind standard benchmarks.
* **Motion and life**: **N/A** — Still renders evaluated.

---

### Part C: 8 Key Quality Upgrades

1. **Faceted Body Mesh** -> Jagged, un-smoothed polygons give a placeholder look -> Apply smooth shading across all body groups and smooth edge angles above 35 degrees.
2. **Static Flame Tail** -> Tail cap appears as a rigid geometry piece rather than fire -> Replace tip with a 2-layer semi-transparent flame mesh and add dynamic particle emitters.
3. **Flat Decal Eyes** -> Eyes look like flat stickers painted onto the head -> Recess eye sockets by 0.15 studs and add 3D spherical lens geometry with high specularity.
4. **Blocky Chest Fur** -> Fur tufts clip awkwardly into the main torso mesh -> Re-topology chest fur into 3 curved overlapping shell layers smoothed against the body mesh.
5. **Muddy Paw Gradients** -> Leg color transitions look blurry and unpainted -> Clean UV maps to feature sharp 2-stage gradient transitions with 20% higher color contrast.
6. **Proportion Misalignment** -> Head ratio is noticeably smaller than the reference concept -> Scale head size up by 15% and increase eye size by 10% for stronger appeal.
7. **Shallow Ear Cavities** -> Ears look flat from side and rear angles -> Extrude inner ear geometry inward by 0.3 studs and add rim highlights.
8. **Dull Material Finish** -> Lack of visual pop in engine lighting -> Assign a custom Roughness map (0.2 for eyes, 0.8 for fur) and embed an inner light source (brightness 1.5) in the tail.
