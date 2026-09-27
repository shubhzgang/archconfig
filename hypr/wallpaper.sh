#!/bin/bash
WALLPAPER_DIR="$HOME/wallpapers/walls"
THUMB_DIR="$HOME/.cache/hypr-wallpaper-thumbs-150x84"
THUMB_W=150
THUMB_H=84

export WALLPAPER_DIR THUMB_DIR THUMB_W THUMB_H

make_thumb() {
    local file="$1"
    local rel="${file#"$WALLPAPER_DIR"/}"
    local thumb="$THUMB_DIR/$rel.png"
    mkdir -p "$(dirname "$thumb")"
    if [ -f "$thumb" ] && [ "$thumb" -nt "$file" ]; then
        return
    fi
    magick "${file}[0]" -resize "${THUMB_W}x${THUMB_H}^" -gravity center -extent "${THUMB_W}x${THUMB_H}" -quality 80 "$thumb" 2>/dev/null
}
export -f make_thumb

menu() {
    local files=()
    while IFS= read -r -d '' f; do files+=("$f"); done < <(
        find "${WALLPAPER_DIR}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0
    )
    printf '%s\0' "${files[@]}" | xargs -0 -P "$(nproc)" -n1 bash -c 'make_thumb "$@"' _
    local f
    for f in "${files[@]}"; do
        echo "img:$THUMB_DIR/${f#"$WALLPAPER_DIR"/}.png"
    done
}

main() {
    choice=$(menu | wofi -c ~/.config/wofi/wallpaper -s ~/.config/wofi/style-wallpaper.css --show dmenu --prompt "Select Wallpaper:" -n)
    
    # SAFETY CHECK: Exit the script immediately if you hit escape or close wofi without picking anything
    if [ -z "$choice" ]; then
        exit 0
    fi

    selected_wallpaper=$(echo "$choice" | sed "s|^img:${THUMB_DIR}/|${WALLPAPER_DIR}/|; s|\.png$||")
    
    # 1. Apply wallpaper
    swww img "$selected_wallpaper" --transition-type any --resize crop --transition-fps 144 --transition-duration 1.5
    
    # 2. Generate pywal colors
    wal -i "$selected_wallpaper" -n -s
    
    # 3. Source the generated colors
    # By sourcing this file directly, you instantly load $wallpaper, $color1, $color2, etc. as variables, removing the need for complex awk commands.
    source ~/.cache/wal/colors.sh
    
    # 4. Update basic UI elements
    swaync-client --reload-css
    cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf
    pywalfox update
    
    # 5. Update Cava (Using the sourced $color2 and $color3 variables)
    cava_config="$HOME/.config/cava/config"
    sed -i "s/^gradient_color_1 = .*/gradient_color_1 = '$color2'/" "$cava_config"
    sed -i "s/^gradient_color_2 = .*/gradient_color_2 = '$color3'/" "$cava_config"
    pkill -USR2 cava 2>/dev/null
    
    # 6. Update OpenRGB
    # Instead of reading the 5th line of a file, we can just strip the '#' from the $color5 variable
    sys_box_color=$(echo "$color5" | sed 's/#//')
    echo "$sys_box_color"
    saturated_color=$(python ~/.config/hypr/inc_saturation.py "$sys_box_color" "2.0")
    echo "$saturated_color"
    
    # Added quotes around variables to prevent shell expansion errors
    ~/Downloads/OpenRGB_1.0rc1_x86_64_1fbacde.AppImage -c "$saturated_color"
    
    # 7. Save current wallpaper path
    cp -r "$wallpaper" ~/wallpapers/pywallpaper.jpg 
}

main
