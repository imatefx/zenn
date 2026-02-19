# Thought Process: Architecture Choices

## Decision: Multi-Module Swift Package

### Options Considered

1. **Single-target monolith.** All code in one target. Simplest build, but no enforced boundaries. Platform code would mix with logic, making unit testing require Accessibility permissions.

2. **Framework-based (Xcode project).** Multiple frameworks with explicit dependencies. Provides strong boundaries but requires an Xcode project file, which is harder to manage in version control and does not integrate well with SwiftPM.

3. **Multi-target SwiftPM package.** Multiple targets in a single `Package.swift` with explicit dependency declarations. Enforces import boundaries at compile time. Pure command-line build with `swift build`.

### Decision: Option 3

SwiftPM's multi-target model gives us compile-time enforcement of the dependency graph without the overhead of an Xcode project. The key insight is that `ZennCore` (the tiling engine) must be testable without macOS Accessibility permissions. This means `ZennCore` cannot directly call `AXUIElementSetAttributeValue` -- it must go through a callback or protocol.

The resulting architecture:

- `ZennShared`: shared types, zero dependencies. Can be imported by everything.
- `CPrivateAPI`: C headers for private macOS APIs. Imported only by `ZennMacOS`.
- `ZennMacOS`: all macOS API calls. Imported by `ZennCore` for the `Monitor`/`Display` types but the core tiling algorithms do not call macOS APIs directly.
- `ZennCore`: tree, layout, operations, state. Testable with mock data.
- `ZennLua`: configuration bridge. Depends on `ZennCore` to call operations.
- `ZennIPC`: network servers. Depends on `ZennCore` via `CommandRouter`.
- `ZennApp`: entry point. Wires everything together.
- `ZennCLI`: standalone client. Depends only on `ZennShared` for message encoding.

### Why ZennCLI Only Depends on ZennShared

The CLI is a thin client. It serializes a `Command` enum value to JSON, sends it over a Unix socket, reads the response, and prints it. It does not need to know about the tree, the layout engine, or macOS APIs. By depending only on `ZennShared`, the CLI compiles in under 2 seconds and has no dependency on SwiftNIO or Lua.

This also means the CLI can be distributed independently of the daemon.

## Decision: Callback-Based Wiring (Not Protocol/Delegate)

### Options Considered

1. **Protocol-based abstraction.** Define protocols like `WindowManager` and `LayoutApplier` that `TilingCoordinator` conforms to. Pass these to `LuaBridge` and `CommandRouter`.

2. **Callback closures.** Give `LuaBridge` and `CommandRouter` closure properties (`onApplyFrames`, `onWorkspaceSwitch`, etc.) that the `AppDelegate` sets during initialization.

3. **Notification/event bus.** Use `NotificationCenter` or a custom event bus for loose coupling.

### Decision: Option 2

Callback closures are the simplest approach that still provides decoupling. The `LuaBridge` does not know about `TilingCoordinator` or `VirtualWorkspaceManager`. It just calls `onApplyFrames?([WindowID: Rect])` and trusts that someone wired it up.

This keeps the module boundaries clean: `ZennLua` does not import `ZennApp`, and `ZennIPC` does not import `ZennApp`. Only `AppDelegate` (in `ZennApp`) knows about all the modules and wires the callbacks.

Protocol-based abstractions were considered but rejected because:
- The callback signatures are simple (one or two parameters, no return value).
- There are only 5-6 callbacks. A protocol with 5-6 methods is not meaningfully more type-safe than 5-6 closure properties.
- Protocols would require defining the protocol in `ZennShared` (to be visible to all modules), polluting the shared types with behavioral contracts.

The event bus approach was rejected because it loses type safety and makes the data flow harder to trace.

## Decision: WorldState as Single Source of Truth

### Options Considered

1. **Distributed state.** Each module maintains its own state. `ZennMacOS` tracks AX references, `ZennCore` tracks the tree, `ZennIPC` caches query results.

