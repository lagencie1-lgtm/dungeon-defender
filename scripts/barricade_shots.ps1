# Screenshots of the Oak Barricade in a real run (test/shots.project.json): opens the place in Roblox Studio (the
# film plugin runs it in the iPhone 13 simulator), grabs the Studio window at every "[SHOT] <unix ms> <name>" line
# into reviews/towers/barricade/ingame/<name>.png, then closes that Studio.
#   powershell -ExecutionPolicy Bypass -File scripts/barricade_shots.ps1 [-Lock C:\Projects\RealmGuardians\tools\studio.lock] [-FFmpeg path]
param([string]$Lock = "", [string]$FFmpeg = "", [int]$Limit = 240)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not $Lock) { $Lock = Join-Path $root "tools\studio.lock" }
if (-not $FFmpeg) { $FFmpeg = (Get-ChildItem "$root\tools\ffmpeg\*\bin\ffmpeg.exe" | Select-Object -First 1).FullName }
# one Studio run at a time on this PC: the lock, stale after 25 minutes
while ((Test-Path $Lock) -and ((Get-Date) - (Get-Item $Lock).LastWriteTime).TotalMinutes -lt 25) {
    Write-Output "waiting for the Studio lock: $(Get-Content $Lock -Raw)"
    Start-Sleep 60
}
Set-Content $Lock "barricade thread (screenshots, RealmGuardians-barricade) $(Get-Date -Format s)"
$proc = $null
try {
    $out = Join-Path $root "reviews\towers\barricade\ingame"
    New-Item -ItemType Directory -Force $out | Out-Null
    $place = Join-Path $root "tools\htd-film-phone-barricade.rbxl"
    & "$root\tools\rojo.exe" build (Join-Path $root "test\shots.project.json") -o $place
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
    if (-not $log) { throw "no Studio log" }
    $seen = @{}
    Start-Sleep 5
    (New-Object -ComObject WScript.Shell).AppActivate($proc.Id) | Out-Null
    $deadline = (Get-Date).AddSeconds($Limit)
    while ((Get-Date) -lt $deadline) {
        Set-Content $Lock "barricade thread (screenshots, RealmGuardians-barricade) $(Get-Date -Format s)"
        $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
        foreach ($m in [regex]::Matches([string]$text, "\[SHOT\] \d{13} (\w+)")) {
            $name = $m.Groups[1].Value
            if ($seen.ContainsKey($name)) { continue }
            $seen[$name] = $true
            if ($name -eq "done") { continue }
            $title = (Get-Process -Id $proc.Id).MainWindowTitle
            # Studio only redraws its viewport while it has the focus: an unfocused window gave the same stale frame
            # for every shot (the wall's health bar never showed although the wall was being hit)
            (New-Object -ComObject WScript.Shell).AppActivate($proc.Id) | Out-Null
            Start-Sleep -Milliseconds 600
            & $FFmpeg -y -loglevel error -f gdigrab -i "title=$title" -frames:v 1 (Join-Path $out "$name.png")
            Write-Output "shot $name"
        }
        if ($seen.ContainsKey("done") -or ([string]$text -match "play test finished")) { break }
        Start-Sleep -Milliseconds 400
    }
    Select-String -Path $log -Pattern "\[SHOT\]|\[BARCHECK\]|Script '.*', Line|Error: " | ForEach-Object { $_.Line -replace '^[^\[]*\[FLog::\w+\] ', '' } | Select-Object -First 60
} finally {
    if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item $Lock -Force -ErrorAction SilentlyContinue
}
