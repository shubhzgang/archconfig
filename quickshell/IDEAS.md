# Quickshell shell: ideas for later

## Could move into Quickshell

1. **Notifications (swaync).** The biggest outside piece left. Popups slide out of the frame like
   the other panels, and a history panel sits behind a bell in the left band or the bar. swaync has
   no config dir, so it is the only part of the desktop that doesn't take the wal colors.
2. **Audio mixer (pulsemixer on Super+G, pavucontrol on Super+O).** One audio panel that reuses the
   media panel's per-app volume and output pieces. It shows output and input devices with their
   volumes, and each app's volume and output. Clicking the volume in the bar opens it.
   It can cover everything pavucontrol does:

   | pavucontrol tab | What it has | How the panel would do it |
   |---|---|---|
   | Playback | Each app's volume, mute and output device | `Quickshell.Services.Pipewire` (the media panel already does this) |
   | Recording | Each app's microphone input and which device it uses | Pipewire, as for playback |
   | Output devices | Volume, mute, per-channel balance, default device | Pipewire (`preferredDefaultAudioSink`, `volumes`) |
   | | Port (headphones vs. speakers on one card) | `pactl set-sink-port` |
   | Input devices | Volume, mute, default device, live level meter | Pipewire (`preferredDefaultAudioSource`, the peak monitor) |
   | Configuration | Each card's profile (stereo, 5.1, digital out, off) | `pactl set-card-profile` |

   There are three cards here: one on digital stereo (`output:iec958-stereo`) and two set to off,
   so the profile switching matters. Rarely used options (latency offsets) stay in pavucontrol,
   behind a small "Open pavucontrol" link in the panel's corner.
3. **Network and Bluetooth (`kitty nmtui`, `blueman-manager`).** Clicking the bar icons opens
   separate windows today. `Quickshell.Networking` and `Quickshell.Bluetooth` are already imported,
   so a small panel under the bar could list Wi-Fi networks and paired devices with connect buttons.
4. **Lock screen (hyprlock).** Quickshell's `WlSessionLock` can draw the lock screen with the same
   frame, colors, clock and media strip. hyprlock works fine, so this is mostly about looks.
5. **Pacman updates.** Clicking the count opens kitty with `yay -Syu`. A panel could list the
   pending updates first, with an "Update" button that still runs yay in kitty.

Keep as they are: wpaperd (the wallpaper pipeline depends on it), hypridle (it has no UI), the
screenshot tools and cliphist (it already feeds the clipboard panel).

## New ideas

- **Volume and brightness popup.** The volume and brightness keys show nothing on screen today. A
  thin slider could slide out of the frame edge for a second and then hide.
- **Keybind cheat sheet.** A panel listing the binds, read from `hypr/hyprland.lua` so it stays
  up to date.
- **Screenshot menu.** One panel for region, window or screen, with copy, save and edit in satty.
  It would replace the five separate screenshot binds.
- **Do-not-disturb and idle-inhibit toggles.** Small buttons in the left band: one to stop the
  screen from locking or sleeping while watching something, and one to mute notifications (pairs
  with item 1).
- **Weather in the calendar panel.**

Suggested order: notifications first (the most visible piece that doesn't match), then the
volume/brightness popup and the audio panel, which share code with the media panel.

## Problems found along the way

- **Alt+R** runs `~/.config/swaync/refresh.sh`, which doesn't exist, so it does nothing.
- **`hypr/hypridle.conf`** sources `/home/eli/.cache/wal/colors.sh` (from someone else's config),
  so the "about to be locked" and "Unlocked" notifications fail silently.
- **`hypr/hyprland.lua.backup`** is still in the repo and still references wlogout.
