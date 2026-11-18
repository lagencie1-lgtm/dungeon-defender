"""Creates the game passes and developer products from src/shared/Store.luau
on Roblox (Open Cloud) and writes their new ID numbers back into Store.luau.
Items that already have an ID are skipped. Also sets max players per server.

Needs the API key in tools/roblox-api-key.txt with these permissions:
game-pass (read, write), developer-product (read, write), universe.place (write).
Run:  python scripts/create_store_items.py
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "src", "shared", "Store.luau")
SETTINGS = json.load(open(os.path.join(ROOT, "scripts", "publish.json")))
UNIVERSE, PLACE = SETTINGS["universeId"], SETTINGS["placeId"]
KEY = open(os.path.join(ROOT, "tools", "roblox-api-key.txt")).read().strip()
MAX_PLAYERS = 4


def curl(args):
    out = subprocess.run(["curl", "-s", "-w", "\n%{http_code}", "-H", "x-api-key: " + KEY] + args,
                         capture_output=True, text=True)
    body, _, code = out.stdout.rpartition("\n")
    return int(code or 0), body


def parse_items(text, table):
    """Finds  Key = { Id = 0, Name = "...", Price = 123 ... Text = "..." } inside Store.<table>."""
    start = text.index("Store." + table + " = {")
    end = text.index("\n}", start)
    block = text[start:end]
    items = []
    for m in re.finditer(r'^\t(\w+) = \{ Id = (\d+), Name = "([^"]+)", Price = (\d+)(.*?)\},?[ \t]*$', block, re.S | re.M):
        key, ident, name, price, rest = m.groups()
        t = re.search(r'Text\s*=\s*"([^"]+)"', rest)
        items.append({"key": key, "id": int(ident), "name": name, "price": int(price), "text": t.group(1) if t else name})
    return items


def set_id(text, key, new_id):
    return re.sub(r"(\n\t" + key + r" = \{ Id = )0,", r"\g<1>" + str(new_id) + ",", text, count=1)


def main():
    text = open(STORE, encoding="utf-8").read()

    code, body = curl(["-X", "PATCH", "-H", "Content-Type: application/json",
                       f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}/places/{PLACE}?updateMask=serverSize",
                       "--data", json.dumps({"serverSize": MAX_PLAYERS})])
    print("max players:", "set to %d" % MAX_PLAYERS if code == 200 else "FAILED %d %s" % (code, body[:200]))

    for item in parse_items(text, "GamePasses"):
        if item["id"]:
            continue
        code, body = curl(["-X", "POST", f"https://apis.roblox.com/game-passes/v1/universes/{UNIVERSE}/game-passes",
                           "--form-string", "name=" + item["name"], "--form-string", "description=" + item["text"],
                           "--form-string", "price=%d" % item["price"], "--form-string", "isForSale=true"])
        if code == 200:
            new_id = json.loads(body).get("gamePassId")
            text = set_id(text, item["key"], new_id)
            print("game pass", item["name"], "->", new_id)
        else:
            print("game pass", item["name"], "FAILED", code, body[:200])

    for item in parse_items(text, "Products"):
        if item["id"]:
            continue
        code, body = curl(["-X", "POST", f"https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE}/developer-products",
                           "--form-string", "name=" + item["name"], "--form-string", "description=" + item["text"],
                           "--form-string", "price=%d" % item["price"], "--form-string", "isForSale=true"])
        if code == 200:
            data = json.loads(body)
            new_id = data.get("productId") or data.get("developerProductId") or data.get("id")
            text = set_id(text, item["key"], new_id)
            print("product", item["name"], "->", new_id)
        else:
            print("product", item["name"], "FAILED", code, body[:200])

    open(STORE, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    sys.exit(main())
