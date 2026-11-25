# Heroes Tower Defense (ours): pets

Source: cycle4-sheet1.png, cycle4-sheet2.png (Gemini model gemini-3.5-flash-lite)

### Part A: Per-Pet Breakdown

1. **Green Slime:** Works: smooth jelly sheen. Flaw: generic blob shape with zero hook.
2. **Sprout Bud:** Works: clear leafy sprout theme. Flaw: looks like a half-peeled potato.
3. **Rock Dog:** Works: cute collar detail. Flaw: stone texture looks dirty and low-res.
4. **Leaf Cat:** Works: soft floral accents on ears. Flaw: muddy, undefined fur clusters.
5. **Firefly Bug:** Works: bright glowing antenna balls. Flaw: stiff beetle body lacks squish.
6. **Orange Fox:** Works: perky alert ears. Flaw: chunky, unrefined tail geometry.
7. **Ice Owl:** Works: cool blue crystal spikes. Flaw: muddy brown feathers hide the face.
8. **Cloud Golem:** Works: playful round shapes. Flaw: lacks limbs, looks like a melting rock.
9. **Purple Dragon:** Works: classic chibi dragon silhouette. Flaw: stiff wings glued awkwardly to the back.
10. **Rainbow Unicorn:** Works: colorful mane gradient. Flaw: muddy white body lacks shadow contrast.
11. **Fire Phoenix:** Works: vibrant, fiery wing tips. Flaw: chaotic flame spikes destroy readability.
12. **Armored Dragon:** Works: strong gold trim on wings. Flaw: duplicate model of #9 with minor horns swap.

---

### Part B: 1–10 Ratings

*   **Silhouette: 5/10** — The slime and golem read well, but dragons, foxes, and cats share generic blobby proportions that blur together at 32x32 pixels.
*   **Face appeal: 6/10** — Big anime eyes are present, but the dead-stare expressions lack personality, emotion, or cheekiness.
*   **Form quality: 4/10** — Lumpy sculpts, muddy transitions between materials (rock/fur/leaves), and accidental flat facets betray automated AI generation.
*   **Surface: 5/10** — Gradients are decent, but materials look greasy or clay-like rather than clean, iconic game assets.
*   **Rarity read: 3/10** — Zero hierarchy; a basic slime and a legendary dragon share the exact same asset fidelity and visual noise level.
*   **Set cohesion: 4/10** — They span different art styles: slime is hyper-smooth, rock dog is rough grey, unicorn is pastel, phoenix is hyper-saturated.
*   **Motion and life: N/A** — Still pictures.

---

### Part C: Top 8 Fixes

1.  **Muddy, undefined fur/leaves** -> Looks like procedural AI noise that creates visual clutter -> **Sculpt sharp, clean tufts with maximum 4-color shading planes per clump.**
2.  **Identical dragon models (rows 3 and 6)** -> Lazy asset reuse kills perceived value -> **Delete the duplicate; design a unique wyvern or serpent body type for the rare tier.**
3.  **Low contrast on white/grey pets (Rock Dog, Unicorn)** -> They wash out against Roblox in-game lighting -> **Add vibrant rim lights (cyan/orange) and push ambient occlusion depth by 30%.**
4.  **Inconsistent rendering styles (Jelly vs. Stone vs. Fur)** -> Feels like an asset pack rip rather than a game -> **Standardize specular roughness across all materials to a uniform semi-gloss toy finish.**
5.  **Weak rarity distinction** -> Players can't tell which pet is worth grinding for -> **Add floating magical particles, iridescent shaders, or gold inlay trim exclusively to upper-tier pets.**
6.  **Stiff, glued-on wings (Owl, Insects, Dragons)** -> Kills the illusion of life and movement -> **Angle wings outward by 15 degrees and separate them from the torso mesh with visible socket joints.**
7.  **Blank, unexpressive eyes** -> Kids don't fall in love with dead glares -> **Add dynamic highlight reflections (dual-white dots) and slightly curve mouth corners upward into dynamic smirks.**
8.  **Dull, grey-brown base palettes (Owl, Rock Dog)** -> Unappealing thumbnails in the Roblox marketplace -> **Boost saturation by 25% and shift neutral greys into warm cream or cool slate-blue tones.**
