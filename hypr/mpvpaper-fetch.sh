#!/bin/bash
# Looks up a YouTube link for the Quickshell live-wallpaper panel: prints {"title", "thumb"} as JSON
# (thumb is a path relative to this directory) and exits 0, or exits 1 if the title can't be resolved.
# The title comes from yt-dlp; the thumbnail is saved in mpvpaper-thumbs/.
url="$1"
[ -n "$url" ] || exit 1
dir="$(dirname "$(readlink -f "$0")")"

info=$(yt-dlp -J --flat-playlist --playlist-items 1 --no-warnings "$url" 2>/dev/null) || exit 1
title=$(jq -r '.title // empty' <<<"$info")
[ -n "$title" ] || exit 1

# thumbnail candidates: the 16:9 one without black bars (for the video, or the playlist's first), then
# whatever yt-dlp reports (live streams have no mqdefault)
id=$(jq -r '.entries[0].id // .id // empty' <<<"$info")
candidates=()
[ -n "$id" ] && candidates+=("https://i.ytimg.com/vi/$id/mqdefault.jpg")
reported=$(jq -r '.thumbnail // .entries[0].thumbnail // (.entries[0].thumbnails // .thumbnails // [])[-1].url // empty' <<<"$info")
[ -n "$reported" ] && candidates+=("$reported")

thumb=""
name="mpvpaper-thumbs/$(printf '%s' "$url" | sha1sum | cut -c1-12).jpg"
mkdir -p "$dir/mpvpaper-thumbs"
for c in "${candidates[@]}"; do
    if curl -fsSL --max-time 10 -o "$dir/$name" "$c"; then thumb="$name"; break; fi
done

jq -nc --arg title "$title" --arg thumb "$thumb" '{title: $title, thumb: $thumb}'
