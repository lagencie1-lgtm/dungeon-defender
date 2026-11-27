"""Numbers for what makes a tower read on the phone (coordinator 2026-11-27): each tower level's phone view (with
its outline from the film, tools/rules_<film>/<Kind>_l<n>_mask.png) against its painting, the painting scaled so
the tower is as tall in pixels as on the phone.
  sharpness   mean gradient (Sobel) inside the tower, phone / painting
  edge        mean lightness step across the tower's outline, tower against what is round it (phone only)
  saturation  mean HSV saturation inside the tower, phone / painting
  value range lightness spread (std) inside the tower, phone / painting
  width/height  the silhouette's width over its height, phone / painting (Codex 2026-11-27: tall and narrow)
  footing     lightness of the bottom 15 % of the tower minus the rest, phone and painting (a pale rim)
  python scripts/phone_measure.py <rules dir> [out.md]"""
import os
import sys

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KINDS = {"ranger": "Ranger", "ballista": "Ballista", "storm": "StormObelisk", "flame": "FlameCannon", "frost": "FrostCrystal"}


def stats(img, mask):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
    L = lab[..., 0] * 100 / 255
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    gx = cv2.Sobel(L, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(L, cv2.CV_32F, 0, 1, ksize=3)
    g = np.hypot(gx, gy)
    inner = cv2.erode(mask.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0   # (not the outline itself)
    return float(g[inner].mean()), float(hsv[..., 1][mask].mean() / 255), float(L[mask].std()), L


def main():
    rules = sys.argv[1]
    rows = ["| tower level | sharpness phone/painting | edge step (L) | saturation phone/painting | value range phone/painting | width/height phone/painting | footing L step phone / painting |", "|---|---|---|---|---|---|---|"]
    tot = []
    for kind, K in KINDS.items():
        for lv in (1, 2, 3):
            ph = cv2.imread(os.path.join(rules, f"{K}_l{lv}_phone.png"))
            mk = cv2.imread(os.path.join(rules, f"{K}_l{lv}_mask.png"), 0)
            pt = cv2.imread(os.path.join(ROOT, "art", "ref3d", f"tower_{kind}_l{lv}.png"))
            if ph is None or mk is None or pt is None:
                continue
            if mk.shape != ph.shape[:2]:
                mk = cv2.resize(mk, (ph.shape[1], ph.shape[0]), interpolation=cv2.INTER_NEAREST)
            m = mk > 127
            ys, xs = np.nonzero(m)
            h = ys.max() - ys.min() + 1
            pm = (pt.astype(int).sum(-1) < 3 * 235)           # (the painting's tower: everything off its white ground)
            pys, pxs = np.nonzero(pm)
            crop = pt[pys.min():pys.max() + 1, pxs.min():pxs.max() + 1]
            cm = pm[pys.min():pys.max() + 1, pxs.min():pxs.max() + 1]
            k = h / crop.shape[0]
            crop = cv2.resize(crop, (max(1, int(crop.shape[1] * k)), h), interpolation=cv2.INTER_AREA)
            cm = cv2.resize(cm.astype(np.uint8), (crop.shape[1], h), interpolation=cv2.INTER_NEAREST) > 0
            s1, sat1, v1, L = stats(ph, m)
            s2, sat2, v2, _ = stats(crop, cm)
            ring_in = m & ~(cv2.erode(m.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0)
            ring_out = (cv2.dilate(m.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0) & ~m
            edge = abs(float(L[ring_in].mean()) - float(L[ring_out].mean()))
            ar1 = (xs.max() - xs.min() + 1) / h
            ar2 = crop.shape[1] / h
            def foot(Lm, mm):
                yy = np.nonzero(mm)[0]; cut = yy.max() - 0.15 * (yy.max() - yy.min())
                rowsel = np.arange(mm.shape[0])[:, None] >= cut
                return float(Lm[mm & rowsel].mean() - Lm[mm & ~rowsel].mean())
            L2 = cv2.cvtColor(crop, cv2.COLOR_BGR2LAB)[..., 0].astype(np.float32) * 100 / 255
            f1, f2 = foot(L, m), foot(L2, cm)
            tot.append((s1 / s2, edge, sat1 / sat2, v1 / v2, ar1 / ar2, f1, f2))
            rows.append(f"| {kind} {lv} | {s1 / s2:.2f} | {edge:.1f} | {sat1:.2f}/{sat2:.2f} = {sat1 / sat2:.2f} | {v1 / v2:.2f} | {ar1:.2f}/{ar2:.2f} = {ar1 / ar2:.2f} | {f1:+.1f} / {f2:+.1f} |")
    a = np.array(tot)
    rows.append(f"| **mean** | {a[:, 0].mean():.2f} | {a[:, 1].mean():.1f} | {a[:, 2].mean():.2f} | {a[:, 3].mean():.2f} | {a[:, 4].mean():.2f} | {a[:, 5].mean():+.1f} / {a[:, 6].mean():+.1f} |")
    txt = "\n".join(rows)
    print(txt)
    if len(sys.argv) > 2:
        open(sys.argv[2], "w", encoding="utf-8").write(txt + "\n")


if __name__ == "__main__":
    main()
