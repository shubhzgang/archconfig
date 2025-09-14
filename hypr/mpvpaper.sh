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
    # If a selection was made, retrieve the corresponding link
    # from the array and output it.
    echo "${options[$selected_key]}"
fi
