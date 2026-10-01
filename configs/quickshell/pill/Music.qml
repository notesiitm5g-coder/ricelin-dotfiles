pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 音 MUSIC surface: a live spectrum, a 10-band equalizer with presets, the
 * bass / treble / widen effects and the per-device volume boost. Everything is
 * driven through [[AudioFx]], which owns the saved state and the PipeWire filter.
 * Reached from the pill's music icon (or the Now playing card); right click
 * steps back like every surface.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 15

    signal requestSurface(string name)

    implicitHeight: content.implicitHeight
    ameForm: "off"

    SpectrumFeed {
        id: feed
        bars: 40
        running: root.open
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12 * root.s

        // Header: title, output name, master switch.
        Item {
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                Text {
                    visible: Flags.showGlyphs
                    anchors.verticalCenter: parent.verticalCenter
                    text: "音"
                    color: Theme.iconDim
                    font.family: Theme.fontJp
                    font.pixelSize: 14 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MUSIC"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.8 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: AudioFx.sinkLabel
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 200 * root.s)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Now playing ›"
                    color: npArea.containsMouse ? Theme.cream : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    MouseArea {
                        id: npArea
                        anchors.fill: parent
                        anchors.margins: -4 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestSurface("media")
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "EQ"
                    color: AudioFx.enabled ? Theme.cream : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }
                LinkToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    on: AudioFx.enabled
                    onToggled: AudioFx.setEnabled(!AudioFx.enabled)
                }
            }
        }

        // Spectrum.
        Rectangle {
            width: parent.width
            height: 86 * root.s
            radius: 10 * root.s
            color: Theme.frameBg
            border.width: 1
            border.color: Theme.hairSoft

            Row {
                id: spec
                anchors.fill: parent
                anchors.margins: 10 * root.s
                spacing: 3 * root.s
                readonly property real barW: (width - spacing * (feed.bars - 1)) / feed.bars

                Repeater {
                    model: feed.bars
                    Item {
                        required property int index
                        width: spec.barW
                        height: spec.height
                        Rectangle {
                            readonly property real lv: feed.levels.length > parent.index ? feed.levels[parent.index] : 0
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(2 * root.s, parent.height * Math.min(1, lv))
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.flameGlow }
                                GradientStop { position: 1.0; color: Theme.vermLit }
                            }
                            opacity: lv > 0.01 ? 1 : 0.35
                            Behavior on height { NumberAnimation { duration: 60 } }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: feed.levels.length === 0 || Math.max.apply(null, feed.levels) < 0.01
                text: "Play something to see it here"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
            }
        }

        // Filter missing hint.
        Text {
            visible: !AudioFx.available
            width: parent.width
            wrapMode: Text.WordWrap
            text: "The EQ filter isn't running. It starts with your session (ricelin-eq); log out and back in, or run audio/ricelin-eq.conf with pipewire -c."
            color: Theme.vermLit
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
        }

        // Presets.
        Row {
            spacing: 6 * root.s
            opacity: AudioFx.enabled ? 1 : 0.45
            Repeater {
                model: AudioFx.presetOrder.concat(AudioFx.preset === "custom" ? ["custom"] : [])
                Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool current: AudioFx.preset === modelData
                    height: 24 * root.s
                    width: chipText.implicitWidth + 22 * root.s
                    radius: height / 2
                    color: current ? Qt.alpha(Theme.vermLit, 0.22) : (chipArea.containsMouse ? Theme.tileBg : "transparent")
                    border.width: 1
                    border.color: current ? Theme.vermLit : Theme.hairSoft
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: AudioFx.presetLabels[chip.modelData] || chip.modelData
                        color: chip.current ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: chip.current ? Font.DemiBold : Font.Medium
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: chip.modelData !== "custom"
                        onClicked: AudioFx.applyPreset(chip.modelData)
                    }
                }
            }
        }

        // 10-band EQ: drag a band, wheel nudges 0.5 dB, double click resets it.
        Item {
            width: parent.width
            height: 150 * root.s
            opacity: AudioFx.enabled ? 1 : 0.45

            Rectangle {
                // 0 dB guide
                x: 0
                width: parent.width
                y: bandRow.y + bandRow.trackTop + bandRow.trackH / 2
                height: 1
                color: Theme.hairSoft
            }

            Row {
                id: bandRow
                anchors.fill: parent
                readonly property real colW: width / 10
                readonly property real trackTop: 16 * root.s
                readonly property real trackH: height - trackTop - 18 * root.s

                Repeater {
                    model: 10
                    Item {
                        id: band
                        required property int index
                        readonly property real db: (AudioFx.bands && AudioFx.bands.length > index) ? Number(AudioFx.bands[index]) : 0
                        readonly property real frac: (db - AudioFx.minDb) / (AudioFx.maxDb - AudioFx.minDb)
                        width: bandRow.colW
                        height: bandRow.height

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            text: (band.db > 0 ? "+" : "") + band.db.toFixed(band.db % 1 === 0 ? 0 : 1)
                            color: band.db === 0 ? Theme.faint : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            font.features: { "tnum": 1 }
                        }

                        Rectangle {
                            id: track
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: bandRow.trackTop
                            width: 4 * root.s
                            height: bandRow.trackH
                            radius: width / 2
                            color: Theme.threadBg

                            // Fill from 0 dB toward the knob.
                            Rectangle {
                                readonly property real zeroY: track.height / 2
                                readonly property real knobY: track.height * (1 - band.frac)
                                width: parent.width
                                radius: width / 2
                                y: Math.min(zeroY, knobY)
                                height: Math.abs(knobY - zeroY)
                                color: Theme.vermLit
                            }

                            Rectangle {
                                width: 12 * root.s
                                height: 12 * root.s
                                radius: width / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: track.height * (1 - band.frac) - height / 2
                                color: bandArea.pressed || bandArea.containsMouse ? Theme.cream : Theme.flameCore
                                border.width: 1
                                border.color: Theme.vermLit
                            }
                        }

                        MouseArea {
                            id: bandArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            enabled: AudioFx.enabled
                            function setFrom(my) {
                                const f = 1 - Math.max(0, Math.min(1, (my - bandRow.trackTop) / bandRow.trackH));
                                AudioFx.setBand(band.index, AudioFx.minDb + f * (AudioFx.maxDb - AudioFx.minDb));
                            }
                            onPressed: (m) => setFrom(m.y)
                            onPositionChanged: (m) => { if (pressed) setFrom(m.y); }
                            onDoubleClicked: AudioFx.setBand(band.index, 0)
                            onWheel: (w) => AudioFx.setBand(band.index, band.db + (w.angleDelta.y > 0 ? 0.5 : -0.5))
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: AudioFx.freqLabels[band.index]
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hairSoft }

        // Effects: bass, treble, widen.
        Repeater {
            model: [
                { key: "bass", label: "Bass", sub: "Low shelf, 100 Hz" },
                { key: "treble", label: "Treble", sub: "High shelf, 8 kHz" },
                { key: "widen", label: "Widen", sub: "Stereo spread" }
            ]
            Item {
                id: fx
                required property var modelData
                readonly property bool isWiden: modelData.key === "widen"
                readonly property real val: fx.isWiden ? AudioFx.widen : (modelData.key === "bass" ? AudioFx.bass : AudioFx.treble)
                width: content.width
                height: 26 * root.s
                opacity: AudioFx.enabled ? 1 : 0.45

                Text {
                    id: fxLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70 * root.s
                    text: fx.modelData.label
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }

                HFader {
                    anchors.left: fxLabel.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    on: AudioFx.enabled
                    enabled: AudioFx.enabled
                    // Shelves span -6..+12 dB; widen is 0..100%.
                    value: fx.isWiden ? fx.val : (fx.val + 6) / 18
                    labelWidth: 52
                    label: fx.isWiden ? Math.round(fx.val * 100) + "%" : ((fx.val > 0 ? "+" : "") + fx.val.toFixed(1) + " dB")
                    onMoved: (v) => {
                        if (fx.isWiden) AudioFx.setWiden(v);
                        else if (fx.modelData.key === "bass") AudioFx.setBass(-6 + v * 18);
                        else AudioFx.setTreble(-6 + v * 18);
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hairSoft }

        // Per-device volume boost.
        Column {
            width: parent.width
            spacing: 8 * root.s

            Item {
                width: parent.width
                height: boostTitle.implicitHeight
                Text {
                    id: boostTitle
                    anchors.left: parent.left
                    text: "Volume boost"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: boostTitle.baseline
                    text: "For " + AudioFx.sinkLabel + " only. Above 100% can distort."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    width: parent.width - boostTitle.width - 16 * root.s
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Off", value: 1.0 },
                    { label: "125%", value: 1.25 },
                    { label: "150%", value: 1.5 },
                    { label: "175%", value: 1.75 },
                    { label: "200%", value: 2.0 }
                ]
                value: AudioFx.boostCap
                onPicked: (v) => AudioFx.setBoost(v)
            }
        }
    }
}
