#!/bin/sh
# Left-click hook (see the non-consuming mouse bind in hyprland.lua).
# While rofi is open it holds the pointer, so the bar's Apps button can't receive the click that
# should close it. This runs on every left click and, if a launcher is open and the click landed on
# the Apps button, closes it. Does nothing otherwise (clicks that open the launcher are handled by
# Quickshell itself).
ps -C rofi -o stat= | grep -q '^[^Z]' || exit 0
pos=$(hyprctl cursorpos)          # "x, y"
x=${pos%%,*}
y=${pos##*, }
# Apps button: inside the 56px top band, near its left end
[ "$y" -lt 56 ] && [ "$x" -ge 14 ] && [ "$x" -lt 100 ] && pkill -x rofi
exit 0
