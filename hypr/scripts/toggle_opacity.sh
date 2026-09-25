#!/usr/bin/env bash
# Toggle global transparency on/off.
# Uses hyprctl eval (Lua) because hyprctl keyword doesn't work with Lua configs.
#
# When toggling to opaque, also clears any per-window set_prop opacity overrides
# (set by active_opacity.sh) because those take precedence over the global config.

CURRENT_OPACITY=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')

# Check if fully opaque (safe floating-point comparison via awk)
IS_OPAQUE=$(awk -v op="$CURRENT_OPACITY" 'BEGIN { print (op >= 0.99) ? 1 : 0 }')

if [ "$IS_OPAQUE" -eq 1 ]; then
    # Revert to translucent defaults
    hyprctl eval 'hl.config({ decoration = { active_opacity = 0.95, inactive_opacity = 0.6 } })'
else
    # Force all windows fully opaque globally
    hyprctl eval 'hl.config({ decoration = { active_opacity = 1.0, inactive_opacity = 1.0 } })'
    # Also clear any per-window opacity override on the active window,
    # since set_prop overrides take precedence over the global config value.
    ADDRESS=$(hyprctl activewindow -j | jq -r '.address')
    if [ "$ADDRESS" != "null" ] && [ -n "$ADDRESS" ]; then
        hyprctl eval "hl.dispatch(hl.dsp.window.set_prop({ window = 'address:$ADDRESS', prop = 'opacity', value = '1.0 override 1.0 override' }))"
        # Clear stored per-window state so active_opacity.sh resets to 1.0 next use
        rm -f "/tmp/hypr_opacity/$ADDRESS"
    fi
fi
