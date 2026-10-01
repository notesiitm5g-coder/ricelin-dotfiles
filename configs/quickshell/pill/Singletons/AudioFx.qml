pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * Ricelin EQ control. The filter itself is a PipeWire filter-chain run as the
 * ricelin-eq user unit (hypr/audio/ricelin-eq.conf), a WirePlumber smart filter
 * that sits in front of whichever output is the default. This singleton owns the
 * user-facing state (audio.json in Ricelin's state dir, shared with volume.sh)
 * and pushes it to the running filter with pw-cli / pw-metadata.
 *
 * Gains are in dB. Bass/treble are shelves, the ten bands are peaking filters.
 * Widen (0..1) is a mid/side spread done in the filter's 2x2 cross mix, and the
 * same mix carries a preamp that pulls the output down by the largest boost so a
 * loud EQ does not clip. Boost is per output device: the volume cap (1.0 = 100%)
 * for that sink's node.name, honoured by the mixer slider and volume.sh.
 */
Singleton {
    id: root

    readonly property var freqs: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var freqLabels: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property real minDb: -12
    readonly property real maxDb: 12

    /** Shipped shapes. "custom" is whatever the user dragged last. */
    readonly property var presets: ({
        "flat":   { bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], bass: 0, treble: 0, widen: 0 },
        "bass":   { bands: [5, 4, 3, 1, 0, 0, 0, 0, 0, 0], bass: 4, treble: 0, widen: 0 },
        "vocal":  { bands: [-2, -2, -1, 0, 2, 3, 3, 2, 0, -1], bass: 0, treble: 0, widen: 0 },
        "hd":     { bands: [2, 1, 0, 0, -1, 0, 1, 2, 3, 3], bass: 2, treble: 2, widen: 0.25 },
        "cinema": { bands: [4, 3, 1, 0, -1, 0, 1, 1, 2, 2], bass: 3, treble: 1, widen: 0.6 }
    })
    readonly property var presetOrder: ["flat", "bass", "vocal", "hd", "cinema"]
    readonly property var presetLabels: ({ flat: "Flat", bass: "Bass", vocal: "Vocal", hd: "HD", cinema: "Cinema", custom: "Custom" })

    property bool enabled: true
    property string preset: "flat"
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real bass: 0
    property real treble: 0
    property real widen: 0
    /** { "<sink node.name>": cap } for boosted outputs only. */
    property var boost: ({})

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string sinkName: sink ? (sink.name || "") : ""
    readonly property string sinkLabel: sink ? (sink.description || sink.nickname || sink.name || "Output") : "No output"
    /** Volume cap for the current output: 1.0 unless boosted. */
    readonly property real boostCap: {
        void root.boost;
        var m = root.boost || {};
        var v = m[root.sinkName];
        return (typeof v === "number" && v > 1) ? v : 1.0;
    }

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    /**
     * Pick a boost level for the current output: it becomes that device's volume
     * cap and the volume jumps straight to it (wpctl, which allows >100%), so the
     * boost is heard at once. Off drops the cap and pulls anything above 100% back.
     * It acts on the device's own volume, so it works with the EQ on, off or on
     * any preset.
     */
    function setBoost(cap) {
        var m = Object.assign({}, root.boost || {});
        if (cap > 1) m[root.sinkName] = cap; else delete m[root.sinkName];
        root.boost = m;
        root.save();
        if (cap > 1)
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", cap.toFixed(2)]);
        else if (root.sink && root.sink.audio && root.sink.audio.volume > 1)
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1.0"]);
    }

    function setBand(i, db) {
        var b = (root.bands || []).slice();
        while (b.length < 10) b.push(0);
        b[i] = Math.max(root.minDb, Math.min(root.maxDb, Math.round(db * 2) / 2));
        root.bands = b;
        root.preset = "custom";
        root.push();
        root.save();
    }
    function setBass(db) { root.bass = Math.round(db * 2) / 2; root.preset = "custom"; root.push(); root.save(); }
    function setTreble(db) { root.treble = Math.round(db * 2) / 2; root.preset = "custom"; root.push(); root.save(); }
    function setWiden(w) { root.widen = Math.max(0, Math.min(1, w)); root.preset = "custom"; root.push(); root.save(); }

    function applyPreset(name) {
        var p = root.presets[name];
        if (!p) return;
        root.bands = p.bands.slice();
        root.bass = p.bass;
        root.treble = p.treble;
        root.widen = p.widen;
        root.preset = name;
        root.push();
        root.save();
    }

    function setEnabled(on) {
        root.enabled = on;
        root.pushEnabled();
        root.save();
    }

    /** The full Props list for pw-cli: both channels' shelves and bands, plus the cross mix. */
    function propsString() {
        var b = root.bands || [];
        var parts = [];
        var peak = Math.max(0, root.bass, root.treble);
        for (var i = 0; i < 10; i++) {
            var g = Number(b[i] || 0);
            peak = Math.max(peak, g);
            parts.push('"b' + (i + 1) + 'L:Gain" ' + g.toFixed(2), '"b' + (i + 1) + 'R:Gain" ' + g.toFixed(2));
        }
        parts.push('"bassL:Gain" ' + Number(root.bass).toFixed(2), '"bassR:Gain" ' + Number(root.bass).toFixed(2));
        parts.push('"trebleL:Gain" ' + Number(root.treble).toFixed(2), '"trebleR:Gain" ' + Number(root.treble).toFixed(2));
        // Mid/side spread: k = 1 is untouched stereo, 2 doubles the side signal.
        var k = 1 + Number(root.widen);
        var pre = Math.pow(10, -peak / 20) / (k > 1 ? (1 + (k - 1) / 2) : 1);
        var same = ((1 + k) / 2) * pre;
        var other = ((1 - k) / 2) * pre;
        parts.push('"mixL:Gain 1" ' + same.toFixed(4), '"mixL:Gain 2" ' + other.toFixed(4));
        parts.push('"mixR:Gain 1" ' + same.toFixed(4), '"mixR:Gain 2" ' + other.toFixed(4));
        return "{ params = [ " + parts.join(" ") + " ] }";
    }

    /** Coalesce slider drags into one pw-cli call per ~50 ms. */
    function push() { pushTimer.restart(); }
    Timer {
        id: pushTimer
        interval: 50
        onTriggered: {
            if (paramProc.running) { pushTimer.restart(); return; }
            paramProc.command = ["pw-cli", "set-param", "ricelin_eq", "Props", root.propsString()];
            paramProc.running = true;
        }
    }
    Process { id: paramProc }

    function pushEnabled() {
        enableProc.command = ["sh", "-c",
            "id=$(pw-dump 2>/dev/null | jq -r '.[] | select(.info.props[\"node.name\"] == \"ricelin_eq\") | .id' | head -1); "
            + "[ -n \"$id\" ] && pw-metadata -n filters \"$id\" filter.smart.disabled " + (root.enabled ? "false" : "true") + " >/dev/null"];
        enableProc.running = true;
    }
    Process { id: enableProc }

    /** True once the filter node exists; the page shows a hint when it doesn't. */
    property bool available: false
    function probe() { probeProc.running = true; }
    Process {
        id: probeProc
        command: ["sh", "-c", "pw-cli info ricelin_eq >/dev/null 2>&1"]
        onExited: (code) => {
            var was = root.available;
            root.available = code === 0;
            // The filter (re)appeared: it starts flat, so hand it the saved state.
            if (root.available && !was) {
                root.push();
                root.pushEnabled();
            }
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/audio.json"

    /** One debounced write of the whole state; volume.sh reads `boost` from it. */
    function save() { saveTimer.restart(); }
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: stateFile.setText(JSON.stringify({
            enabled: root.enabled, preset: root.preset, bands: root.bands,
            bass: root.bass, treble: root.treble, widen: root.widen, boost: root.boost
        }, null, 2) + "\n")
    }

    // Read once at startup; the pill is the only writer.
    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                var d = JSON.parse(stateFile.text());
                if (typeof d.enabled === "boolean") root.enabled = d.enabled;
                if (typeof d.preset === "string") root.preset = d.preset;
                if (Array.isArray(d.bands) && d.bands.length === 10) root.bands = d.bands;
                if (typeof d.bass === "number") root.bass = d.bass;
                if (typeof d.treble === "number") root.treble = d.treble;
                if (typeof d.widen === "number") root.widen = d.widen;
                if (d.boost && typeof d.boost === "object") root.boost = d.boost;
            } catch (e) {}
        }
    }
}
