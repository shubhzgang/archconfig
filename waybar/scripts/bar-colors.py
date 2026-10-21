#!/usr/bin/env python3
"""Write dark, saturated gradient ends for waybar's left/right sections.

CSS has no saturate(), so derive them from the active pywal colors (color1 and
color2, the window border hues): keep the hue, fix a low lightness for text
contrast and push saturation up. Output is imported by waybar/style.css.
"""
import colorsys
import json
import os

CACHE = os.path.expanduser("~/.cache/wal")


def vivid_dark(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    rgb = colorsys.hls_to_rgb(h, 0.24, min(0.9, max(s * 1.3, 0.55)))
    return "#{:02X}{:02X}{:02X}".format(*[round(c * 255) for c in rgb])


with open(f"{CACHE}/colors.json") as f:
    colors = json.load(f)["colors"]

with open(f"{CACHE}/colors-waybar-bar.css", "w") as f:
    f.write(f"@define-color bar_start {vivid_dark(colors['color1'])};\n"
            f"@define-color bar_end {vivid_dark(colors['color2'])};\n")
