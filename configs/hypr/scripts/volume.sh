#!/bin/sh
# Volume keys. Raising honours the per-device boost cap the pill's Music page
# stores in audio.json (keyed by the default sink's node.name); unboosted
# outputs stop at 100% as before.
#   volume.sh up | down
state="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin/audio.json"
case "${1:-}" in
    up)
        sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)"/\1/p' | head -1)
        cap=$(jq -r --arg s "$sink" '.boost[$s] // 1' "$state" 2>/dev/null)
        exec wpctl set-volume -l "${cap:-1}" @DEFAULT_AUDIO_SINK@ 5%+ ;;
    down)
        exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    *)
        echo "usage: volume.sh up|down" >&2; exit 2 ;;
esac
