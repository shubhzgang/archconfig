#!/usr/bin/env python3
"""Write a pywal scheme (JSON) made from one or two picked colors instead of a wallpaper.

Usage: swatch_scheme.py <out.json> <wallpaper> <harmony> <#color> [#color2]
       swatch_scheme.py --preview <#color>     color1..color3 of each harmony, as JSON (the picker shows them)

One color is grown into color1..color6 by a color harmony (monochrome, complementary, split,
analogous, triadic) on the OKLCH hue wheel; two colors are kept as color1 and color2 and the rest is
filled in between them. build_palettes.py then derives color0..color15 the same way as for the
hand-picked wallpaper palettes. Used by hypr/wallpaper.sh for the Quickshell picker's color swatches
and plain-color wallpapers.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_palettes import full_colors, lch  # noqa: E402
from gen_schemes import lch_to_hex  # noqa: E402

# hue offsets (degrees) of color1..color6 from the picked color, and how much chroma/lightness each
# keeps or gains: (offset, chroma factor, lightness change)
HARMONIES = {
    "monochrome":    [(0, 1, 0), (0, 0.7, -0.12), (0, 0.45, 0.1), (0, 0.5, -0.05), (0, 0.85, 0.05), (0, 0.6, -0.18)],
    "complementary": [(0, 1, 0), (180, 1, 0), (0, 0.45, 0), (180, 0.8, 0.08), (0, 0.8, 0.08), (180, 0.45, 0)],
    "split":         [(0, 1, 0), (150, 1, 0), (210, 1, 0), (0, 0.45, 0), (150, 0.8, 0.08), (210, 0.8, 0.08)],
    "analogous":     [(0, 1, 0), (30, 1, 0), (-30, 1, 0), (60, 0.6, 0.05), (0, 0.45, 0), (30, 0.8, 0.08)],
    "triadic":       [(0, 1, 0), (120, 1, 0), (240, 1, 0), (0, 0.45, 0), (120, 0.8, 0.08), (240, 0.8, 0.08)],
}


def shifted(L, C, h, offset, chroma, light):
    return lch_to_hex(L + light, C * chroma, h + math.radians(offset))


def six_colors(colors, harmony):
    if len(colors) == 1:
        L, C, h = lch(colors[0])
        return [shifted(L, C, h, *step) for step in HARMONIES[harmony]]
    (L1, C1, h1), (L2, C2, h2) = lch(colors[0]), lch(colors[1])
    # the hue halfway between the two, the short way round
    mid = math.atan2(math.sin(h1) + math.sin(h2), math.cos(h1) + math.cos(h2))
    Lm, Cm = (L1 + L2) / 2, (C1 + C2) / 2
    return [colors[0], colors[1], lch_to_hex(Lm, Cm * 0.45, mid),
            shifted(L1, C1, h1, 0, 0.8, 0.08), shifted(L2, C2, h2, 0, 0.8, 0.08), lch_to_hex(Lm, Cm, mid)]


def main():
    if sys.argv[1] == "--preview":
        color = sys.argv[2].upper()
        print(json.dumps({h: [full_colors({"colors": six_colors([color], h), "bg": color})[f"color{i}"] for i in (1, 2, 3)]
                          for h in HARMONIES}))
        return
    out, wallpaper, harmony, *colors = sys.argv[1:]
    colors = [c.upper() for c in colors]
    # the second color tints the background (as `bg` does in palettes.json); a single color tints it itself
    full = full_colors({"colors": six_colors(colors, harmony), "bg": colors[-1]})
    # a black (OLED black, matte black): the background is that black itself, so the terminal and
    # everything else on it are the same one black as the wallpaper
    L, C, _ = lch(colors[0])
    if len(colors) == 1 and C < 0.02 and L < 0.3:
        # (and its text is plain grey: a black has no real hue to tint it with)
        full.update(color0=colors[0], color7="#E5E5E7", color8="#8E8E93", color15="#F2F2F7")
    scheme = {
        "wallpaper": wallpaper,
        "alpha": "100",
        "special": {"background": full["color0"], "foreground": full["color7"], "cursor": full["color7"]},
        "colors": full,
    }
    with open(out, "w") as f:
        json.dump(scheme, f, indent=4)


if __name__ == "__main__":
    main()
