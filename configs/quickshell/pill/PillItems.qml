pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 部 PILL ITEMS sub-surface: one toggle per item in the expanded pill's status
 * row, persisted in Flags (show*) so every monitor's pill follows. Workspaces,
 * the clock and the settings cog are not listed: they are how this page is
 * reached, so they always stay. Reached from the settings index and morphs back
 * to it on an empty click or the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: weatherRow, kind: "toggle", get: function () { return Flags.showWeather; }, set: function (v) { Flags.showWeather = v; } },
        { item: trayRow, kind: "toggle", get: function () { return Flags.showTray; }, set: function (v) { Flags.showTray = v; } },
        { item: wifiRow, kind: "toggle", get: function () { return Flags.showWifi; }, set: function (v) { Flags.showWifi = v; } },
        { item: btRow, kind: "toggle", get: function () { return Flags.showBt; }, set: function (v) { Flags.showBt = v; } },
        { item: batteryRow, kind: "toggle", get: function () { return Flags.showBattery; }, set: function (v) { Flags.showBattery = v; } },
        { item: inboxRow, kind: "toggle", get: function () { return Flags.showInbox; }, set: function (v) { Flags.showInbox = v; } },
        { item: mixerRow, kind: "toggle", get: function () { return Flags.showMixer; }, set: function (v) { Flags.showMixer = v; } },
        { item: musicRow, kind: "toggle", get: function () { return Flags.showMusic; }, set: function (v) { Flags.showMusic = v; } },
        { item: sysmonRow, kind: "toggle", get: function () { return Flags.showSysmon; }, set: function (v) { Flags.showSysmon = v; } },
        { item: recorderRow, kind: "toggle", get: function () { return Flags.showRecorder; }, set: function (v) { Flags.showRecorder = v; } },
        { item: screenshotRow, kind: "toggle", get: function () { return Flags.showScreenshot; }, set: function (v) { Flags.showScreenshot = v; } },
        { item: powerRow, kind: "toggle", get: function () { return Flags.showPower; }, set: function (v) { Flags.showPower = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "部"
            title: "PILL ITEMS"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: weatherRow
            surface: root
            name: "Weather"
            icon: "cloud"
            sub: "Temperature glance, opens the calendar"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showWeather
                onToggled: Flags.showWeather = !Flags.showWeather
            }
        }

        SettingsRow {
            id: trayRow
            surface: root
            name: "System tray"
            icon: "app-window"
            sub: "App tray icons, when any are running"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showTray
                onToggled: Flags.showTray = !Flags.showTray
            }
        }

        SettingsRow {
            id: wifiRow
            surface: root
            name: "Wi-Fi"
            icon: "wifi"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showWifi
                onToggled: Flags.showWifi = !Flags.showWifi
            }
        }

        SettingsRow {
            id: btRow
            surface: root
            name: "Bluetooth"
            icon: "bluetooth"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showBt
                onToggled: Flags.showBt = !Flags.showBt
            }
        }

        SettingsRow {
            id: batteryRow
            surface: root
            name: "Battery"
            icon: "bolt"
            sub: "Percentage and charging dot"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showBattery
                onToggled: Flags.showBattery = !Flags.showBattery
            }
        }

        SettingsRow {
            id: inboxRow
            surface: root
            name: "Notifications"
            icon: "inbox"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showInbox
                onToggled: Flags.showInbox = !Flags.showInbox
            }
        }

        SettingsRow {
            id: mixerRow
            surface: root
            name: "Mixer"
            icon: "mixer"
            sub: "Volume, brightness, keep awake"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showMixer
                onToggled: Flags.showMixer = !Flags.showMixer
            }
        }

        SettingsRow {
            id: musicRow
            surface: root
            name: "Music"
            icon: "music"
            sub: "Visualizer, equalizer, volume boost"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showMusic
                onToggled: Flags.showMusic = !Flags.showMusic
            }
        }

        SettingsRow {
            id: sysmonRow
            surface: root
            name: "System monitor"
            icon: "monitor"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showSysmon
                onToggled: Flags.showSysmon = !Flags.showSysmon
            }
        }

        SettingsRow {
            id: recorderRow
            surface: root
            name: "Screen recorder"
            icon: "video"
            sub: "Still shows while a recording runs"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showRecorder
                onToggled: Flags.showRecorder = !Flags.showRecorder
            }
        }

        SettingsRow {
            id: screenshotRow
            surface: root
            name: "Screenshot"
            icon: "camera"
            sub: "Left click region, right click monitor"
            captionOnFocus: true

            LinkToggle {
                s: root.s
                on: Flags.showScreenshot
                onToggled: Flags.showScreenshot = !Flags.showScreenshot
            }
        }

        SettingsRow {
            id: powerRow
            surface: root
            name: "Power"
            icon: "shutdown"
            captionOnFocus: true
            last: true

            LinkToggle {
                s: root.s
                on: Flags.showPower
                onToggled: Flags.showPower = !Flags.showPower
            }
        }
    }
}
