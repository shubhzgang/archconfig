#!/usr/bin/env bash

STEP=0.05
ADDRESS=$(hyprctl activewindow -j | jq -r '.address')

# Exit safely if no window is currently active
if [ "$ADDRESS" == "null" ] || [ -z "$ADDRESS" ]; then
    exit 0
fi

STATE_DIR="/tmp/hypr_opacity"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$ADDRESS"

# Assume alpha is 1.0 if we haven't overridden it yet
if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
else
    CURRENT=1.0
fi

if [ "$1" == "up" ]; then
    NEW=$(awk "BEGIN {print $CURRENT + $STEP}")
elif [ "$1" == "down" ]; then
    NEW=$(awk "BEGIN {print $CURRENT - $STEP}")
fi

# Constrain between 0.1 and 1.0
NEW=$(awk "BEGIN {if ($NEW > 1.0) print 1.0; else if ($NEW < 0.1) print 0.1; else print $NEW}")

# Save state and apply the alpha property
echo "$NEW" > "$STATE_FILE"
hyprctl dispatch setprop address:$ADDRESS opacity "$NEW override $NEW override"
