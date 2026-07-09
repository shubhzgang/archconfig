#!/bin/bash

# A script to select a link using wofi

# Use an associative array to map display names to links.
# Syntax: [Display Name]="Link"
declare -A options=(
    ["Rainy Jazz Cafe - Slow Jazz Music in Coffee Shop Ambience"]="https://www.youtube.com/watch?v=NJuSStkIZBg"
    ["4-HOUR STUDY WITH ME🌦️ / calm piano"]="https://www.youtube.com/watch?v=DXT9dF-WK-I"
    ["synthwave radio 🌌 - beats to chill/game to"]="https://www.youtube.com/watch?v=4xDzrJKXOOY"
    ["lofi hip hop radio - beats to relax/study to"]="https://www.youtube.com/watch?v=jfKfPfyJRdk"
    ["📚2-HOUR LATE NIGHT STUDY / gentle rain🌧 + lofi music / 50 minute Pomodoro / with timer+bell"]="https://www.youtube.com/watch?v=sca4VG9b0NY"
)

# Use printf to format the keys (display names) of the array,
# separated by newlines, and pipe them into wofi.
# The user's selection is stored in the 'selected_key' variable.
selected_key=$(printf "%s\n" "${!options[@]}" | wofi --height=80% --width=80% -p "Choose a link:" --dmenu)

# Check if the user made a selection (i.e., didn't cancel).
if [ -n "$selected_key" ]; then
    # Determine the URL based on whether it's an existing key or a raw string
    if [[ -v options[$selected_key] ]]; then
        URL="${options[$selected_key]}"
    else
        URL="$selected_key"
    fi

    # Check if the URL contains a playlist parameter
    if [[ "$URL" == *"list="* ]]; then
        # Output the mpv options flag (-o) with --shuffle, then the URL
        echo "-o --shuffle $URL"
    else
        # Output just the URL for standard videos
        echo "$URL"
    fi
fi
