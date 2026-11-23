# Pet Simulator 99: pets

Source: https://www.youtube.com/watch?v=TawTgjlZKmI (Gemini model gemini-3.5-flash)

### Part A: How Pets Are Built

1. **Body Recipe**: Pets use extruded cubes or rounded blocks (approx. 80% cube volume) [00:14]. Head-to-body ratio is typically 1:1 or unified into a single block [00:15, 12:12]. Models consist of 1 to 6 primitive mesh pieces with four stubby block legs or no legs at all [00:19, 03:43].
2. **Face**: Features are 2D textures painted directly onto the front mesh face [00:19, 12:12]. Eyes are wide-set, occupying 30–45% of the head width, featuring simple dark pupils with white highlight dots [00:15, 00:20]. Mouths and noses are minimalist vector lines [00:15].
3. **Surface**: Base meshes use flat colors or simple gradient maps with 2 to 4 colors per pet [00:19, 05:12]. Surfaces are smooth-shaded without black outlines, while magical variants feature emissive textures [12:12, 22:26].
4. **Rare/Top-Tier Features**: High-tier "Huge" pets display neon emissive shaders, particle trail auras, translucent materials, and scale up to 3x–5x larger than standard pets [12:12, 22:26, 24:45].
5. **Motion**: Pets follow players via rigid floating or rhythmic hopping scripts [00:21, 06:00]. Hatch/reveal animations feature a 2-to-3-second sequence with a flashing light burst and explosive particle pop [12:08–12:12, 22:24–22:27].
6. **Menu Display**: Items are shown in square inventory tiles at a 3/4 front isometric angle, framed by rarity-colored backgrounds and glow borders [00:19, 08:38].

---

### Part B: Pet Ratings (Scale 1–10)

*Evaluated on a compressed 3–7 scale per instructions.*

* **Silhouette: 4/10** — Blocky base templates make different species hard to distinguish by outline alone.
* **Face Appeal: 6/10** — Simple, expressive eye textures effectively capture target audience appeal.
* **Form Quality: 5/10** — Clean primitive geometry avoids clipping, though overall form depth is minimal.
* **Surface: 5/10** — Crisp face decals balance out otherwise basic, flat body color maps.
* **Rarity Read: 6/10** — Intense particle auras and emissive shaders clearly distinguish rare variants.
* **Set Cohesion: 7/10** — Uniform block proportion rules create a highly consistent visual family.
* **Motion and Life: 4/10** — Movement relies on basic bobbing and hopping scripts rather than articulated skeletal animations.

---

### Part C: 7 Copyable Production Rules

1. **Polygon Cap**: Keep base pet models under 500 polygons using a dominant cube structure.
2. **Eye Scale**: Render eye decals across 35–40% of the front face width for immediate expression read.
3. **Color Budget**: Limit base pet texture maps to a maximum of 4 distinct colors.
4. **Hierarchy Scale**: Standardize pet tier scaling to 1x (Standard), 3x (Huge), and 6x (Titanic).
5. **Emissive Shading**: Apply 100% self-illumination shaders to rare skin variants for instant visibility.
6. **Hatch Timing**: Cap egg hatch reveal animations at exactly 2.5 seconds from burst to full display.
7. **Framing Angle**: Render inventory preview cards at a fixed 35-degree isometric angle.
