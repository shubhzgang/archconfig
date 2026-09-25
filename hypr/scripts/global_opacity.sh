#!/usr/bin/env bash
# Increase or decrease global active+inactive opacity for all windows.
# Uses hyprctl eval (Lua) because hyprctl keyword doesn't work with Lua configs.
# Usage: global_opacity.sh up | down

STEP=0.05

CURRENT_ACTIVE=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')
CURRENT_INACTIVE=$(hyprctl getoption decoration:inactive_opacity -j | jq -r '.float')

if [ "$1" = "up" ]; then
    NEW_ACTIVE=$(awk "BEGIN {print $CURRENT_ACTIVE + $STEP}")
    NEW_INACTIVE=$(awk "BEGIN {print $CURRENT_INACTIVE + $STEP}")
elif [ "$1" = "down" ]; then
    NEW_ACTIVE=$(awk "BEGIN {print $CURRENT_ACTIVE - $STEP}")
    NEW_INACTIVE=$(awk "BEGIN {print $CURRENT_INACTIVE - $STEP}")
else
    echo "Usage: $0 up|down" >&2
    exit 1
fi

# Constrain between 0.1 and 1.0
NEW_ACTIVE=$(awk "BEGIN {if ($NEW_ACTIVE > 1.0) print 1.0; else if ($NEW_ACTIVE < 0.1) print 0.1; else print $NEW_ACTIVE}")
NEW_INACTIVE=$(awk "BEGIN {if ($NEW_INACTIVE > 1.0) print 1.0; else if ($NEW_INACTIVE < 0.1) print 0.1; else print $NEW_INACTIVE}")

hyprctl eval "hl.config({ decoration = { active_opacity = $NEW_ACTIVE, inactive_opacity = $NEW_INACTIVE } })"
