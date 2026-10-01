# Ricelin to Niri Migration Plan

This document outlines the analysis and options for implementing the original Hyprland-based Ricelin shell into the new `quickshell` component architecture, given your switch to the **Niri** window manager.

## Overview of Challenges

1. **Hyprland Native API Absence**: The old Ricelin pill relied heavily on `Quickshell.Hyprland` (over 50+ instances of `Hyprland.focusedWorkspace`, `Hyprland.monitors`, `Hyprland.dispatch`, etc.). Quickshell does not have a native `Quickshell.Niri` module.
2. **Architecture Shift**: The old `pill/` folder is full of massive UI singletons (`Look.qml`, `Power.qml`) that mix business logic with rendering. The new architecture (`ARCHITECTURE.md`) strictly enforces separating `Services` from `Modules` and `Components`.
3. **Configuration & Live Reloading**: The old shell dynamically reloaded Hyprland via IPC or Lua overrides (`hl.config`). Niri configures via KDL and reloads on save, which requires a different approach for features like dynamic blur toggling or animations.

---

## Proposed Changes (New Architecture)

To map the old Ricelin shell to the new `development/quickshell` architecture:

### 1. Window Manager Integration (`services/NiriService.qml`)

> [!IMPORTANT]
> Niri does not have a native QML module in Quickshell, so we must bridge the gap manually.

**Proposed Solution:**
Create a `NiriService` singleton that uses a `Process` (Quickshell standard component for shell commands) to listen to `niri msg -j event-stream`.
- **State Management**: The service will parse the JSON stream and maintain local properties: `workspaces` (array), `focusedWorkspaceId`, `focusedWindow`, etc.
- **Actions**: We will expose methods like `moveWindowToWorkspace(window, workspace)` that call `niri msg action ...` underneath.
- **Benefit**: Modules like `Workspaces.qml` and `MinimizedTray.qml` will just bind to `NiriService.workspaces` without caring about how the IPC works.

### 2. Replacing Hyprland Settings Management (`services/SettingsService.qml`)

> [!WARNING]
> Niri manages settings via a single `config.kdl` file. It does not allow dynamic injection of ad-hoc config rules like Hyprland's `hyprctl keyword`.

**Options for Niri Configuration Toggles (e.g. Animations, Decorations):**
1. **(Recommended) KDL Parsing script**: Create a fast Python/Bash script that parses/regex-modifies the `config.kdl` directly to toggle things like `animations` or `default-column-width`, and then relies on Niri's auto-reload.
2. **Remove specific WM toggles**: Offload UI settings (like colors, transparency) to `Theme.qml` variables directly, and drop WM-level runtime visual toggles if they are too fragile to modify via KDL regex.

### 3. Audio, Bluetooth, and Network Services

The old pill used heavy bash scripts wrapped in `Process` calls (e.g. `nmcli`, `bluetoothctl`, `pamixer`/`wpctl`).
- **Migration**: We will create `NetworkService.qml`, `BluetoothService.qml`, and `AudioService.qml`.
- **Optimization**: We can migrate standard Wayland/Linux integrations to Quickshell's native DBus bindings where possible, or encapsulate the old bash logic purely inside the Service. The UI Module will only read `NetworkService.ssid` or `NetworkService.wifiStrengthIcon`.

### 4. Layout Structure (The "Pill")

The old shell had a highly dynamic morphing pill (`PillSurface.qml`, `AnimationSurface.qml`). 
- **Migration**: We will break this into `components/PillContainer.qml` for the physical structure.
- **Modules**: The morphing surfaces will become standard Modules (e.g., `modules/VolumeMixer.qml`, `modules/AppLauncher.qml`) that slot into the `PillContainer` dynamically based on state held in a `StateService`.

---

## User Review Required

Before I start building the implementation, please review the following open questions:

## Open Questions

1. **Niri IPC Method**: Are you comfortable with using `niri msg -j event-stream` wrapped in a Quickshell `Process` to handle all window/workspace logic? (This is the most reliable method for Niri).
2. **KDL Config Modifying**: Do you want me to write a script to dynamically toggle settings in your `config.kdl` (e.g. for animations/decorations like the old shell did), or should we drop those specific toggles for now?
3. **Pill Morphing**: Do you want to reproduce the exact "morphing pill" UI from the start, or should we build static modules (Workspaces, Clock, System Tray) first to validate the Niri data flow?

Please let me know your preferences, and I will proceed with creating the necessary Services and Modules.
