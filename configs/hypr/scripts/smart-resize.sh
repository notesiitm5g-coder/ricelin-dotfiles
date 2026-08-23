#!/usr/bin/env bash

x=$1
y=$2

# Get active window info
window_info=$(hyprctl activewindow -j)
addr=$(echo "$window_info" | jq -r '.address')
width=$(echo "$window_info" | jq -r '.size[0]')
height=$(echo "$window_info" | jq -r '.size[1]')
floating=$(echo "$window_info" | jq -r '.floating')

# Try normal resize first using hyprland-lua API
hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = $x, y = $y, relative = true }))" >/dev/null 2>&1

# If floating, normal resize always works (unless hitting min size), so we are done
if [ "$floating" = "true" ]; then
    exit 0
fi

# Check new size
new_info=$(hyprctl activewindow -j)
new_width=$(echo "$new_info" | jq -r '.size[0]')
new_height=$(echo "$new_info" | jq -r '.size[1]')

# If size changed, we are done
if [ "$width" != "$new_width" ] || [ "$height" != "$new_height" ]; then
    exit 0
fi

# If size didn't change and we tried to GROW (x > 0 or y > 0), we hit a monitor edge.
# We must shrink the adjacent window instead.
if [ "$x" != "0" ]; then
    if [ "$x" -gt 0 ]; then
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ direction = "l" }))' >/dev/null 2>&1
        hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = -$x, y = 0, relative = true }))" >/dev/null 2>&1
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ direction = "r" }))' >/dev/null 2>&1
    fi
elif [ "$y" != "0" ]; then
    if [ "$y" -gt 0 ]; then
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ direction = "u" }))' >/dev/null 2>&1
        hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = 0, y = -$y, relative = true }))" >/dev/null 2>&1
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ direction = "d" }))' >/dev/null 2>&1
    fi
fi
