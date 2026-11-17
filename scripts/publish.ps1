# Builds the game from the scripts and publishes it to Roblox, without Studio.
# Needs:
#   scripts\publish.json        -> { "universeId": 123, "placeId": 456 }  (from Creator Hub)
#   tools\roblox-api-key.txt    -> your Open Cloud API key (never in git: tools\ is ignored)
# Run:  powershell -ExecutionPolicy Bypass -File scripts\publish.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$settings = Get-Content "$PSScriptRoot\publish.json" -Raw | ConvertFrom-Json
$keyFile = Join-Path $root "tools\roblox-api-key.txt"
if (-not (Test-Path $keyFile)) { throw "API key missing: put it in tools\roblox-api-key.txt" }
$key = (Get-Content $keyFile -Raw).Trim()

$out = Join-Path $root "tools\publish-build.rbxl"
& "$root\tools\rojo.exe" build -o $out
if ($LASTEXITCODE -ne 0) { throw "rojo build failed" }

$url = "https://apis.roblox.com/universes/v1/$($settings.universeId)/places/$($settings.placeId)/versions?versionType=Published"
$result = Invoke-RestMethod -Method Post -Uri $url -InFile $out -ContentType "application/octet-stream" -Headers @{ "x-api-key" = $key }
Write-Output "Published version $($result.versionNumber)"
