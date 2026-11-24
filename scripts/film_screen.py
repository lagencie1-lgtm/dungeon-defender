"""Finds the phone screen in a film frame (the Studio window is not always the same size, so a fixed crop can miss):
Studio's own window is grey, the game is in colour; the screen is the box round the biggest colourful patch.
  from film_screen import screen_box; box = screen_box(frame_rgb_array)  -> (x0, y0, x1, y1)"""
import numpy as np
from scipy import ndimage


def screen_box(a):
    a = np.asarray(a)[..., :3].astype(float)
    mx, mn = a.max(-1), a.min(-1)
    colour = (mx - mn) > 40
    colour = ndimage.binary_closing(colour, iterations=6)
    lab, n = ndimage.label(colour)
    if n == 0:
        return None
    k = int(np.argmax(ndimage.sum(colour, lab, range(1, n + 1)))) + 1
    ys, xs = np.where(lab == k)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
