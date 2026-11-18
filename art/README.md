# Art pipeline

Everything follows `art/STYLE.md` (one set, one style) and the 6A guides in `docs/6A/`.

## Painted images (icons, portraits)
- `python art/make_icons.py [names]` makes icons with Codex image generation (owner's ChatGPT Pro login,
  the Codex inside the VS Code ChatGPT extension). Output: `art/icons/<name>.png`. The list and prompts are in the script.
- `python scripts/upload_art.py` shrinks them to 256 px (ffmpeg) and uploads them to Roblox, then writes the ids
  into `src/shared/Art.luau`. Needs the "asset" permission on the API key.
- In the game, `Icons.Draw(parent, name)` shows the painted icon when its id exists, else a simple drawn shape.

## 3D models as code (Blender)
- One Python script per model in `art/blender/`, sharing `lib.py` (palette, boxes/cylinders/spheres,
  vertex-colour shading baked from above, join, FBX export). Units are studs.
- Build: `blender -b -P art/blender/tower_ranger.py -- art/models/tower_ranger.fbx`
- Look: `blender -b -P art/blender/preview.py -- art/models/tower_ranger.fbx art/models/tower_ranger_preview.png`
- Budget: under 3,000 triangles per defender. Footprint and height match the game's numbers.
- Upload as a Model asset, then the game swaps the part-built look for the mesh (all or nothing per object).

Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. ffmpeg: `tools\ffmpeg\...\bin\ffmpeg.exe`.
