# Grow a Garden: pets

Source: https://www.youtube.com/watch?v=agiSjweZ-2k (Gemini model gemini-3.5-flash)

### Part A: Pet Construction Breakdown

1. **Body Recipe:** Built from 6–15 primitive blocky shapes [01:19, 06:29]. Head-to-body ratio is roughly 1:1 [03:57, 07:52]. Features square cubic limbs or no legs [07:01, 09:05]. Proportions follow a strict voxel/block aesthetic [00:48].
2. **Face:** Eyes are flat-painted square textures [03:57, 07:52] occupying ~25% of head width. Minimalist pupils with no complex highlights. Mouths and snouts are simple extrusions or painted overlays [01:21, 07:54]. Blush/facial expressions are not visible.
3. **Surface:** Flat solid colors with 2–4 hues per model [01:19, 02:35]. No gradients or detailed surface shading. Edges are sharp and faceted. Special variants feature simple emissive textures or surrounding particle glow [00:01, 12:03].
4. **Rarity Differentiation:** Top-tier/Divine pets feature distinct particle auras, glowing eye textures, or bright emissive effects [00:01, 00:29, 12:03], whereas Common pets rely on plain, unadorned block geometry and muted recolors [01:34, 03:54].
5. **Motion:** Basic translation-based hopping, walking, and sleeping idles [00:40, 00:54, 04:08]. Hatch animations are not visible.
6. **Menu Display:** Shown in UI cards and circular tiles at a 3/4 isometric perspective [00:00, 00:01, 01:13] against high-contrast solid or patterned backgrounds.

---

### Part B: Performance Evaluation (Scale Mapped to 3–7)

* **Silhouette (Score: 5/10):** Ear, wing, and horn protrusions provide basic distinction [00:00, 01:19, 02:35], but uniform cubic torsos reduce readability at small sizes.
* **Face Appeal (Score: 4/10):** Minimalist block eyes yield mild cuteness [03:57, 07:52], but lack the emotional resonance of top-tier Roblox titles.
* **Form Quality (Score: 5/10):** Clean geometric assembly with precise grid alignment [01:19, 06:29]; no visible mesh clipping or awkward geometry.
* **Surface (Score: 4/10):** Readability is clear due to flat palette choices [01:19, 02:35], though total lack of material depth or texturing limits visual polish.
* **Rarity Read (Score: 5/10):** Particle trails and glowing eyes make Divine tiers instantly recognizable [00:01, 12:03] compared to baseline models [01:34].
* **Set Cohesion (Score: 6/10):** Strict adherence to blocky voxel proportion rules creates a unified family look across all pets [00:48, 02:30, 07:45].
* **Motion and Life (Score: 4/10):** Functional, low-frame idle cycles and action states [00:40, 00:54, 04:08]; full hatch reveal sequences are not visible.

---

### Part C: 7 Core Production Rules for New Developers

1. **Maintain a 1:1 Head-to-Body Ratio:** Keep head size equal to body height for instant visual appeal.
2. **Cap Geometry at 15 Primitives:** Restrict low-poly character assemblies to 8–15 block shapes.
3. **Limit Palette to 4 Colors:** Use a maximum of 2–4 solid colors per creature to prevent visual noise.
4. **Scale Eye Assets to 25% Head Width:** Maintain consistent facial proportions across species using oversized square eye planes.
5. **Reserve Glow/Particles for Top Tiers:** Restrict emissive shaders and aura particle emitters exclusively to highest-rarity pets.
6. **Standardize UI Framing to 3/4 Isometric Angles:** Display inventory models consistently at a 45-degree front-side angle.
7. **Keep Idle Cycles Under 2 Seconds:** Use short, looping vertical bobbing or rotation motions for idle animations.
