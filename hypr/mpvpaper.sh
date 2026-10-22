#!/bin/bash
# Plays the given link as the live wallpaper (the Quickshell live-wallpaper panel runs this; its
# links are in mpvpaper-links.json). Playlists are shuffled.
URL="$1"
[ -n "$URL" ] || { echo "usage: $0 <link>" >&2; exit 1; }

pkill -9 -x mpvpaper   # a plain kill leaves players that failed to load a link running
if [[ "$URL" == *"list="* ]]; then
    exec mpvpaper HDMI-A-1 -o --shuffle "$URL"
else
    exec mpvpaper HDMI-A-1 "$URL"
fi
