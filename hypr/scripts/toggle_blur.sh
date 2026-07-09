#!/usr/bin/env bash

# Fetch the current state of blur (1 for enabled, 0 for disabled)
BLUR_STATE=$(hyprctl getoption decoration:blur:enabled -j | jq -r '.int')

if [ "$BLUR_STATE" -eq 1 ]; then
    hyprctl keyword decoration:blur:enabled 0
else
    hyprctl keyword decoration:blur:enabled 1
fi
