"""Controller parity check (no Studio needed): every keyboard key a client script listens to must be listed in
Gamepad.KEYBOARD (src/client/Gamepad.luau) with what does the same on a controller, so a PC shortcut is never the
only way to do something. Rule from the console-first pass (2026-11-24): 0 keyboard-only actions.

  python scripts/pad_parity.py        prints the table, exits 1 when a key is missing
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLIENT = ROOT / "src" / "client"
PAD = re.compile(r"^(Button|DPad|Thumbstick)")

gamepad = (CLIENT / "Gamepad.luau").read_text(encoding="utf-8")
table = re.search(r"Gamepad\.KEYBOARD = \{(.*?)\n\}", gamepad, re.S)
if not table:
    sys.exit("pad_parity: Gamepad.KEYBOARD not found in src/client/Gamepad.luau")
listed = dict(re.findall(r"(\w+) = \"([^\"]+)\"", table.group(1)))

used = {}
for path in sorted(CLIENT.glob("*.luau")):
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("--"):
            continue
        for key in re.findall(r"Enum\.KeyCode\.(\w+)", line):
            if not PAD.match(key) and key != "Unknown":
                used.setdefault(key, []).append(f"{path.name}:{n}")

missing = sorted(k for k in used if k not in listed)
for key in sorted(used):
    print(f"[PADPARITY] {key:10} {listed.get(key, 'MISSING: no controller route'):50} {', '.join(used[key][:3])}")
print(f"[PADPARITY] {len(used)} keyboard keys, {len(missing)} without a controller route")
print("[PADPARITY]", "OK" if not missing else "FAILED: " + ", ".join(missing))
sys.exit(1 if missing else 0)
