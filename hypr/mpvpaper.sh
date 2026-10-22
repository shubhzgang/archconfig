#!/bin/bash
# Plays the given link as the live wallpaper (the Quickshell live-wallpaper panel runs this; its
# links are in mpvpaper-links.json). Playlists are shuffled.
#
# Quickshell's colors go neutral while a live wallpaper plays: it is told to check when the player
# starts, and again when it ends (stopped, replaced by another link, or killed by wallpaper.sh).
URL="$1"
[ -n "$URL" ] || { echo "usage: $0 <link>" >&2; exit 1; }

pkill -9 -x mpvpaper   # a plain kill leaves players that failed to load a link running
if [[ "$URL" == *"list="* ]]; then
    mpvpaper HDMI-A-1 -o --shuffle "$URL" &
else
    mpvpaper HDMI-A-1 "$URL" &
fi
qs ipc call theme checkLive
wait
qs ipc call theme checkLive
