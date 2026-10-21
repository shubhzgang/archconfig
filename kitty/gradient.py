#!/usr/bin/env python3
"""Render kitty's background gradient from the Quickshell bar-section colors.

Reads bar_start/bar_end (written by quickshell/scripts/bar-colors.py) and writes a
small diagonal-gradient PNG that kitty stretches over the window, plus the conf line pointing at it.
"""
import glob
import os
import re
import time

import numpy as np
from PIL import Image

CACHE = os.path.expanduser("~/.cache/wal")
SIZE = 256
DARKEN = 0.32  # kitty is mostly text: keep the gradient subtle

css = open(f"{CACHE}/colors-waybar-bar.css").read()
start, end = (np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)
              for h in (re.search(rf"bar_{n} #(\w{{6}})", css).group(1) for n in ("start", "end")))

t = (np.add.outer(np.arange(SIZE), np.arange(SIZE)) / (2 * (SIZE - 1)))[..., None]  # 0 top-left .. 1 bottom-right
img = ((start * (1 - t) + end * t) * DARKEN).round().astype("uint8")
# kitty caches background images by path, so write a fresh file name every time and
# point kitty at it through an included conf; then a config reload picks up changes.
for old in glob.glob(f"{CACHE}/kitty-gradient-*.png"):
    os.remove(old)
path = f"{CACHE}/kitty-gradient-{int(time.time())}.png"
Image.fromarray(img, "RGB").save(path)
with open(f"{CACHE}/kitty-gradient.conf", "w") as f:
    f.write(f"background_image {path}\n")
