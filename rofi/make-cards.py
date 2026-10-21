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
SS = 3           # supersampling for smooth corners

TILE = 44        # app-icon tile in the launcher: a recessed rounded square behind each icon
TILE_RADIUS = 10
THUMB = (392, 260)   # wallpaper thumbnail size (2x display); hypr/wallpaper.sh rounds each
THUMB_RADIUS = 20    # thumbnail with the mask and sets it on the shadow, so it looks like a photo
THUMB_MARGIN = 12    # lying on the card: same corner radius as the cards, with a soft shadow
THUMB_SHADOW_ALPHA = 80
THUMB_SHADOW_BLUR = 8
THUMB_SHADOW_DROP = 4

SIZES = {        # name: (width, height, margin) of the rofi element/widget the image backs;
    "launcher": (749, 80, M),        # a smaller margin gives a bigger card in the same cell, and
    "input": (3010, 76, M),          # the shadow blur/drop shrink with it to fit the margin
    "wall": (240, 174, 7),
}

# Selected card: rofi can't move an entry's content on selection, so instead of lifting, the card
# grows a little on every side (content stays centered) and casts a darker, lower shadow.
# name: (grow px, shadow alpha, blur, drop) -- all must fit inside that image's margin.
SELECTED = {
    "launcher": (3, 190, 3.0, 4),
    "wall": (2, 170, 2.0, 3),
}


def render(w, h, fill, alpha=SHADOW_ALPHA, blur=BLUR, drop=DROP, grow=0, m=M, exact=False):
    if not exact:  # normal cards: shrink blur/drop along with a smaller margin
        scale = m / M
        blur, drop = blur * scale, drop * scale
    W, H = w * SS, h * SS
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(m - grow) * SS, round((m - grow + drop) * SS), W - (m - grow) * SS, H - round((m - grow - drop) * SS)],
        (RADIUS + grow) * SS, fill=alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur * SS))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.putalpha(shadow)
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle(
        [(m - grow) * SS, (m - grow) * SS, W - (m - grow) * SS, H - (m - grow) * SS], (RADIUS + grow) * SS, fill=fill + (255,))
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
    if name in SELECTED:
        grow, alpha, blur, drop = SELECTED[name]
        render(w, h, accent, alpha, blur, drop, grow, m, exact=True).save(f"{CACHE}/rofi-card-{name}-sel.png")

_, tile_shading = recess(TILE, TILE, TILE_RADIUS, 2, 1.5, 0.6, 0.45)
tile_shading.save(f"{CACHE}/rofi-icon-tile.png")  # no fill: the tile is the card's own color

def photo_assets():
    """Rounded-corner mask for a thumbnail, and the canvas-size shadow it sits on."""
    w, h = THUMB
    W, H = w + 2 * THUMB_MARGIN, h + 2 * THUMB_MARGIN
    mask = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], THUMB_RADIUS * SS, fill=255)
    shadow = Image.new("L", (W * SS, H * SS), 0)
    m = THUMB_MARGIN * SS
    ImageDraw.Draw(shadow).rounded_rectangle(
        [m, m + THUMB_SHADOW_DROP * SS, W * SS - m - 1, H * SS - m - 1 + THUMB_SHADOW_DROP * SS],
        THUMB_RADIUS * SS, fill=THUMB_SHADOW_ALPHA)
    shadow = shadow.filter(ImageFilter.GaussianBlur(THUMB_SHADOW_BLUR * SS))
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    layer.putalpha(shadow)
    return mask.resize((w, h), Image.LANCZOS), layer.resize((W, H), Image.LANCZOS)


thumb_mask, thumb_shadow = photo_assets()
thumb_mask.save(f"{CACHE}/rofi-thumb-mask.png")
thumb_shadow.save(f"{CACHE}/rofi-thumb-shadow.png")
