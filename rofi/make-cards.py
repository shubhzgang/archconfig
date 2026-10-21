#!/usr/bin/env python3
"""Render the card images rofi uses for entries (rofi has no box-shadow).

Each PNG is a pale card with a soft, spread-out shadow in a transparent margin, sized
to match the rofi element it backs (rofi stretches it to fit). The selected variant uses
the current wallpaper's color1. Sizes assume a 3840x2160 screen and the theme in
launcher.rasi / wallpaper.rasi; adjust SIZES if you change the layout.
"""
import json
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

CACHE = os.path.expanduser("~/.cache/wal")
CARD = (0xC3, 0xCA, 0xDB)
M = 12           # transparent margin around the card that holds the shadow
RADIUS = 10
SHADOW_ALPHA = 60
BLUR = 7
DROP = 3         # shadow sits a little below the card
SEL_SHADOW_ALPHA = 200  # the selected card is picked up: darker shadow that sits lower...
SEL_BLUR = 5
SEL_DROP = 9
SEL_LIFT = 6            # ...and the card itself moves up (launcher/wallpaper .rasi shift the content to match)
SS = 3           # supersampling for smooth corners

TILE = 44        # app-icon tile in the launcher: a recessed rounded square behind each icon
TILE_RADIUS = 10
THUMB = (392, 260)   # wallpaper thumbnail size (2x display); hypr/wallpaper.sh composites these
THUMB_RADIUS = 16    # onto each thumbnail so it looks recessed in its card

SIZES = {        # name: (width, height, margin) of the rofi element/widget the image backs;
    "launcher": (749, 80, M),        # a smaller margin gives a bigger card in the same cell, and
    "input": (3010, 76, M),          # the shadow blur/drop shrink with it to fit the margin
    "wall": (240, 174, 7),
}


def render(w, h, fill, alpha=SHADOW_ALPHA, blur=BLUR, drop=DROP, lift=0, m=M):
    scale = m / M
    blur, drop = blur * scale, drop * scale
    W, H = w * SS, h * SS
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [m * SS, round((m + drop - lift) * SS), W - m * SS, H - round((m - drop + lift) * SS)], RADIUS * SS, fill=alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur * SS))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.putalpha(shadow)
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle(
        [m * SS, (m - lift) * SS, W - m * SS, H - (m + lift) * SS], RADIUS * SS, fill=fill + (255,))
    img = Image.alpha_composite(img, card)
    return img.resize((w, h), Image.LANCZOS)


def recess(w, h, radius, dark_dy, blur_px, dark, light):
    """(mask, shading) for a rounded rectangle that looks pressed into its surroundings, like
    waybar's empty workspace dots: a dark inner shadow along the top, a faint light edge along
    the bottom. The shading is translucent, so it works over any color or image."""
    pad = 6 * SS  # room outside the shape: the inner shadows are cast by that outside area
    W, H = w * SS + 2 * pad, h * SS + 2 * pad
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([pad, pad, W - pad - 1, H - pad - 1], radius * SS, fill=255)
    blur = ImageFilter.GaussianBlur(blur_px * SS)

    def inner(offset_y, strength):  # dark/light band hugging one inside edge of the shape
        band = ImageChops.offset(ImageChops.invert(mask), 0, round(offset_y * SS)).filter(blur)
        return ImageChops.multiply(band, mask).point(lambda v: int(v * strength))

    shading = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for color, alpha in (((0, 0, 0), inner(dark_dy, dark)),          # inset shadow, top
                         ((255, 255, 255), inner(-dark_dy / 2, light))):  # inset highlight, bottom
        layer = Image.new("RGBA", (W, H), color + (0,))
        layer.putalpha(alpha)
        shading = Image.alpha_composite(shading, layer)

    def finish(img):
        return img.crop((pad, pad, W - pad, H - pad)).resize((w, h), Image.LANCZOS)

    return finish(mask), finish(shading)


with open(f"{CACHE}/colors.json") as f:
    color1 = json.load(f)["colors"]["color1"]
accent = tuple(int(color1[i:i + 2], 16) for i in (1, 3, 5))

for name, (w, h, m) in SIZES.items():
    render(w, h, CARD, m=m).save(f"{CACHE}/rofi-card-{name}.png")
    if name != "input":
        render(w, h, accent, SEL_SHADOW_ALPHA, SEL_BLUR, SEL_DROP, SEL_LIFT, m).save(
            f"{CACHE}/rofi-card-{name}-sel.png")

_, tile_shading = recess(TILE, TILE, TILE_RADIUS, 2, 1.5, 0.6, 0.45)
tile_shading.save(f"{CACHE}/rofi-icon-tile.png")  # no fill: the tile is the card's own color

thumb_mask, thumb_shading = recess(*THUMB, THUMB_RADIUS, 4, 3.5, 0.7, 0.4)
thumb_mask.save(f"{CACHE}/rofi-thumb-mask.png")
thumb_shading.save(f"{CACHE}/rofi-thumb-shade.png")
