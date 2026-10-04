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

    /**
     * EQ modes: an ordered, user-editable library shared by every device. The five
     * shipped shapes seed it (and come back with restoreDefaults()); all of them can
     * be renamed or removed. A device profile points at a mode by id via `preset`
     * and carries its own live values, which may differ from the mode until saved.
     */
    readonly property var builtinModes: [
        { id: "flat",   name: "Flat",   bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], bass: 0, treble: 0, widen: 0 },
        { id: "bass",   name: "Bass",   bands: [5, 4, 3, 1, 0, 0, 0, 0, 0, 0], bass: 4, treble: 0, widen: 0 },
        { id: "vocal",  name: "Vocal",  bands: [-2, -2, -1, 0, 2, 3, 3, 2, 0, -1], bass: 0, treble: 0, widen: 0 },
        { id: "hd",     name: "HD",     bands: [2, 1, 0, 0, -1, 0, 1, 2, 3, 3], bass: 2, treble: 2, widen: 0.25 },
        { id: "cinema", name: "Cinema", bands: [4, 3, 1, 0, -1, 0, 1, 1, 2, 2], bass: 3, treble: 1, widen: 0.6 }
    ]
    property var modes: root.cloneModes(root.builtinModes)
    /** A mode made with + that exists only on the page until it is saved. */
    property var draft: null
    /** Saved modes plus the unsaved draft, in display order. */
    readonly property var modeList: root.draft ? root.modes.concat([root.draft]) : root.modes

    function cloneModes(list) {
        return list.map(function (m) {
            return { id: m.id, name: m.name, bands: m.bands.slice(), bass: m.bass, treble: m.treble, widen: m.widen };
        });
    }
    function modeById(id) {
        if (root.draft && root.draft.id === id) return root.draft;
        for (var i = 0; i < root.modes.length; i++)
            if (root.modes[i].id === id) return root.modes[i];
        return null;
    }
    function isDraft(id) { return root.draft !== null && root.draft.id === id; }

    /** The page's values differ from the selected mode's saved ones (or it's an unsaved draft). */
    readonly property bool dirty: {
        void root.bands; void root.bass; void root.treble; void root.widen; void root.preset; void root.modes; void root.draft;
        if (root.isDraft(root.preset)) return true;
        var m = root.modeById(root.preset);
        if (!m) return false;
        if (Math.abs(m.bass - root.bass) > 0.01 || Math.abs(m.treble - root.treble) > 0.01 || Math.abs(m.widen - root.widen) > 0.01)
            return true;
        for (var i = 0; i < 10; i++)
            if (Math.abs(Number(m.bands[i]) - Number(root.bands[i] || 0)) > 0.01) return true;
        return false;
    }

    /** + : a new flat mode, selected straight away, kept only if saved. */
    function newMode() {
        var n = 1;
        var names = root.modes.map(function (m) { return m.name; });
        while (names.indexOf("Custom " + n) >= 0) n++;
        root.draft = { id: "m" + Date.now(), name: "Custom " + n, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], bass: 0, treble: 0, widen: 0 };
        root.applyPreset(root.draft.id);
    }
    /** Save: the page's values become the selected mode (a draft joins the library). */
    function saveMode() {
        var vals = { bands: root.bands.slice(), bass: root.bass, treble: root.treble, widen: root.widen };
        if (root.isDraft(root.preset)) {
            root.modes = root.modes.concat([Object.assign({ id: root.draft.id, name: root.draft.name }, vals)]);
            root.draft = null;
        } else {
            root.modes = root.modes.map(function (m) { return m.id === root.preset ? Object.assign({ id: m.id, name: m.name }, vals) : m; });
        }
        root.save();
    }
    function renameMode(id, name) {
        name = (name || "").trim();
        if (name.length === 0) return;
        if (root.isDraft(id)) { root.draft = Object.assign({}, root.draft, { name: name }); return; }
        root.modes = root.modes.map(function (m) { return m.id === id ? Object.assign({}, m, { name: name }) : m; });
        root.save();
    }
    function removeMode(id) {
        if (root.isDraft(id)) root.draft = null;
        else root.modes = root.modes.filter(function (m) { return m.id !== id; });
        // The sound stays as it is; it just no longer belongs to a mode.
        if (root.preset === id) { root.preset = ""; root.commit(false); }
        root.save();
    }
    /** Bring the five shipped modes back (renamed/removed ones reset), keeping user modes. */
    function restoreDefaults() {
        var ids = root.builtinModes.map(function (m) { return m.id; });
        root.modes = root.cloneModes(root.builtinModes).concat(root.modes.filter(function (m) { return ids.indexOf(m.id) < 0; }));
        root.save();
    }

    // The profile being edited on the Music page (editSink's), not necessarily the
    // one playing: the filter always runs the active output's profile.
    property bool enabled: true
    property string preset: "flat"
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real bass: 0
    property real treble: 0
    property real widen: 0
    /** { "<sink node.name>": cap } for boosted outputs only. */
    property var boost: ({})
    /** { "<sink node.name>": { enabled, preset, bands, bass, treble, widen } }. Missing = flat, on. */
    property var profiles: ({})
    property var legacy: null

    /** Real output devices (the EQ's own virtual sink excluded), sorted by name. */
    readonly property var outputs: {
        void Pipewire.nodes.values;
        var out = [];
        var all = Pipewire.nodes.values;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream && n.audio && n.name !== "ricelin_eq")
                out.push(n);
        }
        out.sort((a, b) => root.labelOf(a).localeCompare(root.labelOf(b)));
        return out;
    }
    /** Make a device the output (the EQ follows it) and show its settings. */
    function useOutput(name) {
        for (var i = 0; i < root.outputs.length; i++)
            if (root.outputs[i].name === name) {
                Pipewire.preferredDefaultAudioSink = root.outputs[i];
                break;
            }
        root.selectEdit(name);
    }

    /**
     * Hand playback to a headset or speaker as it connects. WirePlumber keeps the
     * saved default (often the laptop speaker), so a freshly paired Bluetooth or
     * USB device would sit idle. Devices present at startup are just recorded.
     */
    property var knownOutputs: null
    onOutputsChanged: {
        var names = root.outputs.map(function (n) { return n.name; });
        if (root.knownOutputs === null) {
            if (names.length > 0) root.knownOutputs = names;
            return;
        }
        for (var i = 0; i < root.outputs.length; i++) {
            var n = root.outputs[i];
            if (root.knownOutputs.indexOf(n.name) < 0 && /^(bluez_output|alsa_output\.usb)/.test(n.name)) {
                Pipewire.preferredDefaultAudioSink = n;
                break;
            }
        }
        root.knownOutputs = names;
    }

    function labelOf(n) { return n ? (n.description || n.nickname || n.name || "Output") : ""; }

    /** Which device the Music page is editing; follows the active output when that changes. */
    property string editSink: ""
    readonly property var editNode: {
        for (var i = 0; i < root.outputs.length; i++)
            if (root.outputs[i].name === root.editSink) return root.outputs[i];
        return null;
    }
    readonly property string editLabel: editNode ? labelOf(editNode) : root.sinkLabel
    /** Is the edited device the one playing? Compared live (a derived property went stale inside the sink-change handler). */
    function editIsActive() { return root.editSink.length > 0 && root.editSink === root.sinkName; }
    readonly property real editBoostCap: boostCapFor(root.editSink)

    function boostCapFor(name) {
        var v = (root.boost || {})[name];
        return (typeof v === "number" && v > 1) ? v : 1.0;
    }
    function profileFor(name) {
        var p = (root.profiles || {})[name];
        return {
            enabled: p && typeof p.enabled === "boolean" ? p.enabled : true,
            preset: p && typeof p.preset === "string" ? p.preset : "flat",
            bands: p && Array.isArray(p.bands) && p.bands.length === 10 ? p.bands : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            bass: p && typeof p.bass === "number" ? p.bass : 0,
            treble: p && typeof p.treble === "number" ? p.treble : 0,
            widen: p && typeof p.widen === "number" ? p.widen : 0
        };
    }
    /** Show a device's profile on the page. */
    function selectEdit(name) {
        root.editSink = name;
        var p = root.profileFor(name);
        root.enabled = p.enabled; root.preset = p.preset; root.bands = p.bands.slice();
        root.bass = p.bass; root.treble = p.treble; root.widen = p.widen;
    }
    /** Store the page's values as editSink's profile; if that device is playing, apply them. */
    function commit(enabledChanged) {
        if (root.editSink.length === 0) return;
        var m = Object.assign({}, root.profiles || {});
        m[root.editSink] = { enabled: root.enabled, preset: root.preset, bands: root.bands,
                             bass: root.bass, treble: root.treble, widen: root.widen };
        root.profiles = m;
        root.save();
        if (root.editIsActive()) {
            root.push();
            if (enabledChanged) root.pushEnabled();
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string sinkName: sink ? (sink.name || "") : ""
    readonly property string sinkLabel: sink ? (sink.description || sink.nickname || sink.name || "Output") : "No output"
    /** Volume cap for the current output: 1.0 unless boosted. */
    readonly property real boostCap: { void root.boost; return root.boostCapFor(root.sinkName); }

    // A new active output: load its profile into the filter and the page.
    onSinkNameChanged: root.activate()
    Component.onCompleted: root.activate()
    function activate() {
        if (root.sinkName.length === 0) return;
        if (root.legacy) {
            var m = Object.assign({}, root.profiles || {});
            if (!m[root.sinkName]) m[root.sinkName] = root.legacy;
            root.profiles = m;
            root.legacy = null;
            root.save();
        }
        root.selectEdit(root.sinkName);
        root.push();
        root.pushEnabled();
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
        var name = root.editSink;
        var m = Object.assign({}, root.boost || {});
        if (cap > 1) m[name] = cap; else delete m[name];
        root.boost = m;
        root.save();
        var target = root.editIsActive() ? "@DEFAULT_AUDIO_SINK@" : (root.editNode ? String(root.editNode.id) : "");
        if (target.length === 0) return;
        var vol = root.editNode && root.editNode.audio ? root.editNode.audio.volume : 1;
        if (cap > 1)
            Quickshell.execDetached(["wpctl", "set-volume", target, cap.toFixed(2)]);
        else if (vol > 1)
            Quickshell.execDetached(["wpctl", "set-volume", target, "1.0"]);
    }

    function setBand(i, db) {
        var b = (root.bands || []).slice();
        while (b.length < 10) b.push(0);
        b[i] = Math.max(root.minDb, Math.min(root.maxDb, Math.round(db * 2) / 2));
        root.bands = b;
        root.commit(false);
    }
    function setBass(db) { root.bass = Math.round(db * 2) / 2; root.commit(false); }
    function setTreble(db) { root.treble = Math.round(db * 2) / 2; root.commit(false); }
    function setWiden(w) { root.widen = Math.max(0, Math.min(1, w)); root.commit(false); }

    /** Select a mode: its saved values replace the page's (unsaved edits are dropped). */
    function applyPreset(name) {
        var p = root.modeById(name);
        if (!p) return;
        // Leaving an unsaved draft discards it.
        if (root.draft && root.draft.id !== name) root.draft = null;
        root.bands = p.bands.slice();
        root.bass = p.bass;
        root.treble = p.treble;
        root.widen = p.widen;
        root.preset = name;
        root.commit(false);
    }

    function setEnabled(on) {
        root.enabled = on;
        root.commit(true);
    }

    /** The full Props list for pw-cli: both channels' shelves and bands, plus the cross mix. */
    function propsString() {
        var a = root.profileFor(root.sinkName);
        var b = a.bands;
        var parts = [];
        var peak = Math.max(0, a.bass, a.treble);
        for (var i = 0; i < 10; i++) {
            var g = Number(b[i] || 0);
            peak = Math.max(peak, g);
            parts.push('"b' + (i + 1) + 'L:Gain" ' + g.toFixed(2), '"b' + (i + 1) + 'R:Gain" ' + g.toFixed(2));
        }
        parts.push('"bassL:Gain" ' + Number(a.bass).toFixed(2), '"bassR:Gain" ' + Number(a.bass).toFixed(2));
        parts.push('"trebleL:Gain" ' + Number(a.treble).toFixed(2), '"trebleR:Gain" ' + Number(a.treble).toFixed(2));
        // Mid/side spread: k = 1 is untouched stereo, 2 doubles the side signal.
        var k = 1 + Number(a.widen);
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
            + "[ -n \"$id\" ] && pw-metadata -n filters \"$id\" filter.smart.disabled " + (root.profileFor(root.sinkName).enabled ? "false" : "true") + " >/dev/null"];
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
        onTriggered: stateFile.setText(JSON.stringify({ modes: root.modes, profiles: root.profiles, boost: root.boost }, null, 2) + "\n")
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
                if (d.boost && typeof d.boost === "object") root.boost = d.boost;
                if (Array.isArray(d.modes)) root.modes = d.modes.filter(function (m) { return m && m.id && Array.isArray(m.bands) && m.bands.length === 10; });
                if (d.profiles && typeof d.profiles === "object") root.profiles = d.profiles;
                // Pre-profile files kept one global EQ: hand it to the first active output.
                else if (Array.isArray(d.bands))
                    root.legacy = { enabled: d.enabled !== false, preset: d.preset || "flat", bands: d.bands,
                                    bass: d.bass || 0, treble: d.treble || 0, widen: d.widen || 0 };
            } catch (e) {}
            root.activate();
        }
    }
}