2. **Centralized state.** A single `WorldState` object holds all state: monitors, workspaces, tiling trees, window registry, gap config, window rules. All modules read from and write to this object.

### Decision: Option 2

Centralized state eliminates synchronization bugs. There is one `WorldState` instance, created by `TilingCoordinator`, and passed by reference to all components that need it.

The `WorldState` owns:
- `monitors: OrderedDictionary<DisplayID, Monitor>` -- each `Monitor` owns its `workspaces: OrderedDictionary<Int, Workspace>`, and each `Workspace` owns its `tileRoot: ContainerNode?`.
- `windowRegistry: WindowRegistry` -- flat lookup of all tracked windows by `WindowID`.
- `focusedWindowID: WindowID?` -- the global focus state.
- `globalGaps: GapConfig` -- gap configuration.
- `windowRules: [WindowRule]` -- matching rules.

The trade-off is that `WorldState` is a class (reference type) passed to many components. Mutations are not synchronized -- all mutations happen on the main thread. This is acceptable because macOS Accessibility API callbacks and hotkey events both arrive on the main thread.

## Decision: Operations as Separate Types

### Options Considered

1. **Methods on WorldState.** `worldState.focusLeft()`, `worldState.moveRight()`.
2. **Static functions.** `TilingOperations.focus(state:, direction:)`.
3. **Separate operation objects.** `FocusManager`, `TileOperation`, `SwapOperation`, `ResizeOperation`, `MoveOperation`, `FullscreenOperation`.

### Decision: Option 3

Each operation type encapsulates a specific concern:

- `TileOperation`: Insert/remove a window from the tree and recalculate layout.
- `SwapOperation`: Find a neighbor and swap two windows in the tree.
- `ResizeOperation`: Adjust split ratios and apply presets.
- `MoveOperation`: Move a window to a different position in the tree or to a different workspace.
- `FullscreenOperation`: Toggle window modes (fullscreen, floating, sticky, monocle).
- `FocusManager`: Navigate focus directionally or by cycle.

Each operation takes `WorldState`, `LayoutEngine`, and `HookDispatcher` as constructor arguments. They read from `WorldState`, mutate the tree, call `LayoutEngine` to recalculate frames, and fire hooks.

This separation makes each operation independently testable and keeps individual files small (under 200 lines each).

## Decision: SwiftNIO (Not GCD Sockets)

### Options Considered

1. **Raw POSIX sockets with GCD dispatch sources.** Minimal dependencies, full control, but requires implementing buffering, framing, and error handling.
2. **Foundation URLSession.** Only works for HTTP client, not server.
3. **SwiftNIO.** Event-driven networking framework by Apple. Provides codecs, pipelines, and both TCP and Unix socket support.

### Decision: Option 3 for the server, Option 1 for the CLI client

SwiftNIO handles the complexity of non-blocking I/O, partial reads, and connection management. The `ServerBootstrap` API supports Unix domain sockets natively with `bind(unixDomainSocketPath:)`.

For the CLI client, raw POSIX sockets are used to avoid pulling SwiftNIO into the `ZennCLI` target. The CLI only needs to open one connection, send one message, read one response, and close. This is straightforward with `socket()`, `connect()`, `send()`, `recv()`.

## Decision: Event Tap for Hotkeys (Not NSEvent)

The `HotkeyManager` uses `CGEventTapCreate` to install a global event tap that intercepts keyboard events before they reach any application. This is the only way to implement truly global hotkeys on macOS without requiring the application to be frontmost.

`NSEvent.addGlobalMonitorForEvents` was considered but rejected: it can observe events but cannot consume them. With `NSEvent`, pressing Alt+H would both trigger the Zenn binding and be delivered to the focused application. `CGEventTap` can return `nil` from the callback to consume the event.

The event tap requires Accessibility permission, which Zenn already requests.
