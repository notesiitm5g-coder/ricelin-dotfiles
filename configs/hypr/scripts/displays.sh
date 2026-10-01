#!/bin/bash
# On-the-go display switching for a laptop that docks to external screens.
#
#   displays.sh cycle       both -> external only -> laptop only -> both
#   displays.sh lid-close   undocked: lock. docked: hand off to the external screens
#   displays.sh lid-open    bring the laptop panel back
#
# Everything is session-only (hyprctl eval). monitors.lua is never written, so a
# reload or reboot restores the saved layout, and the last enabled output is never
# turned off. Set DRY_RUN=1 (and optionally MONITORS_JSON) to print instead of apply.
set -u

conf="$HOME/.config/hypr/modules/monitors.lua"
json=${MONITORS_JSON:-$(hyprctl monitors all -j)}

apply() {
    if [ -n "${DRY_RUN:-}" ]; then echo "eval: $1"; else hyprctl eval "$1" >/dev/null; fi
}

note() {
    if [ -n "${DRY_RUN:-}" ]; then echo "note: $1"; return; fi
    notify-send -a Ricelin -t 2500 "Displays" "$1" 2>/dev/null || true
}

# The saved hl.monitor block for an output (minus any disabled flag), or a
# preferred/auto fallback when monitors.lua has none.
enable() {
    local block
    block=$(awk -v out="$1" '
        /hl\.monitor\(\{/ { buf = ""; inb = 1 }
        inb { buf = buf $0 "\n" }
        inb && /\}\)/ { inb = 0; if (buf ~ "output[ \t]*=[ \t]*\"" out "\"") printf "%s", buf }
    ' "$conf" 2>/dev/null | grep -v 'disabled')
    [ -n "$block" ] || block="hl.monitor({ output = \"$1\", mode = \"preferred\", position = \"auto\", scale = 1 })"
    apply "$block"
}

dpms() {
    if [ -n "${DRY_RUN:-}" ]; then echo "dpms: $1"; return; fi
    hyprctl dispatch "hl.dsp.dpms({action = \"$1\"})" >/dev/null
}

disable() {
    apply "hl.monitor({ output = \"$1\", disabled = true })"
}

laptop=$(jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)"))][0].name // empty' <<<"$json")
mapfile -t externals < <(jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)") | not) | .name' <<<"$json")
laptop_on=$(jq -r --arg n "$laptop" '.[] | select(.name == $n) | (.disabled | not)' <<<"$json")
ext_on=$(jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)") | not) | select(.disabled | not)] | length' <<<"$json")

case "${1:-cycle}" in
    cycle)
        if [ -z "$laptop" ] || [ "${#externals[@]}" -eq 0 ]; then
            note "Only one display connected"
            exit 0
        fi
        if [ "$laptop_on" = true ] && [ "$ext_on" -gt 0 ]; then
            disable "$laptop"
            note "External only"
        elif [ "$laptop_on" != true ]; then
            enable "$laptop"
            for e in "${externals[@]}"; do disable "$e"; done
            note "Laptop only"
        else
            for e in "${externals[@]}"; do enable "$e"; done
            note "Laptop + external"
        fi
        ;;
    lid-close)
        if [ -n "$laptop" ] && [ "$ext_on" -gt 0 ]; then
            disable "$laptop"
        elif [ -n "${DRY_RUN:-}" ]; then
            echo "lock"; echo "dpms: off"
        else
            # Lock first (it grabs the screen for its reveal), then blank the panel.
            # logind normally suspends on lid close too, but it ignores the lid for
            # 30s after a resume, so without this a quick re-close left it lit.
            "$HOME/.config/hypr/scripts/lock.sh"
            sleep 1
            dpms off
        fi
        ;;
    lid-open)
        [ -n "$laptop" ] && [ "$laptop_on" != true ] && enable "$laptop"
        dpms on
        ;;
    *)
        echo "usage: displays.sh [cycle|lid-close|lid-open]" >&2
        exit 2
        ;;
esac
exit 0
