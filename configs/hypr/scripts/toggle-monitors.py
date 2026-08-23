#!/usr/bin/env python3
import os
import re
import subprocess
from pathlib import Path

STATE_FILE = Path("/tmp/ricelin-monitor-state")
MONITORS_LUA = Path.home() / ".config/hypr/modules/monitors.lua"

def get_next_state():
    if not STATE_FILE.exists():
        STATE_FILE.write_text("dual\n")
    current = STATE_FILE.read_text().strip()
    if current == "dual":
        return "external"
    elif current == "external":
        return "laptop"
    else:
        return "dual"

def set_mode(text, output_name, mode):
    # Find the block for output_name and replace its mode
    pattern = r'(output\s*=\s*"' + re.escape(output_name) + r'".*?mode\s*=\s*")[^"]*(")'
    return re.sub(pattern, r'\g<1>' + mode + r'\g<2>', text, flags=re.DOTALL)

def main():
    next_state = get_next_state()
    
    if not MONITORS_LUA.exists():
        return

    text = MONITORS_LUA.read_text()

    # eDP-1 is the laptop display, HDMI-A-1 is the external display
    if next_state == "dual":
        text = set_mode(text, "eDP-1", "preferred")
        text = set_mode(text, "HDMI-A-1", "preferred")
    elif next_state == "external":
        text = set_mode(text, "eDP-1", "disable")
        text = set_mode(text, "HDMI-A-1", "preferred")
    elif next_state == "laptop":
        text = set_mode(text, "HDMI-A-1", "disable")
        text = set_mode(text, "eDP-1", "preferred")
        
    MONITORS_LUA.write_text(text)
    STATE_FILE.write_text(next_state + "\n")
    
    subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    main()
