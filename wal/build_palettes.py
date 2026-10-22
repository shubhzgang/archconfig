#!/usr/bin/env python3
"""Build wallpaper-schemes/<image>.json from the hand-picked palettes in palettes.json.

Usage: build_palettes.py [image name ...]     (default: every entry)

Each entry in palettes.json is
    "<image file name>": {
        "note":   what was seen in the image and why these colours,
        "colors": [color1 .. color6],
        "bg":     optional hex whose hue tints color0/7/8/15 (default: color2),
        "colorN": optional explicit override of any derived slot
    }
Roles (see hypr/wallpaper.sh, quickshell/Theme.qml):
    color1  most striking colour: active border, focused workspace pill, accent, bar centre
    color2  mood colour: inactive border, occupied workspace dots, bar ends
    color3  quiet colour: empty workspace dots
    color4  prompt path segment in the terminal; graphs
    color5-6  other colours of the image; graphs, terminal
    color7  text; color9 hover text / hyprlock+wlogout highlight (lighter color1)
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_schemes import lab_to_lch, lch_to_hex, rgb_to_oklab  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
WALL_DIR = os.path.expanduser("~/wallpapers/walls")
OUT_DIR = os.path.join(HERE, "wallpaper-schemes")


def lch(hex_color):
    rgb = np.array([int(hex_color[i:i + 2], 16) for i in (1, 3, 5)], float) / 255
    return lab_to_lch(rgb_to_oklab(rgb))


def visible(hex_color):
    """The picked color with its brightness kept in a range that reads on the dark bar and as a
    window border (a navy sky or a forest shadow would vanish); hue and chroma are kept."""
    L, C, h = lch(hex_color)
    if 0.55 <= L <= 0.88:
        return hex_color.upper()
    return lch_to_hex(min(max(L, 0.55), 0.88), C, h)


def full_colors(entry):
    """color0..color15 for one palettes.json entry."""
    main = [visible(c) for c in entry["colors"]]
    _, _, bg_h = lch(entry.get("bg", main[1]))
    colors = {"color0": lch_to_hex(0.17, 0.03, bg_h)}
    for i, c in enumerate(main, 1):
        colors[f"color{i}"] = c
    colors["color7"] = lch_to_hex(0.89, 0.03, bg_h)
    colors["color8"] = lch_to_hex(0.56, 0.03, bg_h)
    for i, c in enumerate(main):   # lighter versions (color9 is the hover / hyprlock / wlogout highlight)
        L, C, h = lch(c)
        colors[f"color{9 + i}"] = lch_to_hex(min(L + 0.1, 0.9), C, h)
    colors["color15"] = lch_to_hex(0.95, 0.02, bg_h)
    for k, v in entry.items():
        if k.startswith("color") and k != "colors":
            colors[k] = v.upper()
    return colors


def build(name, entry):
    colors = full_colors(entry)
    return {
        "wallpaper": os.path.join(WALL_DIR, name),
        "alpha": "100",
        "special": {"background": colors["color0"], "foreground": colors["color7"],
                    "cursor": colors["color7"]},
        "colors": colors,
    }


def main():
    palettes = json.load(open(os.path.join(HERE, "palettes.json")))
    for name in sys.argv[1:] or sorted(palettes):
        with open(os.path.join(OUT_DIR, name + ".json"), "w") as f:
            json.dump(build(name, palettes[name]), f, indent=4)
        print(name)


if __name__ == "__main__":
    main()
