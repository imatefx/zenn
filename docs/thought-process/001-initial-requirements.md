# Thought Process: Initial Requirements

## Problem Statement

macOS lacks a built-in tiling window manager. Existing solutions each have significant drawbacks:

- **yabai:** Requires SIP to be disabled for full functionality. Written in C/Objective-C, making it difficult to contribute to. The scripting API is CLI-based with no embedded configuration language.
- **AeroSpace:** Proves that the offscreen-hiding approach works without SIP, but its feature set is still maturing and its configuration format is TOML-based without scripting capability.
- **Amethyst:** SwiftUI-based but uses a limited set of predefined layouts rather than a user-configurable tree structure.
- **Hammerspoon:** General-purpose scripting tool, not purpose-built for tiling. Building a tiling WM on top of Hammerspoon is possible but requires substantial user effort.

Zenn aims to combine the best aspects: AeroSpace's SIP-free approach, yabai's power and flexibility, and Hammerspoon's Lua scripting -- in a native Swift application.

## Functional Requirements

### Core Tiling

- **R1:** Automatically tile new windows into a configurable binary split tree layout.
- **R2:** Support horizontal and vertical splits with user-adjustable ratios.
- **R3:** Support directional focus navigation (left, right, up, down) and cycle navigation (next, previous).
- **R4:** Support directional window movement (swap positions within the tree).
- **R5:** Support keyboard-driven resize of split ratios.
- **R6:** Support resize presets (50/50, 60/40, 70/30) for quick layout adjustment.

### Window Modes

- **R7:** Tiled mode: window participates in the tree layout.
- **R8:** Floating mode: window is removed from the tree and floats above tiled windows. Stays on its workspace.
- **R9:** Sticky mode: floating window that is visible on all workspaces.
- **R10:** Fullscreen mode: window fills the workspace. Other windows remain in the tree but are not visible.
- **R11:** Monocle layout mode: all windows on the workspace fill the available area; cycle between them.

### Virtual Workspaces

- **R12:** Provide 9 virtual workspaces per monitor, independent of macOS Spaces.
- **R13:** Switch workspaces by keyboard with instant visual transition.
- **R14:** Move windows between workspaces.
- **R15:** Back-and-forth switching: pressing the current workspace key switches to the previously active workspace.

### Configuration

- **R16:** Lua 5.4 configuration loaded from `~/.config/zenn/init.lua`.
- **R17:** Hot-reload configuration without restarting the application.
- **R18:** Keybinding registration with arbitrary modifier combinations.
- **R19:** Window rules: match by app name (regex), window title (regex), or bundle ID (exact). Apply mode (floating, sticky) or workspace assignment.
- **R20:** Configurable gaps (inner between windows, outer from screen edges).

### IPC

- **R21:** Unix domain socket for fast CLI communication.
- **R22:** HTTP REST API for integration with external tools.
- **R23:** CLI tool for all operations (focus, move, resize, workspace, query, subscribe).
- **R24:** Event subscription for real-time notifications of window/workspace/app/monitor events.

### State

- **R25:** Persist tiling tree structure and window assignments across restarts.
- **R26:** Correctly handle monitor connect/disconnect by migrating windows.
- **R27:** Handle application launch and termination gracefully.

### Presentation

- **R28:** Menu bar application with no Dock icon.
- **R29:** Optional focus border overlay (colored border around focused window).
- **R30:** Optional animations for window transitions (off by default).

## Non-Functional Requirements

- **NF1:** macOS 14+ (Sonoma). Use only APIs available without SIP disable.
- **NF2:** Accessibility permission only. No screen recording, no input monitoring beyond the event tap.
- **NF3:** Layout calculations must complete in under 1ms for up to 50 windows.
- **NF4:** Workspace switching must feel instant (under 50ms perceived latency).
- **NF5:** Memory usage under 50MB during normal operation.
- **NF6:** GPL v3 license.

## Out of Scope (v1)

- Multi-monitor workspace spanning (windows spanning across monitors).
- Tabbed window grouping.
- Custom layout algorithms beyond binary split tree.
- GUI configuration editor.
- Auto-start on login (users can configure this via macOS Login Items).
