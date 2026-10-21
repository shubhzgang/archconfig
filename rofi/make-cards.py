#!/usr/bin/env python3
"""Render the card images rofi uses for entries (rofi has no box-shadow).

Each PNG is a pale card with a soft, spread-out shadow in a transparent margin, sized
to match the rofi element it backs (rofi stretches it to fit). The selected variant uses
the current wallpaper's color1. Sizes assume a 3840x2160 screen and the theme in
launcher.rasi / wallpaper.rasi; adjust SIZES if you change the layout.
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

CACHE = os.path.expanduser("~/.cache/wal")
CARD = (0xC3, 0xCA, 0xDB)
M = 12           # transparent margin around the card that holds the shadow
RADIUS = 10
SHADOW_ALPHA = 60
BLUR = 7
DROP = 3         # shadow sits a little below the card
SS = 3           # supersampling for smooth corners

SIZES = {        # name: (width, height) of the rofi element/widget the image backs
    "launcher": (749, 80),
    "input": (3010, 76),
    "wall": (240, 174),
}


def render(w, h, fill):
    W, H = w * SS, h * SS
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [M * SS, (M + DROP) * SS, W - M * SS, H - (M - DROP) * SS], RADIUS * SS, fill=SHADOW_ALPHA)
    shadow = shadow.filter(ImageFilter.GaussianBlur(BLUR * SS))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.putalpha(shadow)
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle(
        [M * SS, M * SS, W - M * SS, H - M * SS], RADIUS * SS, fill=fill + (255,))
    img = Image.alpha_composite(img, card)
    return img.resize((w, h), Image.LANCZOS)


with open(f"{CACHE}/colors.json") as f:
    color1 = json.load(f)["colors"]["color1"]
accent = tuple(int(color1[i:i + 2], 16) for i in (1, 3, 5))

for name, (w, h) in SIZES.items():
    render(w, h, CARD).save(f"{CACHE}/rofi-card-{name}.png")
    if name != "input":
        render(w, h, accent).save(f"{CACHE}/rofi-card-{name}-sel.png")
