#!/bin/bash
sleep 2

CONFIG_FILE="$HOME/.config/hypr/modules/monitors.lua"

# Remove any disabled flags entirely so hyprland-lua successfully parses all displays as active
sed -i '/[ \t]*disabled\s*=\s*true/d' "$CONFIG_FILE"
sed -i '/[ \t]*disabled\s*=\s*false/d' "$CONFIG_FILE"
sed -i 's/mode = "disable"/mode = "preferred"/g' "$CONFIG_FILE"

# Dynamically evaluate the fixed lua config through the backend
hyprctl eval "$(cat "$CONFIG_FILE")" >/dev/null 2>&1

# Re-initialize the pill to ensure it catches the finalized monitor state
killall qs
killall watchdog.sh
nohup ~/.config/hypr/scripts/watchdog.sh pill >/dev/null 2>&1 &
