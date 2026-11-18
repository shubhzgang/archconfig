# Mood blobs in a palette's colors, for Hyperion (sent with the desktop theme's colors by
# ~/.config/hypr/wallpaper.sh). As Hyperion's own mood blobs: blobs of light with dark gaps between
# them move round the LEDs, lit by colors that slowly turn round under them; here the colors are the
# palette's, easing from each into the next once round the LEDs, instead of shades of one hue.
#   colors        [[r, g, b], ...]  the palette, in order
#   blobs         how many blobs
#   rotationTime  how slowly they move (as in Hyperion's own: seconds per half turn)
#   reverse       the other way round
import hyperion
import math
import time

colors = [tuple(int(v) for v in c[:3]) for c in hyperion.args.get('colors', [])] or [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
blobs = max(1, int(hyperion.args.get('blobs', 5)))
rotationTime = max(0.1, float(hyperion.args.get('rotationTime', 60)))
reverse = bool(hyperion.args.get('reverse', False))
ledCount = hyperion.ledCount


def mix(t):
    """The color at t (0 to 1) on a loop through the palette."""
    x = (t % 1.0) * len(colors)
    i = int(x)
    f = x - i
    f = f * f * (3 - 2 * f)   # ease, so each color holds a while before it turns into the next
    a, b = colors[i % len(colors)], colors[(i + 1) % len(colors)]
    return [a[k] + (b[k] - a[k]) * f for k in range(3)]


# the colors under the blobs, once round the LEDs
colorData = [mix(i / ledCount) for i in range(ledCount)]

# the blobs move on by this much every step, and the colors one LED every other step
sleepTime = 0.1
amplitudePhaseIncrement = blobs * math.pi * sleepTime / rotationTime
colorDataIncrement = 1
if reverse:
    amplitudePhaseIncrement = -amplitudePhaseIncrement
    colorDataIncrement = -colorDataIncrement

amplitudePhase = 0.0
rotateColors = False
while not hyperion.abort():
    ledData = bytearray()
    for i in range(ledCount):
        # half of each blob's stretch is lit (a sine's bump), the other half dark
        amplitude = max(0.0, math.sin(-amplitudePhase + 2 * math.pi * blobs * i / ledCount))
        ledData += bytearray(int(c * amplitude) for c in colorData[i])
    hyperion.setColor(ledData)

    amplitudePhase = (amplitudePhase + amplitudePhaseIncrement) % (2 * math.pi)
    if rotateColors:
        colorData = colorData[-colorDataIncrement:] + colorData[:-colorDataIncrement]
    rotateColors = not rotateColors
    time.sleep(sleepTime)
