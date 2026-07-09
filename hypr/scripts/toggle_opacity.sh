#!/usr/bin/env bash

# Fetch the current global active opacity
CURRENT_OPACITY=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')

# Check if it is fully opaque (using awk for safe floating-point comparison)
IS_OPAQUE=$(awk -v op="$CURRENT_OPACITY" 'BEGIN { print (op >= 0.99) ? 1 : 0 }')

if [ "$IS_OPAQUE" -eq 1 ]; then
    # Revert to translucent defaults
    hyprctl keyword decoration:active_opacity 0.95
    hyprctl keyword decoration:inactive_opacity 0.6
else
    # Force all windows to be fully opaque
    hyprctl keyword decoration:active_opacity 1.0
    hyprctl keyword decoration:inactive_opacity 1.0
fi
