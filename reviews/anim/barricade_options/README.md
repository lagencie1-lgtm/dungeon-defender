# Making the barricade fight read on a phone: options (2026-11-26)

Each option was a quick local test in a throwaway copy that merges the barricade branch (6283328). Nothing here is in the game code; this folder holds review files only.

**Setup:** 8 goblins pile up and smash an L1 wall, filmed at phone size from the run camera (32 degrees down, 20.5 studs back, aimed 3 up). The hero stands 28 studs from the wall. I put the wall on the longest stretch that isn't the last one, because the first try had the portal standing between the hero and the wall.

**Files:** `option_<X>_frame.jpg` (one phone frame), `option_<X>.mp4` (3 s), `option_<X>_sheet.jpg` (the 3 s as frames), `numbers.txt`.

**Measured over 3 s:**
- **Above the wall:** the share of the goblins' bone points that sit above the wall's top edge on screen.
- **Pile height:** the pile's height on screen (bone points, 388 px phone screen).

| option | what it does | above the wall | pile height |
|---|---|---|---|
| A | The wall reacts to each blow: shudder 8 cm at the base, the top boards flex back, 2-3 chips on 1 blow in 3, the health bar flashes. Half the back rows climb onto shoulders. | 27% | 37 px (9.4%) |
| B | While the wall is under attack, the run camera springs 7 degrees **flatter** (32 to 25) over 0.4 s. | 26% | 35 px (9.0%) |
| B2 | Same, but 8 degrees **steeper** (32 to 40). | 31% | 41 px (10.5%) |
| C2 | A + B2 | **37%** | **59 px (15.1%)** |

**Findings:**
- **Steeper, not flatter:** a flatter camera sits lower behind the wall, so the wall hides more of the pile (B: 26% vs B2: 31%). Looking down over the wall shows more.
- **C2 reads best:** the climbing goblins stand above the wall, the pile is 1.6x taller on screen than A, and the wall's reaction marks each blow.
- **C (A with the flatter camera) was not filmed:** B showed the flatter camera hurts.
