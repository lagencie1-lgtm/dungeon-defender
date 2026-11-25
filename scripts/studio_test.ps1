# Runs one test project in Roblox Studio (the HTD_AutoTest plugin starts the play test for htd-autotest-* files)
# and prints the lines with the given tag.  scripts/studio_test.ps1 -Project test/ground.project.json -Tag GROUND
param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Tag, [int]$Limit = 600)
$ErrorActionPreference = "Stop"
# one Studio run at a time on this PC (shared with the pets thread): tools\studio.lock, stale after 25 minutes
$lockFile = Join-Path (Split-Path $PSScriptRoot -Parent) "tools\studio.lock"
while ((Test-Path $lockFile) -and ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes -lt 25) {
    Write-Output "waiting for the Studio lock: $(Get-Content $lockFile -Raw)"
    Start-Sleep 60
}
Set-Content $lockFile "hub thread (film/test) $(Get-Date -Format s)"
try {
$root = Split-Path $PSScriptRoot -Parent
$name = ((Get-Content (Join-Path $root $Project) -Raw) | ConvertFrom-Json).name
$place = Join-Path $root "tools\$name.rbxl"
& "$root\tools\rojo.exe" build (Join-Path $root $Project) -o $place
if ($LASTEXITCODE -ne 0) { throw "rojo build failed" }
$studio = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
# (every log that exists now: with another Studio open, the newest log can be that Studio's)
$before = @(Get-ChildItem "$logDir\*Studio*.log" | ForEach-Object { $_.FullName })
$proc = Start-Process $studio -ArgumentList "`"$place`"" -PassThru
$log = $null
for ($i = 0; $i -lt 90 -and -not $log; $i++) {
    Start-Sleep 1
    $new = Get-ChildItem "$logDir\*Studio*.log" | Where-Object { $before -notcontains $_.FullName } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($new) { $log = $new.FullName }
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

} finally { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }
