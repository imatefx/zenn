# Zenn Architecture

## Module Overview

Zenn is composed of 8 Swift modules organized in a strict dependency hierarchy. The design enforces separation between platform-independent logic and macOS-specific APIs, ensuring testability and clear boundaries.

```
ZennApp -----> ZennLua -----> ZennCore -----> ZennMacOS -----> CPrivateAPI
  |               |               |               |
  +----------> ZennIPC ------+    +----> ZennShared <----+
                                                          |
ZennCLI -----> ZennShared <-------------------------------+
```

## Modules

### ZennShared

**Path:** `Sources/ZennShared/`
**Dependencies:** None

The leaf module in the dependency graph. Contains all types shared across modules with zero platform dependencies. Everything here is `Codable` and `Sendable`.

- **Types:** `WindowID`, `NodeID`, `WorkspaceID`, `DisplayID`, `Direction`, `SplitAxis`, `Rect`, `GapConfig`, `EdgeGaps`, `LayoutMode`, `WindowMode`, `KeyModifier`, `Keybinding`, `WindowInfo`, `WorkspaceInfo`, `MonitorInfo`, `WindowRule`
- **Protocol:** `Command` enum (all IPC command cases), `CommandResponse`, `ResponseData`
- **Serialization:** `IPCMessage` (length-prefixed JSON wire format), `TreeSnapshot`
- **Events:** `HookEventType` (18 event types covering windows, workspaces, apps, monitors, config)

### CPrivateAPI

**Path:** `Sources/CPrivateAPI/`
**Dependencies:** None (C target)

A C bridging target that exposes macOS private ApplicationServices APIs needed for window management. Linked against the `ApplicationServices` framework. Provides C function declarations that Swift code in ZennMacOS imports through the module system.

### ZennMacOS

**Path:** `Sources/ZennMacOS/`
**Dependencies:** `ZennShared`, `CPrivateAPI`

Platform abstraction layer. All macOS API interaction is isolated here so that ZennCore remains testable without accessibility permissions.

| Subsystem | Files | Responsibility |
|---|---|---|
| **Accessibility** | `AXHelpers`, `AXWindow`, `AXApplication`, `AXObserverManager` | Wrap AXUIElement operations: read/write window position and size, observe window events, enumerate application windows |
| **Window** | `WindowDiscovery` | Enumerate all on-screen windows at launch |
| **Display** | `DisplayManager`, `DisplayObserver` | Query connected displays, observe connect/disconnect/reconfigure events |
| **Input** | `EventTapManager`, `HotkeyManager`, `MouseTracker` | Global keyboard event tap for hotkeys, mouse position tracking |
| **Workspace** | `VirtualWorkspaceManager`, `OffscreenHider` | Implement virtual workspaces by moving windows to/from offscreen coordinates (x: -99999, y: -99999) |

### ZennCore

**Path:** `Sources/ZennCore/`
**Dependencies:** `ZennShared`, `ZennMacOS`, `swift-collections`

The tiling engine. Contains all layout logic, tree data structures, and state management. This is the largest module.

| Subsystem | Files | Responsibility |
|---|---|---|
| **Tree** | `TreeNode`, `ContainerNode`, `WindowNode`, `TreeOperations`, `TreeTraversal`, `TreeNormalization` | Binary split tree: insert, remove, swap, resize, search, normalize |
| **Model** | `WindowState`, `WindowRegistry`, `Workspace`, `Monitor` | Domain model for tracked windows, virtual workspaces, and physical monitors |
| **State** | `WorldState`, `StateSnapshot`, `StatePersistence` | Single source of truth for the entire WM state, serialization for persistence |
| **Layout** | `LayoutEngine`, `FrameCalculator`, `GapCalculator`, `AnimationController` | Compute window frames from tree structure, apply gaps, interpolate animations |
| **Focus** | `FocusManager`, `DirectionalFocus`, `FocusBorderOverlay` | Directional and cycle focus traversal, colored border overlay |
| **Operations** | `TileOperation`, `SwapOperation`, `ResizeOperation`, `MoveOperation`, `FullscreenOperation` | High-level operations that combine tree mutation with layout recalculation |
| **Hooks** | `HookEvent`, `HookRegistry`, `HookDispatcher` | Event system: register callbacks, dispatch events to Lua and IPC subscribers |

### ZennLua

**Path:** `Sources/ZennLua/`
**Dependencies:** `ZennShared`, `ZennCore`, `CLua` (system library, lua5.4)

Embeds a Lua 5.4 interpreter and exposes the `zenn` module to user configuration scripts.

- **LuaVM:** Manages the `lua_State`, provides type-safe push/pop helpers, stores Swift object pointers in the Lua registry for access from C callbacks.
- **LuaBridge:** Registers all Lua API functions (`bind`, `focus`, `move`, `resize`, `workspace`, `rule`, `gaps`, `on`, `toggle_*`, `set_split`, `preset`, `focused`, `reload`). Uses `@convention(c)` closures to bridge between Lua's C callback model and Swift. Communicates results back to the app via callback closures (`onKeybind`, `onApplyFrames`, `onWorkspaceSwitch`, `onFocusChange`, `onReload`).

### ZennIPC

**Path:** `Sources/ZennIPC/`
**Dependencies:** `ZennShared`, `ZennCore`, `swift-nio` (NIOCore, NIOPosix, NIOHTTP1)

Two IPC servers that accept commands from the CLI and external tools.

- **CommandRouter:** Maps `Command` enum cases to operation calls and returns `CommandResponse` values.
- **UnixSocketServer:** Listens on `$TMPDIR/zenn.sock`. Uses the length-prefixed JSON protocol (4-byte big-endian length + JSON payload). Built on SwiftNIO.
- **HTTPServer:** Listens on `127.0.0.1:19876`. Provides REST endpoints (`GET /api/v1/windows`, `POST /api/v1/command`, etc.). Built on SwiftNIO with NIOHTTP1.
- **EventBroadcaster:** Subscribes to the HookRegistry and broadcasts events to connected IPC clients as Server-Sent Events (SSE) formatted JSON.

### ZennApp

**Path:** `Sources/ZennApp/`
**Dependencies:** `ZennCore`, `ZennMacOS`, `ZennLua`, `ZennIPC`
**Product:** `zenn-app` executable (menu bar application)

The application entry point. Wires all modules together.

- **AppDelegate:** Orchestrates initialization: accessibility check, TilingCoordinator creation, Lua config loading, IPC server startup, status bar setup.
- **TilingCoordinator:** Central coordinator that owns all components and handles the event loop: monitor setup, window discovery, accessibility observers, app launch/quit handling, workspace switching, frame application with optional animation.
- **StatusBarController:** NSStatusBar menu with workspace display, reload, toggle tiling, and quit actions.
- **AccessibilityGuard:** Checks and requests macOS Accessibility permission.

### ZennCLI

**Path:** `Sources/ZennCLI/`
**Dependencies:** `ZennShared`, `swift-argument-parser`
**Product:** `zenn` executable

A command-line client that sends commands to the running daemon over the Unix socket.

Subcommands: `focus`, `move`, `resize`, `swap`, `workspace`, `move-to-workspace`, `layout`, `toggle`, `query`, `subscribe`, `reload`, `quit`.

Uses raw POSIX socket APIs (`socket`, `connect`, `send`, `recv`) to communicate with the daemon. Encodes commands using `IPCMessage.encode()` and prints JSON responses to stdout.

## Data Flow

### Window Creation

```
NSWorkspace notification (app launched)
  -> TilingCoordinator.handleAppLaunched()
    -> AXObserverManager.observe(pid:)
    -> AXApplication.tileableWindows()
    -> TileOperation.tileWindow()
      -> WindowRegistry.register()
      -> WindowRule matching
      -> Workspace.insertWindow()
        -> TreeOperations.insertWindow()
      -> LayoutEngine.applyLayout()
        -> FrameCalculator.calculateFrames()
    -> VirtualWorkspaceManager.applyFrames()
      -> AXWindow.setFrame() [Accessibility API]
    -> HookDispatcher.windowCreated()
```

### Keybinding Execution (e.g., focus left)

```
CGEventTap captures key event
  -> HotkeyManager matches modifier+key
    -> Lua callback fires
      -> LuaBridge.registerFocusFunction closure
        -> FocusManager.focusInDirection(.left)
          -> TreeTraversal.findNeighbor()
          -> WorldState.setFocus()
        -> onFocusChange callback
          -> VirtualWorkspaceManager.focusWindow()
            -> AXWindow.focus() [Accessibility API]
```

### Workspace Switch

```
User presses Alt+2 (via hotkey)
  -> Lua callback: zenn.workspace(2)
    -> TilingCoordinator.switchToWorkspace(2)
      -> VirtualWorkspaceManager.hideWindows() [move to -99999,-99999]
      -> Monitor.switchToWorkspace(number: 2)
      -> LayoutEngine.applyLayout(for: newWorkspace)
      -> VirtualWorkspaceManager.showWindows() [restore to calculated frames]
      -> HookDispatcher.workspaceSwitched()
```

### IPC Command (CLI)

```
$ zenn focus left
  -> ZennCLI.FocusCommand.run()
    -> sendCommand(.focus(.left))
      -> POSIX socket connect to $TMPDIR/zenn.sock
      -> IPCMessage.encode(command) [4-byte length + JSON]
      -> UnixSocketServer.SocketHandler.channelRead()
        -> CommandRouter.handle(.focus(.left))
          -> FocusManager.focusInDirection(.left)
        -> IPCMessage.encode(response)
      -> CLI prints JSON response
```

## Key External Dependencies

| Dependency | Version | Used By | Purpose |
|---|---|---|---|
| swift-argument-parser | 1.3+ | ZennCLI | CLI argument parsing |
| swift-nio | 2.65+ | ZennIPC | Unix socket and HTTP server |
| swift-collections | 1.1+ | ZennCore | `OrderedDictionary` for monitors and workspaces |
| lua5.4 (system) | 5.4 | ZennLua (via CLua) | Embedded configuration scripting |

## Build Targets

| Target | Type | Product |
|---|---|---|
| ZennApp | executableTarget | `zenn-app` |
| ZennCLI | executableTarget | `zenn` |
| ZennCore | library | `ZennCore` |
| ZennMacOS | library | `ZennMacOS` |
| ZennLua | library | `ZennLua` |
| ZennIPC | library | `ZennIPC` |
| ZennShared | library | (internal) |
| CPrivateAPI | target (C) | (internal) |
| CLua | systemLibrary | (internal) |
