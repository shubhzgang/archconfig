#!/usr/bin/env python3
"""Generate one pywal scheme (JSON) per wallpaper.

Usage: gen_schemes.py [wallpaper_dir] [out_dir]

Unlike pywal's own backends, which favour the most *common* colors (a red car
on a grey road comes out grey), accents here are scored by population AND
chroma, so small vivid subjects win. Output files are consumed by
`wal --theme <file>` in hypr/wallpaper.sh.
"""
import colorsys
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HOME = os.path.expanduser("~")
WALL_DIR = sys.argv[1] if len(sys.argv) > 1 else f"{HOME}/wallpapers/walls"
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else f"{HOME}/.config/wal/wallpaper-schemes"
EXTS = (".jpg", ".jpeg", ".png")


# ---- OKLab helpers ---------------------------------------------------------
def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def rgb_to_oklab(rgb):
    r, g, b = [srgb_to_lin(rgb[..., i]) for i in range(3)]
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.stack([
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ], -1)


def oklab_to_rgb_raw(lab):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def lch_to_hex(L, C, h):
    """OKLCH -> hex, reducing chroma until the color fits in sRGB."""
    for _ in range(40):
        lin = oklab_to_rgb_raw((L, C * math.cos(h), C * math.sin(h)))
        if all(-1e-4 <= v <= 1 + 1e-4 for v in lin):
            break
        C *= 0.93
    rgb = lin_to_srgb(np.array(lin))
    return "#{:02X}{:02X}{:02X}".format(*[int(round(v * 255)) for v in rgb])


def lab_to_lch(lab):
    return lab[0], math.hypot(lab[1], lab[2]), math.atan2(lab[2], lab[1])


# ---- palette extraction ----------------------------------------------------
def kmeans(x, k, iters=20, seed=0):
    rng = np.random.default_rng(seed)
    cent = x[rng.choice(len(x), k, replace=False)]
    for _ in range(iters):
        d = ((x[:, None, :] - cent[None]) ** 2).sum(-1)
        lbl = d.argmin(1)
        for i in range(k):
            sel = x[lbl == i]
            if len(sel):
                cent[i] = sel.mean(0)
    return cent, np.bincount(lbl, minlength=k) / len(x)


def pick_accents(path, n=6):
    img = Image.open(path).convert("RGB")
    img.thumbnail((200, 200))
    px = np.asarray(img, dtype=np.float64).reshape(-1, 3) / 255
    lab = rgb_to_oklab(px)
    cent, pop = kmeans(lab, 24)

    cands = []
    for c, p in zip(cent, pop):
        L, C, h = lab_to_lch(c)
        if p < 0.008 or L < 0.2 or L > 0.95:
            continue
        cands.append((math.sqrt(p) * (C + 0.03) ** 1.2, c))
    cands.sort(key=lambda t: -t[0])
    if not cands:  # nearly black/white image
        cands = [(1, np.array([0.6, 0.0, 0.0]))]

    picks = []
    for thr in (0.12, 0.09, 0.06, 0.04, 0.025):
        for _, c in cands:
            if len(picks) >= n:
                break
            if all(np.linalg.norm(c - q) > thr for q in picks):
                picks.append(c)
    # still short (flat, near-monochrome image): spin extra hues off the top pick
    L0, C0, h0 = lab_to_lch(picks[0])
    k = 1
    while len(picks) < n:
        h = h0 + math.radians(22) * (k if k % 2 else -k)
        picks.append(np.array([L0, C0 * math.cos(h), C0 * math.sin(h)]))
        k += 1
    return [lab_to_lch(c) for c in picks], lab_to_lch(picks[0])


def build_scheme(path):
    accents, (_, _, bg_h) = pick_accents(path)

    def norm(L, C, h):
        achromatic = C < 0.03
        C = max(C, 0.02 if achromatic else 0.08)
        return min(max(L, 0.58), 0.82), min(C, 0.2), h

    base = [norm(*a) for a in accents]  # color1..color6
    colors = {"color0": lch_to_hex(0.17, 0.035, bg_h)}
    for i, (L, C, h) in enumerate(base, 1):
        colors[f"color{i}"] = lch_to_hex(L, C, h)
    colors["color7"] = lch_to_hex(0.86, 0.025, bg_h)
    colors["color8"] = lch_to_hex(0.55, 0.03, bg_h)
    # color9 backs the highlight/text color in wofi, hyprlock, wlogout: keep it
    # recognisably color1's hue but lighter.
    L, C, h = base[0]
    colors["color9"] = lch_to_hex(min(L + 0.1, 0.9), C, h)
    for i in range(1, 6):
        L, C, h = base[i]
        colors[f"color{9 + i}"] = lch_to_hex(min(L + 0.1, 0.9), C, h)
    colors["color15"] = lch_to_hex(0.94, 0.02, bg_h)
    return {
        "wallpaper": path,
        "alpha": "100",
        "special": {
            "background": colors["color0"],
            "foreground": colors["color7"],
            "cursor": colors["color7"],
        },
        "colors": colors,
    }


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in sorted(os.listdir(WALL_DIR)):
        if not name.lower().endswith(EXTS):
            continue
        path = os.path.join(WALL_DIR, name)
        out = os.path.join(OUT_DIR, name + ".json")
        with open(out, "w") as f:
            json.dump(build_scheme(path), f, indent=4)
        print(name)


if __name__ == "__main__":
    main()
