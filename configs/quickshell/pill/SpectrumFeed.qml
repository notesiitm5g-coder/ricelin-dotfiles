import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A wider cava spectrum for the Music page, separate from the 5-bar Cava
 * singleton that drives the rest pill. It only runs while `running` is true (the
 * page is open), so the extra FFT costs nothing the rest of the time. Same raw
 * ascii protocol as Cava; levels are normalized 0..1, low to high frequency.
 */
Item {
    id: root

    property int bars: 36
    property bool running: false
    property var levels: []

    readonly property string config: "[general]\n"
        + "bars = " + bars + "\nframerate = 60\nautosens = 0\nsensitivity = 5500\n"
        + "[input]\nmethod = pipewire\nsource = auto\n"
        + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n"
        + "ascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n"
        + "channels = mono\nmono_option = average\n"
        + "[smoothing]\nnoise_reduction = 0.7\n"

    onRunningChanged: if (!running) levels = []

    Process {
        running: root.running
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; printf '%s' \"$1\" | exec cava -p /dev/stdin", "_", root.config]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line)
                    return;
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < root.bars; i++)
                    out.push((parseInt(parts[i]) || 0) / 1000);
                root.levels = out;
            }
        }
    }
}
