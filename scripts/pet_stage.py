"""Pet stage: shows the uploaded second-generation pets INSIDE Roblox Studio, next to the pets the game uses today,
under daylight like the game's, and takes screenshots through Studio's connector (scripts/studio_mcp.py). Blender
renders are kinder than the engine, so no pet counts as done from a render (6A: judge in the game's light).

  python scripts/pet_stage.py            all 12, new row in front, old row behind -> reviews/pets/img/stage-*.png
  python scripts/pet_stage.py --keep     leave that Studio window open afterwards (for looking around by hand)

Takes tools/studio.lock for the run (one Studio job at a time on this PC) and only closes its own Studio window.
"""
import glob
import json
import os
import re
import subprocess
import sys
import time

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Studio  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCK = os.path.join(ROOT, "tools", "studio.lock")
PLACE = os.path.join(ROOT, "tools", "pets-stage.rbxlx")
OUT = os.path.join(ROOT, "reviews", "pets", "img")
KINDS = ["slimey", "leafling", "stonepup", "mosskitten", "glowbug", "emberfox", "crystalowl", "minigolem", "babydragon",
         "starunicorn", "phoenix", "voiddrake"]

LUAU = r"""
local data = game:GetService("HttpService"):JSONDecode([==[%s]==])
local old = workspace:FindFirstChild("PetStage")
if old then old:Destroy() end
local stage = Instance.new("Folder")
stage.Name = "PetStage"
stage.Parent = workspace
local L = game:GetService("Lighting")
L.ClockTime = 14.5
L.GeographicLatitude = 35
L.Brightness = 3
L.Ambient = Color3.fromRGB(120, 120, 130)
L.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
L.EnvironmentDiffuseScale = 0.2
L.EnvironmentSpecularScale = 0.2
local ground = Instance.new("Part")
ground.Anchored = true
ground.Size = Vector3.new(160, 1, 320)
ground.Position = Vector3.new(0, -0.5, -90)
ground.Material = Enum.Material.Grass
ground.Color = Color3.fromRGB(106, 150, 74)
ground.Parent = stage
local loaded, failed = 0, {}
-- NEW pets get a fully rough surface (a MaterialVariant whose roughness map is plain white): Roblox's default
-- plastic puts small white highlights on them, measured on 2026-11-23 (reviews/pets/img/matte-*.png)
if data[1] and data[1].white then
	local MS = game:GetService("MaterialService")
	local oldv = MS:FindFirstChild("HTD_Matte")
	if oldv then oldv:Destroy() end
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. data[1].white) end)
	if ok and objs[1] then
		local mv = Instance.new("MaterialVariant")
		mv.Name = "HTD_Matte"
		mv.BaseMaterial = Enum.Material.SmoothPlastic
		mv.RoughnessMap = objs[1].Texture
		mv.Parent = MS
	end
end
-- the stored paint ids are Decal assets; a MeshPart needs the image inside the decal
local function imageOf(id)
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if ok and objs[1] and objs[1]:IsA("Decal") then
		return objs[1].Texture
	end
	return "rbxassetid://" .. id
end
local function place(entry, pos, height)
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. entry.model) end)
	if not ok or not objs[1] then
		table.insert(failed, entry.name .. ": " .. tostring(objs))
		return
	end
	local model = objs[1]
	if not model:IsA("Model") then
		local m = Instance.new("Model")
		model.Parent = m
		model = m
	end
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			part.Anchored = true
			part.CanCollide = false
			local r, g, b = part.Name:match("^c_(%%d+)_(%%d+)_(%%d+)")
			if r then
				part.Color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
				part.Material = Enum.Material.Neon
			else
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new(1, 1, 1)
				part.TextureID = imageOf(entry.paint)
				if entry.matte then
					part.MaterialVariant = "HTD_Matte"
				end
			end
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(height / size.Y)
	local cf, size2 = model:GetBoundingBox()
	-- the models face -Z after import; turn them to face the camera at +Z
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(entry.turn or 180), 0))
	local cf3 = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (pos + Vector3.new(0, size2.Y / 2, 0) - cf3.Position))
	model.Name = entry.name
	model.Parent = stage
	loaded += 1
end
local function tag(text, pos, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos + Vector3.new(0, 3.3, 0)
	anchor.Parent = stage
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(70, 22)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Text = text
	label.Parent = gui
end
-- four rows of three pairs, rows far apart so each picture shows only its own row: OLD on the left, NEW on the right
for i, e in data do
	local col, row = (i - 1) %% 3, math.floor((i - 1) / 3)
	local x, z = (col - 1) * 8.4, row * -60
	place({ name = "new_" .. e.kind, model = e.new_model, paint = e.new_paint, matte = e.white ~= nil }, Vector3.new(x + 1.7, 0, z), 2.3)
	tag("NEW", Vector3.new(x + 1.7, 0, z), Color3.fromRGB(30, 130, 60))
	if e.old_model then
		place({ name = "old_" .. e.kind, model = e.old_model, paint = e.old_paint }, Vector3.new(x - 1.7, 0, z), 2.3)
		tag("OLD", Vector3.new(x - 1.7, 0, z), Color3.fromRGB(150, 40, 40))
	end
end
return ("loaded %%d, failed %%d: %%s"):format(loaded, #failed, table.concat(failed, " | "))
"""


