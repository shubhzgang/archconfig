#!/usr/bin/env bash

# Set how much the opacity changes per keypress
STEP=0.05 

# Fetch current global opacity values
CURRENT_ACTIVE=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')
CURRENT_INACTIVE=$(hyprctl getoption decoration:inactive_opacity -j | jq -r '.float')

if [ "$1" == "up" ]; then
    NEW_ACTIVE=$(awk "BEGIN {print $CURRENT_ACTIVE + $STEP}")
    NEW_INACTIVE=$(awk "BEGIN {print $CURRENT_INACTIVE + $STEP}")
elif [ "$1" == "down" ]; then
    NEW_ACTIVE=$(awk "BEGIN {print $CURRENT_ACTIVE - $STEP}")
    NEW_INACTIVE=$(awk "BEGIN {print $CURRENT_INACTIVE - $STEP}")
fi

# Constrain the values between 0.1 (mostly transparent) and 1.0 (fully opaque)
NEW_ACTIVE=$(awk "BEGIN {if ($NEW_ACTIVE > 1.0) print 1.0; else if ($NEW_ACTIVE < 0.1) print 0.1; else print $NEW_ACTIVE}")
NEW_INACTIVE=$(awk "BEGIN {if ($NEW_INACTIVE > 1.0) print 1.0; else if ($NEW_INACTIVE < 0.1) print 0.1; else print $NEW_INACTIVE}")

# Apply the new values
hyprctl keyword decoration:active_opacity $NEW_ACTIVE
hyprctl keyword decoration:inactive_opacity $NEW_INACTIVE
