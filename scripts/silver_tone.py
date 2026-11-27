"""Silver kept silver after the repaint (coordinator 2026-11-25, Frost level 3's arch had turned beige): a painted
silver sheet keeps its light and shade (value, softened) but takes a cool grey-white colour (a faint blue hue, low
saturation), with its highlights lifted a little.
  python scripts/silver_tone.py <painted silver sheet> [out]"""
import sys

import cv2
import numpy as np

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else src
img = cv2.imread(src, cv2.IMREAD_UNCHANGED)
sm = cv2.GaussianBlur(cv2.medianBlur(img[..., :3], 5), (0, 0), 1.5)
hsv = cv2.cvtColor(sm, cv2.COLOR_BGR2HSV).astype(np.float32)
hsv[..., 0] = 105                                   # (a faint cool blue)
hsv[..., 1] = np.clip(hsv[..., 1] * 0.25, 8, 28)
v = hsv[..., 2]
hsv[..., 2] = np.clip(70 + v * 0.75 + np.clip(v - 170, 0, None) * 0.5, 0, 255)   # (grey-white, highlights lifted)
rgb = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)
if img.shape[2] == 4:
    rgb = np.dstack([rgb, img[..., 3]])
cv2.imwrite(out, rgb)
print("SILVER toned", out)
