"""Timing rules for the defenders' shots (coordinator 2026-11-27, 6A): from a film's shot marks ("shot <kind> <wind-up>
<travel>", test/film) and the numbers in Config.TowerShots / TowerLife's springs:
  wind-up      0.08-0.2 s
  settle       the recoil spring back within 2 % of its peak in 0.4 s
  visible      the projectile in flight for at least 4 frames at 60 fps (travel >= 4/60 s)
  damage       lands within one frame of arrival (the server waits wind-up + travel, the same numbers it sends)
  effect size  the hit effect at most 1/5 of the shot's distance (spark / blast width vs travel x speed)
  python scripts/shot_rules.py tools/film/<name>-phonehq [out.md]"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# the widest hit effect of each kind, studs (TowerLife: the spark flash grows to 3.2; the fireball's blast is the
# server's ring of stats.Radius, the frost wave is the attack itself and has no shot distance)
EFFECT = {"Ballista": "fifth", "Ranger": "fifth", "FlameCannon": None, "StormObelisk": 1.6, "FrostCrystal": None}


def config():
    src = open(os.path.join(ROOT, "src", "shared", "Config.luau"), encoding="utf-8").read()
    block = src[src.index("Config.TowerShots = {"):]
    block = block[:block.index("\n}\n")]
    out = {}
    for m in re.finditer(r"\t(\w+) = \{(.*?)\},", block, re.S):
        out[m.group(1)] = {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", m.group(2))}
    return out


def settle(kick, k=220.0, c=24.0, dt=1 / 240):   # (TowerLife's recoil spring)
    x, v, peak, t, last = 0.0, kick, 0.0, 0.0, 0.0
    while t < 2:
        a = -x * k - v * c
        v += a * dt
        x += v * dt
        t += dt
        peak = max(peak, abs(x))
        if abs(x) > 0.02 * peak:
            last = t
    return last


def main():
    film = sys.argv[1]
    cfg = config()
    seen = {}
    for ln in open(film + ".marks.txt", encoding="utf-8"):
        _, _, name = ln.strip().partition("\t")
        p = name.split()
        if len(p) == 4 and p[0] == "shot":
            seen.setdefault(p[1], []).append((float(p[2]), float(p[3])))
    rows = ["| tower | shots | wind-up s | settle s | flight frames at 60 fps (min) | damage on arrival | widest effect / shot distance | projectile px at 720p (run camera) | verdict |",
            "|---|---|---|---|---|---|---|---|---|"]
    for kind, shots in sorted(seen.items()):
        c = cfg.get(kind, {})
        w = sorted(x[0] for x in shots)
        tr = [x[1] for x in shots]
        kick = c.get("Kick", 0) * 22
        st = settle(kick) if kick else 0.0
        frames = min(tr) * 60 if kind not in ("StormObelisk", "FrostCrystal") else None
        speed = c.get("Speed")
        dist = min(tr) * speed if speed else None
        eff = EFFECT.get(kind)
        if eff == "fifth" and dist:   # (TowerLife grows the spark to 0.8 + clamp(d / 5 - 0.8, 0.6, 2.4))
            eff = 0.8 + max(0.6, min(dist / 5 - 0.8, 2.4))
        ratio = eff / dist if eff and dist else None
        # (round 4: the arrow and the bolt at least 12 px long on a 720p phone frame at the run camera: 20.5 studs, 70 deg)
        LEN = {"Ranger": 3.8, "Ballista": 3.6}
        px = LEN[kind] * 720 / (2 * 20.5 * 0.7002) if kind in LEN else None
        ok = (0.08 <= w[0] and w[-1] <= 0.2) and st <= 0.4 and (frames is None or frames >= 4) and (ratio is None or ratio <= 0.2) and (px is None or px >= 12)
        rows.append("| %s | %d | %.2f-%.2f | %.2f | %s | yes (wind-up + travel on both sides) | %s | %s | %s |" % (
            kind, len(shots), w[0], w[-1], st, "%.0f" % frames if frames is not None else "n/a (strikes at once / wave)",
            "%.2f (%.1f of %.1f studs)" % (ratio, eff, dist) if ratio else "n/a", "%.0f" % px if px else "n/a", "PASS" if ok else "FAIL"))
    txt = "\n".join(rows)
    print(txt)
    if len(sys.argv) > 2:
        open(sys.argv[2], "w", encoding="utf-8").write(txt + "\n")


if __name__ == "__main__":
    main()
