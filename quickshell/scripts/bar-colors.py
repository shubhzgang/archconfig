#!/usr/bin/env python3
"""Write the Quickshell bar's dark, saturated gradient ends (and rofi's pale background).

CSS has no saturate(), so derive them from the active pywal colors (color1 and
color2, the window border hues): keep the hue, fix a low lightness for text
contrast and push saturation up. Output is read by quickshell/Theme.qml and kitty/gradient.py; rofi gets a pale
color1 -> color2 gradient (like the stats panel) as a window rule in colors-rofi-bar.rasi.
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

start, end = vivid_dark(colors["color1"]), vivid_dark(colors["color2"])

with open(f"{CACHE}/colors-waybar-bar.css", "w") as f:
    f.write(f"@define-color bar_start {start};\n@define-color bar_end {end};\n")

def light(hex_color):
    """Pale version (35% toward white), like the stats panel background."""
    rgb = [int(hex_color[i:i + 2], 16) for i in (1, 3, 5)]
    return "#{:02X}{:02X}{:02X}".format(*[round(c + (255 - c) * 0.35) for c in rgb])


with open(f"{CACHE}/colors-rofi-bar.rasi", "w") as f:
    f.write("window { background-image: linear-gradient(135, "
            f"{light(colors['color1'])}, {light(colors['color2'])}); }}\n")
