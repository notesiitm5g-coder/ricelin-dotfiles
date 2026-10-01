#!/bin/bash
# start-hidden.sh <space> <class> <cmd...>
# Launches an app that a spaces.lua rule routes into special:<space>, then folds
# that special workspace away once the window maps, so login autostarts don't
# pop the space open over the desktop. Launching the app by hand still shows it.
space="$1"; class="$2"; shift 2

has_window() {
    hyprctl clients -j | jq -e --arg c "$class" 'any(.[]; .class == $c)' >/dev/null
}

has_window && exit 0
"$@" >/dev/null 2>&1 &

for _ in $(seq 1 60); do
    sleep 0.5
    if has_window; then
        sleep 0.3
        hyprctl monitors -j | jq -e --arg s "special:$space" 'any(.[]; .specialWorkspace.name == $s)' >/dev/null \
            && hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special(\"$space\"))" >/dev/null
        exit 0
    fi
done