def enlarge(title_part, width=1700, height=1040):
    """Makes that Studio window bigger without bringing it to the front or giving it the keyboard, so the game
    view (and with it every screenshot) is larger."""
    import ctypes
    from ctypes import wintypes
    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    def each(hwnd, _):
        buf = ctypes.create_unicode_buffer(300)
        user32.GetWindowTextW(hwnd, buf, 300)
        if title_part in buf.value and "Roblox Studio" in buf.value and user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    user32.EnumWindows(each, 0)
    for hwnd in found:
        user32.SetWindowPos(hwnd, 1, 0, 0, width, height, 0x0010 | 0x0002)   # HWND_BOTTOM, no activate, no move
    return len(found)


MATERIALS = ["SmoothPlastic", "Plastic", "Rubber", "Plaster", "Fabric", "Cardboard", "Sand", "Wood"]


def main():
    while os.path.exists(LOCK) and time.time() - os.path.getmtime(LOCK) < 25 * 60:
        print("waiting for the Studio lock:", open(LOCK).read().strip(), flush=True)
        time.sleep(60)
    open(LOCK, "w").write("pets thread (pet stage) " + time.strftime("%Y-%m-%dT%H:%M:%S"))
    proc = None
    try:
        store = json.load(open(os.path.join(ROOT, "reviews", "pets", "assets.json")))
        art = open(os.path.join(ROOT, "src", "shared", "Art.luau"), encoding="utf-8").read()
        models_block = art[art.index("Art.Models = {"):]
        data = []
        for k in KINDS:
            if k not in store or "model" not in store[k]:
                continue
            om = re.search(r"\n\tpet_" + k + r' = "(\d+)"', models_block)
            op = re.search(r"\n\tpaint_pet_" + k + r' = "(\d+)"', art)
            data.append({"kind": k, "new_model": store[k]["model"], "new_paint": store[k]["paint"],
                         "old_model": om.group(1) if om else None, "old_paint": op.group(1) if op else None})
            if "_white" in store and "--shiny" not in sys.argv:
                data[-1]["white"] = store["_white"]["decal"]
        open(PLACE, "w").write('<roblox version="4"></roblox>')
        studio_exe = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe")), key=os.path.getmtime)[-1]
        proc = subprocess.Popen([studio_exe, PLACE])
        s = None
        for _ in range(40):
            time.sleep(4)
            s = Studio()
            found = [x for x in s.studios() if "pets-stage" in x.get("file", "")]
            if found:
                s.studio_id = found[0]["id"]
                break
            s.close()
            s = None
        if not s:
            raise SystemExit("Studio did not connect (is the connector still on?)")
        enlarge("pets-stage")
        material = sys.argv[sys.argv.index("--material") + 1] if "--material" in sys.argv else "SmoothPlastic"
        for attempt in range(8):   # Studio answers before the place is ready: try until the stage really loaded
            got = s.text("execute_luau", {"code": (LUAU % json.dumps(data)).replace("Enum.Material.SmoothPlastic", "Enum.Material." + material),
                                          "datamodel_type": "Edit"})
            if got.strip().startswith("loaded"):
                break
            time.sleep(6)
        print(got[:300], flush=True)
        time.sleep(40)   # meshes and textures stream in (captures taken earlier show blurred paint)
        os.makedirs(OUT, exist_ok=True)
        shots = {}
        if "--materials" in sys.argv:   # the same NEW pet under each candidate material: which one keeps the paint calm?
            kind = sys.argv[sys.argv.index("--materials") + 1]
            i = [e["kind"] for e in data].index(kind)
            x, z = (i % 3 - 1) * 8.4 + 1.7, (i // 3) * -60
            for m in MATERIALS:
                s.text("execute_luau", {"datamodel_type": "Edit", "code": (
                    'for _, p in workspace.PetStage["new_%s"]:GetDescendants() do if p:IsA("MeshPart") and p.Material ~= Enum.Material.Neon then '
                    'pcall(function() p.Material = Enum.Material.%s end) end end return "ok"') % (kind, m)})
                time.sleep(1.5)
                try:
                    print(s.shot(os.path.join(OUT, f"mat-{kind}-{m}.png"), {"camera_position": [x - 1.0, 1.8, z + 3.0], "look_at_position": [x, 1.2, z]}), flush=True)
                except Exception as e:
                    print("shot failed", m, e, flush=True)
            s.close()
            return
        if "--matte" in sys.argv:   # the same NEW pet with Roblox's default surface and with a fully rough (matte) one
            kind = sys.argv[sys.argv.index("--matte") + 1]
            i = [e["kind"] for e in data].index(kind)
            x, z = (i % 3 - 1) * 8.4 + 1.7, (i // 3) * -60
            cam = {"camera_position": [x - 0.9, 1.7, z + 2.7], "look_at_position": [x, 1.2, z]}
            time.sleep(4)
            print(s.shot(os.path.join(OUT, f"matte-{kind}-default.png"), cam), flush=True)
            print(s.text("execute_luau", {"datamodel_type": "Edit", "code": (
                'local MS = game:GetService("MaterialService") local old = MS:FindFirstChild("HTD_Matte") if old then old:Destroy() end '
                'local mv = Instance.new("MaterialVariant") mv.Name = "HTD_Matte" mv.BaseMaterial = Enum.Material.SmoothPlastic '
                'local d = game:GetObjects("rbxassetid://%s")[1] mv.RoughnessMap = d.Texture mv.Parent = MS local n = 0 '
                'for _, p in workspace.PetStage["new_%s"]:GetDescendants() do if p:IsA("MeshPart") and p.Material ~= Enum.Material.Neon then '
                'p.Material = Enum.Material.SmoothPlastic p.MaterialVariant = "HTD_Matte" n += 1 end end return "matte parts " .. n') % (store["_white"]["decal"], kind)}), flush=True)
            time.sleep(5)
            print(s.shot(os.path.join(OUT, f"matte-{kind}-matte.png"), cam), flush=True)
            s.close()
            return
        for i, e in enumerate(data):   # one picture per pair: OLD on the left, NEW on the right
            x, z = (i % 3 - 1) * 8.4, (i // 3) * -60
            shots[f"stage-{i + 1:02d}-{e['kind']}"] = {"camera_position": [x, 2.3, z + 6.6], "look_at_position": [x, 1.2, z]}
        if "--close" in sys.argv:   # close-ups of the NEW pets (surface smoothness, faces): --close kind [kind ...] or --close all
            want = [k for k in sys.argv[sys.argv.index("--close") + 1:] if not k.startswith("--")]
            for i, e in enumerate(data):
                if e["kind"] in want or "all" in want:
                    x, z = (i % 3 - 1) * 8.4 + 1.7, (i // 3) * -60
                    shots[f"close-{e['kind']}"] = {"camera_position": [x - 1.3, 1.9, z + 3.7], "look_at_position": [x, 1.2, z]}
                    shots[f"close-{e['kind']}-side"] = {"camera_position": [x + 3.4, 1.7, z + 1.6], "look_at_position": [x, 1.2, z]}
        shots["stage-phone"] = {"camera_position": [0, 9, 26], "look_at_position": [0, 1, 0]}   # pets at the size a hero's camera shows them
        for name, cam in shots.items():
            try:
                print(s.shot(os.path.join(OUT, name + ".png"), cam), flush=True)
            except Exception as e:
                print("shot failed", name, e, flush=True)
        s.close()
    finally:
        if proc and "--keep" not in sys.argv:
            subprocess.run(["powershell", "-NoProfile", "-Command",
                            "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*pets-stage*' } | Stop-Process -Force"])
        if os.path.exists(LOCK):
            os.remove(LOCK)


if __name__ == "__main__":
    main()
