#!/bin/bash
sleep 2

# Check if eDP-1 is set to disabled in monitors.lua
if grep -q 'disabled = true' ~/.config/hypr/modules/monitors.lua; then
    # Count how many physical displays are connected (via DRM sysfs)
    MON_COUNT=$(cat /sys/class/drm/card*-*/status 2>/dev/null | grep -c "^connected")
    
    if [ "$MON_COUNT" -eq 1 ]; then
        # Only 1 display is connected, but the config has disabled=true!
        # This would cause a black screen on boot. Let's fix it safely.
        sed -i 's/disabled = true/disabled = false/g' ~/.config/hypr/modules/monitors.lua
        sed -i 's/mode = "disable"/mode = "preferred"/g' ~/.config/hypr/modules/monitors.lua
        hyprctl reload
    fi
fi
