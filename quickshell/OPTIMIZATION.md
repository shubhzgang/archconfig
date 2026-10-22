# Quickshell + Hyprland: optimization plan

Goal: smoother animations and less idle work. Trading disk space for speed is fine (pre-rendered
images, cached thumbnails, in-memory history).

## 0. Measure first
Run Quickshell with `QSG_RENDER_TIMING=1` and enable Hyprland's `debug:overlay`; record frame times
while opening each panel and while idle. Repeat after every step below and keep only what helps.

## 1. Biggest wins for animation smoothness

**1a. Pre-rendered shadows instead of live blur effects.**
Nearly every card has its own `layer` + `MultiEffect` shadow: stats cards, clipboard/live-wallpaper
rows, launcher search box and selected tile, calendar card, wallpaper thumbnails, the 10 workspace
dots. Each is an offscreen blur recomputed whenever its content changes (stats cards every second,
since their graphs redraw). Render each shadow style once into a small PNG (at startup or in a cache
directory) and draw it behind cards with a `BorderImage` (9-slice), via one reusable `ShadowBox`
component, like the old rofi `make-cards.py` did. Removes roughly 20-40 offscreen blur passes,
especially while scrolling lists and morphing panels.

**1b. Cheaper frame shadow.**
`FrameShadow.qml` blurs and masks a full 3840x2160 texture on every frame of every panel animation,
the single most expensive thing during a morph. Render it at half resolution (`layer.textureSize`,
4x fewer pixels, visually the same for a soft shadow). If that isn't enough, split it so only the area
around the moving panel is re-rendered.

**1c. Put the always-changing bar text on its own small surface.**
Everything is on one 3840x2160 surface. The clock (seconds) and the stats numbers update every
second, so the whole 4K surface is re-rendered and Hyprland recomputes the blur behind it every
second. Move the clock, workspace dots and stats numbers to a thin 48px surface; the big frame surface
then only redraws while a panel animates or the theme changes. Large drop in idle GPU and blur work,
and animations stop competing with the per-second redraws.

**1d. Cached wallpaper thumbnails.**
The wallpaper picker decodes each 4K JPEG whenever a thumbnail comes into view, causing pop-in and
stutter when moving fast. Generate ~720px thumbnails once into `~/.cache/qs-wallthumbs/`
(regenerated only for new or changed wallpapers) and keep about +-5 thumbnails loaded instead of
loading and unloading them.

## 2. Stop polling

**2a. Stats sampler: small updates instead of the full history.**
`sysstatsd.py` rewrites a 60 KB `state.json` (600 points x 6 series) every tick, and Quickshell
re-reads and parses it plus 4 small files on 1-second timers, even though sampling is every 2 s.
Write a small "latest values" file per tick; Quickshell keeps the history in memory and reads the
full history only at startup or after a sampling-settings change. React to file changes instead of
timers, and only update graphs while the panel is open (the bar numbers update regardless).

**2b. Theme: push instead of poll.**
Every 2 s the theme re-reads `colors.json` and the bar colors file and spawns `pgrep` to detect
mpvpaper. Have `wallpaper.sh` and `mpvpaper.sh` notify Quickshell over IPC (e.g. `theme reload`,
`theme live true/false`): instant updates, no 2 s lag, no constant process spawns. Only assign colors
that actually changed (graph colors are currently reassigned every couple of seconds, which redraws
every graph).

**2c. Pacman check.**
`checkupdates` runs every 30 s and syncs a copy of the package database over the network each time.
Every 30 minutes, plus right after an update is run.

## 3. Graphs
When the stats panel opens, all 7 canvases paint for the first time just as the content fades in,
which can hitch: keep them painted while hidden (at low frequency) or paint off the main thread
(`renderStrategy: Canvas.Threaded`). The network graph scale does `Math.max(...600 values)` twice per
update: keep a running maximum instead. If still costly, draw graphs with Shapes on the GPU.

## 4. Hyprland
- `WLR_DRM_NO_ATOMIC=1` is ignored by current Hyprland (aquamarine ignores `WLR_*`): remove it, or use
  the `AQ_*` equivalent if really needed.
- Try `cursor.no_hardware_cursors = false`: a hardware cursor is smoother and avoids redrawing under
  it (recent NVIDIA drivers support it; test first).
- `no_anim` layer rules for the `qs-*` surfaces, so Hyprland's 70% pop-in doesn't play when Quickshell
  restarts.
- `wallpaper.sh`: replace the full `hyprctl reload` with a targeted `hyprctl eval` for the border
  colors (avoids a reload stutter); run the independent steps (kitty, swaync, pywalfox, cava,
  OpenRGB) in parallel; drop the obsolete `rofi/make-cards.py`; OpenRGB launches an AppImage on every
  change, which is slow (its SDK server would be faster).

## 5. Consistency cleanups
- Shared animation timings (520/620 ms ease-out, 430/500 ms ease-in, content fade delays) in one
  place in `Theme.qml`, so every panel feels the same and is tunable from one spot.
- Calendar and launcher still fade content with `Behavior`s that pick the wrong delay when closing
  (fixed elsewhere with explicit open/close transitions): switch them over too.
- Clipboard: keep the last `cliphist list` and refresh it in the background, so opening is instant.
- `cacheBuffer` on the clipboard and live-wallpaper lists so scrolling never builds rows on the fly.

## Order
0 (baseline) -> 1a + 1b (shadows) -> 1c (bar surface) -> 1d (thumbnails) -> 2 + 3 (polling, graphs)
-> 4 (Hyprland) -> 5 (timings). 1a, 1b and 1d are self-contained and low-risk; 1c is the biggest
change (mostly moving existing items to another surface); the rest is small.
