"""(tracked copy of tools/push_sync.py, 2026-11-27; keys are matched table by table, see keyed())
Copies this thread's files from the shared tree into the clean push worktree (C:/Projects/RG-push), and takes only
the named towers' lines from Art.luau and TowerService.luau (other threads' edits there stay out).
  python tools/push_sync.py <kinds comma list> <file> ...   (kinds e.g. ballista,storm,frost)"""
import os
import re
import shutil
import sys

SRC = "C:/Projects/RealmGuardians"
DST = "C:/Projects/RG-push"
kinds = sys.argv[1].split(",")
for f in sys.argv[2:]:
    os.makedirs(os.path.dirname(os.path.join(DST, f)), exist_ok=True)
    shutil.copyfile(os.path.join(SRC, f), os.path.join(DST, f))
    print("copied", f)


def keyed(path, pattern):
    src = open(os.path.join(SRC, path), encoding="utf-8").read()
    dst = open(os.path.join(DST, path), encoding="utf-8").read()
    n = 0
    # (2026-11-27: table by table: Art.Icons and Art.Models both have tower_ranger_l1..3, and a model id once went
    # into the icon's line)
    def tables(t):
        cuts = [0] + [m.start() for m in re.finditer(r"^[A-Za-z_.]+ = \{$", t, re.M)] + [len(t)]
        return [t[a:b] for a, b in zip(cuts, cuts[1:])]
    s_parts, d_parts = tables(src), tables(dst)
    if len(s_parts) != len(d_parts):
        raise SystemExit("table layout differs in " + path)
    for i, (sp, dp) in enumerate(zip(s_parts, d_parts)):
        for m in re.finditer(pattern, sp, re.M):
            key, line = m.group(1), m.group(0)
            # (the whole key only: "paint_tower_x_l3" must not take the line of "paint_tower_x_l3_props")
            dp2, c = re.subn(r'^\t+(?:\{ Name = ")?' + re.escape(key) + r'(?: =|").*$', lambda _: line, dp, count=1, flags=re.M)
            if c and dp2 != dp:
                n += 1
            dp = dp2
        d_parts[i] = dp
    dst = "".join(d_parts)
    open(os.path.join(DST, path), "w", encoding="utf-8", newline="").write(dst)
    print(path, n, "lines taken")


for k in kinds:
    if k == "ranger":
        keyed("src/shared/Art.luau", r'^\t((?:paint_)?(?:tower_ranger_l\d|ranger_archer)\w*) = "\d+",')
    else:
        keyed("src/shared/Art.luau", r'^\t((?:paint_)?tower_' + k + r'_l\d\w*) = "\d+",')
    keyed("src/server/TowerService.luau", r'^\t\t\{ Name = "(tower_' + k + r'_l\d)".*$')
