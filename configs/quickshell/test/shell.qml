import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    width: 400
    height: 400
    color: "red"
    Process {
        id: proc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("OUT:", this.text.length, "bytes")
                proc.running = false
                Qt.quit()
            }
        }
    }
    Component.onCompleted: proc.running = true
}
