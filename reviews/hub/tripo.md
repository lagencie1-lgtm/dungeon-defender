# Tripo list for the Watch Keep (2026-11-22)

Lemp makes these on the Tripo website with **Image to 3D**, from the reference pictures in `art/ref3d/` (front
three-quarter view, white background, painted in the game's style by `scripts/ref3d.py`). Download each as **GLB**
into `art/tripo-in/` with the name below; Claude cleans, bakes and places them. Until they arrive the game uses the
hand-made Blender stand-ins (`art/blender/keep_props.py`, `outpost_props.py`).

| # | Save as | Picture | What it is | Size in game |
|---|---|---|---|---|
| 1 | `keep_beacon.glb` | `art/ref3d/keep_beacon_tower.png` | The Beacon Tower: the landmark, with the PLAY portal in its archway and the violet crystal on top | 42 studs tall |
| 2 | `keep_forge.glb` | `art/ref3d/keep_forge_house.png` | The blacksmith's workshop (FORGE) | 13 tall |
| 3 | `keep_shop.glb` | `art/ref3d/keep_shop_stall.png` | The gem stall (SHOP) | 10 tall |
| 4 | `keep_pets.glb` | `art/ref3d/keep_pet_house.png` | The stump house with the egg nest (PETS) | 9 tall |
| 5 | `keep_quests.glb` | `art/ref3d/keep_quest_board.png` | The notice board with a lantern (QUESTS) | 9 tall |
| 6 | `keep_chest.glb` | `art/ref3d/keep_reward_chest.png` | The big reward chest on its dais (REWARDS) | 5 tall |
| 7 | `keep_hero.glb` | `art/ref3d/keep_hero_statue.png` | The hero statue with the raised sword (HEROES) | 13 tall |

Tripo settings: the default "realistic" texture is fine; ask for a **low-poly / game** mesh if offered (we cut each to
under 10,000 triangles anyway). One model per picture; nothing else is needed from Tripo for the hub.
