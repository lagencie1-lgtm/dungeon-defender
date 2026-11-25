"""The gold-trim rule on a painted gold sheet (coordinator 2026-11-25): keeps the painter's light and shade on the
gold (its highlights and the dark edges of each band) but takes out the small noise that read as popcorn: a median
filter, then a soft blur; hue held to the gold family.
  python scripts/gold_smooth.py <painted gold sheet> [out]"""
import sys

import cv2
import numpy as np

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else src
img = cv2.imread(src, cv2.IMREAD_UNCHANGED)
rgb = img[..., :3]
sm = cv2.medianBlur(rgb, 7)
sm = cv2.GaussianBlur(sm, (0, 0), 2.0)
hsv = cv2.cvtColor(sm, cv2.COLOR_BGR2HSV).astype(np.float32)
hsv[..., 0] = np.clip(hsv[..., 0], 14, 24)   # (OpenCV hue 14-24: orange gold to yellow gold)
sm = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)
if img.shape[2] == 4:
    sm = np.dstack([sm, img[..., 3]])
cv2.imwrite(out, sm)
print("GOLD smoothed", out)
