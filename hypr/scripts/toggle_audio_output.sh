#!/usr/bin/env bash

# Switch the Ryzen HD Audio card between the 5.1 speakers (TOSLINK, AC3) and the headphones (rear line out).
# With no argument it toggles; "speakers" or "headphones" picks one (the media panel's buttons).
CARD=alsa_card.pci-0000_17_00.6
SPEAKERS=output:iec958-ac3-surround-51
HEADPHONES=output:analog-stereo+input:analog-stereo

TARGET=$1
if [ -z "$TARGET" ]; then
    ACTIVE=$(pactl list cards | awk -v card="$CARD" '$1 == "Name:" { in_card = ($2 == card) } in_card && /Active Profile:/ { print $3; exit }')
    [ "$ACTIVE" = "$SPEAKERS" ] && TARGET=headphones || TARGET=speakers
fi

if [ "$TARGET" = "headphones" ]; then
    pactl set-card-profile "$CARD" "$HEADPHONES" && notify-send -a audio "Audio output" "Headphones"
else
    pactl set-card-profile "$CARD" "$SPEAKERS" && notify-send -a audio "Audio output" "5.1 Speakers"
fi
