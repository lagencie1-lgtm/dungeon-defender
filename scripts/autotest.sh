#!/usr/bin/env bash
# Builds the test version, opens it in Roblox Studio (the HTD_AutoTest plugin
# then starts a play test), waits for the test to finish and prints what the
# test scripts said plus every script error. Closes that Studio afterwards.
cd "$(dirname "$0")/.."
STUDIO=$(ls -t "$LOCALAPPDATA"/Roblox/Versions/*/RobloxStudioBeta.exe | head -1)
tools/rojo.exe build test.project.json -o tools/htd-autotest.rbxl || exit 1
LOGDIR="$LOCALAPPDATA/Roblox/logs"
before=$(ls -t "$LOGDIR"/*Studio*.log 2>/dev/null | head -1)
"$STUDIO" "$(cygpath -w "$PWD/tools/htd-autotest.rbxl")" &
# wait for Studio's new log file
for _ in $(seq 1 60); do
	log=$(ls -t "$LOGDIR"/*Studio*.log | head -1)
	[ "$log" != "$before" ] && break
	sleep 1
done
# wait until the play test ends (or 6 minutes)
for _ in $(seq 1 360); do
	grep -q "play test finished" "$log" && break
	sleep 1
done
grep -E "AUTOTEST|CreatorError|Info: Script '" "$log" | grep -v "spend point false\|select hero" | sed -E 's/^[^[]*\[FLog::Creator(Output|Error)\] //' | cut -c1-260
# close the test Studio (only the one showing the test file)
powershell -NoProfile -Command "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -like '*htd-autotest*' } | Stop-Process -Force"
