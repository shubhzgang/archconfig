#!/usr/bin/env bash
# Increase or decrease the opacity of the currently active window.
# Usage: active_opacity.sh up | down
#
# Uses hyprctl eval with hl.dsp.window.set_prop because:
#   - hyprctl dispatch setprop is broken in Lua-config mode (0.55+)
#   - hyprctl setprop standalone also does not work with Lua config
# The correct prop name is "opacity" (with optional " override" suffix).

STEP=0.05
ADDRESS=$(hyprctl activewindow -j | jq -r '.address')

# Exit safely if no window is currently active
if [ "$ADDRESS" = "null" ] || [ -z "$ADDRESS" ]; then
    exit 0
fi

STATE_DIR="/tmp/hypr_opacity"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$ADDRESS"

# Assume fully opaque if we haven't tracked this window yet
if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
else
    CURRENT=1.0
fi

if [ "$1" = "up" ]; then
    NEW=$(awk "BEGIN {print $CURRENT + $STEP}")
elif [ "$1" = "down" ]; then
    NEW=$(awk "BEGIN {print $CURRENT - $STEP}")
else
    echo "Usage: $0 up|down" >&2
    exit 1
fi

# Constrain between 0.1 and 1.0
NEW=$(awk "BEGIN {if ($NEW > 1.0) print 1.0; else if ($NEW < 0.1) print 0.1; else print $NEW}")

# Save state and apply via hyprctl eval + Lua API.
# "opacity" prop with " override" suffix forces exact value instead of multiplier.
echo "$NEW" > "$STATE_FILE"
hyprctl eval "hl.dispatch(hl.dsp.window.set_prop({ window = 'address:$ADDRESS', prop = 'opacity', value = '$NEW override $NEW override' }))"
