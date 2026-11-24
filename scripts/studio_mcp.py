"""Talks to Roblox Studio through Studio's own connector (the built-in MCP server; switched on 2026-11-23 in Studio:
Assistant Settings > MCP Servers > "Enable Studio as MCP server", saved in %LOCALAPPDATA%/Roblox/AssistantSettings).
With it a script can start and stop a play test, run Luau in the open place, read the output and take a screenshot
of the game view, without touching the mouse or the window.

  python scripts/studio_mcp.py studios                         the open Studio windows and their ids
  python scripts/studio_mcp.py tools                           every tool with its inputs
  python scripts/studio_mcp.py call <tool> '<json arguments>'  one call; add --studio <id> or leave it to the only one
  python scripts/studio_mcp.py shot out.png ['<json arguments>']   screen_capture saved as a picture

As a module:  from studio_mcp import Studio;  with Studio() as s: s.call("execute_luau", {...})
Take tools\\studio.lock before opening or driving a Studio (see CLAUDE.md of the hub thread's rules).
"""
import base64
import glob
import json
import os
import subprocess
import sys
import threading
import time


class Studio:
    def __init__(self):
        exe = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe")), key=os.path.getmtime)
        if not exe:
            raise SystemExit("StudioMCP.exe not found: update Roblox Studio")
        self.p = subprocess.Popen([exe[-1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                  text=True, encoding="utf-8", errors="ignore")
        self.answers, self.next_id = {}, 1
        threading.Thread(target=self._read, daemon=True).start()
        self._request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "htd", "version": "1"}})
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        time.sleep(1.5)   # Studio registers its tools a moment after the handshake
        self.studio_id = None

    def _read(self):
        for line in self.p.stdout:
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if "id" in o:
                self.answers[o["id"]] = o

    def _send(self, obj):
        self.p.stdin.write(json.dumps(obj) + "\n")
        self.p.stdin.flush()

    def _request(self, method, params=None, timeout=180):
        i = self.next_id
        self.next_id += 1
        self._send({"jsonrpc": "2.0", "id": i, "method": method, "params": params or {}})
        end = time.time() + timeout
        while time.time() < end:
            if i in self.answers:
                o = self.answers.pop(i)
                if "error" in o:
                    raise RuntimeError(json.dumps(o["error"]))
                return o["result"]
            time.sleep(0.05)
        raise TimeoutError(method)

    def tools(self):
        return self._request("tools/list")["tools"]

    def studios(self):
        r = self._request("tools/call", {"name": "list_roblox_studios", "arguments": {}})
        return json.loads(r["content"][0]["text"])["studios"]

    def call(self, tool, arguments=None, timeout=300):
        """returns the list of content parts ({type: text|image, ...})"""
        arguments = dict(arguments or {})
        if tool != "list_roblox_studios" and "studio_id" not in arguments:
            if not self.studio_id:
                found = self.studios()
                if not found:
                    raise SystemExit("no Roblox Studio with the connector is open")
                self.studio_id = found[0]["id"]
            arguments["studio_id"] = self.studio_id
        r = self._request("tools/call", {"name": tool, "arguments": arguments}, timeout)
        return r.get("content", [])

    def text(self, tool, arguments=None, timeout=300):
        return "\n".join(c.get("text", "") for c in self.call(tool, arguments, timeout) if c.get("type") == "text")

    def shot(self, path, arguments=None):
        arguments = dict(arguments or {})
        arguments.setdefault("capture_id", "ScreenCapture_%d" % int(time.time() * 10 % 100000))
        parts = self.call("screen_capture", arguments)
        for c in parts:
            if c.get("type") == "image":
                with open(path, "wb") as f:
                    f.write(base64.b64decode(c["data"]))
                return path
        raise RuntimeError("no picture came back: " + " ".join(c.get("text", "") for c in parts)[:300])

    def close(self):
        self.p.kill()

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "studios"
    with Studio() as s:
        if "--studio" in sys.argv:
            s.studio_id = sys.argv[sys.argv.index("--studio") + 1]
        if cmd == "studios":
            print(json.dumps(s.studios(), indent=1))
        elif cmd == "tools":
            for t in s.tools():
                props = t.get("inputSchema", {}).get("properties", {})
                print(f"{t['name']}({', '.join(props)})\n    {t.get('description', '')[:300]}")
        elif cmd == "call":
            for c in s.call(sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else {}):
                print(c.get("text") or f"<{c.get('type')}>")
        elif cmd == "shot":
            print(s.shot(sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}))


if __name__ == "__main__":
    main()
