# Films the fixed test route (test/film) in Roblox Studio and saves the clip plus its marks.
#   powershell -ExecutionPolicy Bypass -File scripts/film.ps1 -Name before -Mode phone
# Mode: phone (iPhone 13, graphics 1), phonehq (iPhone 13, graphics 8), pc. Output: tools/film/<Name>-<Mode>.mp4
# and .marks.txt (each line: seconds into the clip, mark name). Closes that Studio afterwards.
param([string]$Name = "take", [string]$Mode = "phone", [int]$Limit = 300)
$ErrorActionPreference = "Stop"
# one Studio run at a time on this PC (shared with the pets thread): tools\studio.lock, stale after 25 minutes
$lockFile = Join-Path (Split-Path $PSScriptRoot -Parent) "tools\studio.lock"
while ((Test-Path $lockFile) -and ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes -lt 25) {
    Write-Output "waiting for the Studio lock: $(Get-Content $lockFile -Raw)"
    Start-Sleep 60
}
# (2026-11-24: films 7 and 8 recorded another thread's Studio playtest, which sat over this window: gdigrab
# records the screen area of the window by title. Refuse to film while any other Studio window is open.)
# (only Studios with a window on screen: a windowless leftover process cannot cover this one)
$others = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle })
if ($others.Count -gt 0) {
    throw "another Roblox Studio is open (process $($others.Id -join ', ')): a film would record it; wait until it closes"
}
Set-Content $lockFile "hub thread (film/test) $(Get-Date -Format s)"
try {
$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "tools\film"
New-Item -ItemType Directory -Force $outDir | Out-Null
Copy-Item (Join-Path $root "test\film\HTD_Film.plugin.lua") "$env:LOCALAPPDATA\Roblox\Plugins\HTD_Film.lua" -Force

$place = Join-Path $root "tools\htd-film-$Mode.rbxl"
& "$root\tools\rojo.exe" build (Join-Path $root "test\film.project.json") -o $place
if ($LASTEXITCODE -ne 0) { throw "rojo build failed" }

$studio = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
# (2026-11-25: the newest-written log was another open Studio's, which writes all the time; the film's own log is a
# file that did not exist before this Studio started)
$before = @(Get-ChildItem "$logDir\*Studio*.log" | ForEach-Object { $_.FullName })
$proc = Start-Process $studio -ArgumentList "`"$place`"" -PassThru

# the new Studio log
$log = $null
for ($i = 0; $i -lt 90 -and -not $log; $i++) {
    Start-Sleep 1
    $new = Get-ChildItem "$logDir\*Studio*.log" | Where-Object { $before -notcontains $_.FullName } | Sort-Object CreationTime | Select-Object -First 1
    if ($new) { $log = $new.FullName }
}
if (-not $log) { throw "no Studio log" }

function Read-Log { Get-Content $log -Raw -ErrorAction SilentlyContinue }
# wait for the film start mark, then film the Studio window
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline -and -not ((Read-Log) -match "\[FILM\] \d+ film start")) { Start-Sleep -Milliseconds 300 }
$title = (Get-Process -Id $proc.Id).MainWindowTitle
if (-not $title) { $title = (Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like "*htd-film*" } | Select-Object -First 1).MainWindowTitle }
$clip = Join-Path $outDir "$Name-$Mode.mp4"
$ffmpeg = (Get-ChildItem "$root\tools\ffmpeg\*\bin\ffmpeg.exe" | Select-Object -First 1).FullName
$startMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$ff = New-Object System.Diagnostics.Process
$ff.StartInfo.FileName = $ffmpeg
$ff.StartInfo.Arguments = "-y -loglevel error -f gdigrab -framerate 20 -i `"title=$title`" -t $Limit -vf crop=trunc(iw/2)*2:trunc(ih/2)*2 -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p `"$clip`""
$ff.StartInfo.UseShellExecute = $false
$ff.StartInfo.RedirectStandardInput = $true
$ff.Start() | Out-Null

$deadline = (Get-Date).AddSeconds($Limit)
while ((Get-Date) -lt $deadline -and -not ((Read-Log) -match "film end|play test finished")) { Start-Sleep 1 }
Start-Sleep 2
$ff.StandardInput.Write("q"); $ff.WaitForExit(15000) | Out-Null
if (-not $ff.HasExited) { $ff.Kill() }

# marks relative to the clip start
$marks = Select-String -Path $log -Pattern "\[FILM\] (\d{13}) (.+)$" | ForEach-Object {
    $ms = [int64]$_.Matches[0].Groups[1].Value
    "{0:N1}`t{1}" -f (($ms - $startMs) / 1000.0), $_.Matches[0].Groups[2].Value.Trim()
}
$marks | Set-Content (Join-Path $outDir "$Name-$Mode.marks.txt")
Select-String -Path $log -Pattern "\[FILM\]|Error|error" | Select-Object -Last 60 | ForEach-Object { $_.Line.Substring([Math]::Min(60, $_.Line.Length - 1)) } | Set-Content (Join-Path $outDir "$Name-$Mode.log.txt")
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Write-Output "clip $clip (window '$title')"
$marks

} finally { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }
