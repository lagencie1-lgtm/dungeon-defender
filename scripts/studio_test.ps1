# Runs one test project in Roblox Studio (the HTD_AutoTest plugin starts the play test for htd-autotest-* files)
# and prints the lines with the given tag.  scripts/studio_test.ps1 -Project test/ground.project.json -Tag GROUND
param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Tag, [int]$Limit = 600)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$name = ((Get-Content (Join-Path $root $Project) -Raw) | ConvertFrom-Json).name
$place = Join-Path $root "tools\$name.rbxl"
& "$root\tools\rojo.exe" build (Join-Path $root $Project) -o $place
if ($LASTEXITCODE -ne 0) { throw "rojo build failed" }
$studio = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
$before = Get-ChildItem "$logDir\*Studio*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$proc = Start-Process $studio -ArgumentList "`"$place`"" -PassThru
$log = $null
for ($i = 0; $i -lt 90 -and -not $log; $i++) {
    Start-Sleep 1
    $new = Get-ChildItem "$logDir\*Studio*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($new -and (-not $before -or $new.FullName -ne $before.FullName)) { $log = $new.FullName }
}
$deadline = (Get-Date).AddSeconds($Limit)
while ((Get-Date) -lt $deadline) {
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if ($text -match "play test finished|\[$Tag\] DONE") { break }
    Start-Sleep 2
}
Start-Sleep 2
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Select-String -Path $log -Pattern "\[$Tag\]|Script '.*', Line|Error: " | ForEach-Object {
    $_.Line -replace '^[^\[]*\[FLog::\w+\] ', '' } | Select-Object -First 200
