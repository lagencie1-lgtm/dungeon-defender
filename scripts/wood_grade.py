"""Colour correction of a painted sheet's wood toward the painting's wood (coordinator 2026-11-25, Storm planks "darker,
browner"): pixels in the red-brown wood band (OpenCV hue 3-16, saturated, mid dark) get the painting's median wood
saturation and value, by the ratio of the medians, blended in softly at the band's edges; stone, gold and the
violet runes are left alone.
  python scripts/wood_grade.py <sheet.png> <painting.png> [out]"""
import sys

import cv2
import numpy as np


def band(hsv):
    h, s, v = (hsv[..., i].astype(np.float32) for i in range(3))
    w = np.clip((h - 1) / 2, 0, 1) * np.clip((18 - h) / 2, 0, 1) * np.clip((s - 90) / 30, 0, 1) * np.clip((v - 30) / 15, 0, 1) * np.clip((215 - v) / 15, 0, 1)
    return w


def medians(hsv, w):
    m = w > 0.5
    return np.median(hsv[m][:, 1]), np.median(hsv[m][:, 2]), int(m.sum())


src, pic = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else src
img = cv2.imread(src, cv2.IMREAD_UNCHANGED)
hsv = cv2.cvtColor(img[..., :3], cv2.COLOR_BGR2HSV).astype(np.float32)
phsv = cv2.cvtColor(cv2.imread(pic)[..., :3], cv2.COLOR_BGR2HSV).astype(np.float32)
w = band(hsv)
s0, v0, n0 = medians(hsv, w)
s1, v1, n1 = medians(phsv, band(phsv))
g = hsv.copy()
g[..., 1] = np.clip(hsv[..., 1] * (s1 / s0), 0, 255)
g[..., 2] = np.clip(hsv[..., 2] * (v1 / v0), 0, 255)
mix = hsv * (1 - w[..., None]) + g * w[..., None]
rgb = cv2.cvtColor(mix.astype(np.uint8), cv2.COLOR_HSV2BGR)
if img.shape[2] == 4:
    rgb = np.dstack([rgb, img[..., 3]])
cv2.imwrite(out, rgb)
print(f"WOOD graded {out}: saturation x{s1 / s0:.2f}, value x{v1 / v0:.2f} ({n0} px)")
