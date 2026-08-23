import QtQuick
import Quickshell
import Quickshell.Io
import "." as Local

PanelWindow {
    width: 400
    height: 400
    color: "red"
    Local.Display {
        id: disp
    }
}
