#!/bin/bash
# Prints waybar JSON for workspace dot $1: class "active" and/or "empty".
n=$1
active=$(hyprctl -j activeworkspace | jq .id)
windows=$(hyprctl -j workspaces | jq --argjson n "$n" '[.[] | select(.id == $n)][0].windows // 0')
jq -nc --argjson n "$n" --argjson a "$active" --argjson w "$windows" \
    '{text: "", class: (["ws", if $a == $n then "active" else empty end, if $w == 0 then "empty" else empty end])}'
