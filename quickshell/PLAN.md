# Quickshell shell: plan

Goal: a Caelestia-style shell where the bar and panels are one morphing shape drawn by Quickshell
(waybar can't merge with panels, so it is retired section by section).

1. **Prototype (this directory):** top-right stats text that morphs into the full stats panel in
   the same corner. Waybar stays untouched underneath; the overlay covers its right section.
2. **Data + colors:** QML reads the shared sampler files (`$XDG_RUNTIME_DIR/sysstats/*.json`) and the
   current wal colors (`~/.cache/wal/colors.json`, `colors-waybar-bar.css`).
3. **Stats panel in QML:** stacked cards, interval/points options, time-ago labels, gradient,
   mirrored network graph.
4. **Right section** done properly (remove the stats modules from waybar's right side).
5. **Center section:** workspace dots (click switches; Lua dispatch via
   `hyprctl dispatch 'hl.dsp.focus({ workspace = N })'`).
6. **Overview (macOS Mission Control style):** Shift+click on the workspace dots opens a grid of all
   workspaces with live window thumbnails (Quickshell `ScreencopyView` + `ToplevelManager`);
   click to switch, drag windows between workspaces, Escape closes. Grows out of the center
   section like the other panels.
7. **Left section:** notifications button, clock, pacman, tray, bluetooth, network.
8. **Retire waybar** (done: waybar is removed; sections 1-5 and 7 are ported; step 6, the overview, is still to do); Quickshell reserves the bar space; the top-left hot corner is gone (an Apps button replaced it) and `ws-watch.py` is retired.
9. **Optional:** animated launcher / wallpaper picker / notifications as panels in the same shape.

Known risks: Hyprland's Lua config rejects legacy `dispatch workspace N` (wrap commands in `hl.dsp.*`);
live capture cost on NVIDIA at 4K (refresh only while the overview is open if needed).
