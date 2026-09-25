#!/bin/bash
WAYBAR_DIR="$HOME/.config/waybar"
STYLECSS="$WAYBAR_DIR/style.css"
CONFIG="$WAYBAR_DIR/config"
ASSETS="$WAYBAR_DIR/assets"
THEMES="$WAYBAR_DIR/themes"
menu() {
    find "${ASSETS}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | awk '{print "img:"$0}'
}
restart_waybar() {
    pkill -x waybar
    sleep 0.5
    setsid waybar >/dev/null 2>&1 < /dev/null &
    disown
}
main() {
    local choice selected_wallpaper
    choice=$(menu | wofi -c ~/.config/wofi/waybar -s ~/.config/wofi/style-waybar.css --show dmenu --prompt "  Select Waybar (Scroll with Arrows)" -n)
    selected_wallpaper=$(echo "$choice" | sed 's/^img://')
    # User cancelled the menu - leave current bar untouched
    [[ -z "$selected_wallpaper" ]] && exit 0
    if [[ "$selected_wallpaper" == "$ASSETS/experimental.png" ]]; then
        cat "$THEMES/experimental/style-experimental.css" > "$STYLECSS"
        cat "$THEMES/experimental/config-experimental" > "$CONFIG"
        restart_waybar
    elif [[ "$selected_wallpaper" == "$ASSETS/main.png" ]]; then
        cat "$THEMES/default/style-default.css" > "$STYLECSS"
        cat "$THEMES/default/config-default" > "$CONFIG"
        restart_waybar
    elif [[ "$selected_wallpaper" == "$ASSETS/line.png" ]]; then
        cat "$THEMES/line/style-line.css" > "$STYLECSS"
        cat "$THEMES/line/config-line" > "$CONFIG"
        restart_waybar
    elif [[ "$selected_wallpaper" == "$ASSETS/zen.png" ]]; then
        cat "$THEMES/zen/style-zen.css" > "$STYLECSS"
        cat "$THEMES/zen/config-zen" > "$CONFIG"
        restart_waybar
    fi

}
main
