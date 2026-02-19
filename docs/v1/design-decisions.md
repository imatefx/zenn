# Design Decisions

This document captures the key technical decisions made during the development of Zenn, along with the reasoning and trade-offs for each.

## 1. Language: Swift

**Decision:** Write the entire application in Swift (5.9+, macOS 14+).

**Reasoning:**
- First-class access to macOS frameworks (AppKit, Accessibility, CoreGraphics) without FFI overhead. The Accessibility API is verbose even in Swift; doing it through Rust or C bindings would add a significant maintenance burden.
- Value types (`struct`, `enum`) with `Codable` and `Sendable` conformance make the shared types safe to pass across module and thread boundaries.
- Swift Package Manager provides straightforward multi-target builds. The 8-module structure compiles with a single `swift build` invocation.
- Pattern matching on `indirect enum TreeNode` maps naturally to the recursive tree algorithms at the core of the tiling engine.

**Trade-offs:**
- Swift is not common in the tiling WM space. yabai uses C/Objective-C, AeroSpace uses Swift but is a relatively recent precedent.
- The `@convention(c)` closures required for Lua interop are awkward. Lua's C API expects plain function pointers, so the bridge layer requires careful handling of Swift object lifetimes through `Unmanaged` pointers stored in the Lua registry.
- Swift's lack of stable ABI for libraries means all modules are compiled together rather than distributed as separate dylibs.

## 2. Virtual Workspaces via Offscreen Window Hiding

**Decision:** Implement virtual workspaces by moving windows to offscreen coordinates (-99999, -99999) rather than using macOS Spaces.

**Reasoning:**
- macOS does not provide a public API for programmatic Space management. The private `CGSSpace` APIs require SIP to be disabled, which is a dealbreaker for most users.
- AeroSpace proved that the offscreen approach works reliably. Windows moved to extreme negative coordinates are invisible to the user but remain in the window list and respond to Accessibility API calls.
- This approach requires only standard Accessibility permissions (System Settings > Privacy & Security > Accessibility). No SIP disable, no screen recording permission, no injection.
- Workspace switching is fast: it is a batch of `AXUIElementSetAttributeValue` calls to update window positions.

**Trade-offs:**
- Mission Control shows all windows in a flat list regardless of virtual workspace assignment. This is inherent to any approach that does not use native Spaces.
- Windows briefly flash during workspace switch on some configurations. The `VirtualWorkspaceManager` mitigates this by hiding first, then showing, but the Accessibility API does not guarantee atomic position updates.
- The `savedPositions` dictionary in `VirtualWorkspaceManager` must be kept in sync. If a window is moved by the user while offscreen (unlikely but possible via scripting), the saved position becomes stale.

## 3. Binary Split Tree with Depth Cap

**Decision:** Use a binary split tree (BSP tree) for layout, with a maximum depth of 5.

**Reasoning:**
- A BSP tree directly models the user's mental model of splitting a screen: every split divides a region into two (or more) children along a horizontal or vertical axis.
- The `ContainerNode` holds an array of children (not strictly binary; it can hold N children at one level), but nesting creates the binary split effect. This is more flexible than a strict binary tree because same-axis containers are merged during normalization.
- The depth cap of 5 prevents pathological nesting. At depth 5, the user has split the screen at least 5 times in alternating directions, producing 32+ windows in theory. In practice, more than 3-4 levels of nesting makes windows too small to be useful.
- When the depth cap is reached, new windows are inserted as siblings in the current container rather than creating a new sub-container. This degrades gracefully.

**Normalization rules (applied after every mutation):**
1. Remove empty containers (no children after a window was removed).
2. Flatten single-child containers (a container with one child is replaced by that child).
3. Merge same-axis containers (e.g., `H[H[a, b], c]` becomes `H[a, b, c]` with proportionally adjusted ratios).

These rules keep the tree minimal and prevent degenerate structures from accumulating over time.

**Trade-offs:**
- The normalization pass runs after every insert/remove. For typical window counts (under 50), this is negligible. For extreme cases, the recursive traversal is bounded by the depth cap.
- Ratios are stored per-container and must sum to 1.0. After merging same-axis containers, ratios are recalculated proportionally. Floating-point drift is corrected by renormalization when the sum deviates by more than 0.001.

## 4. Lua Configuration

**Decision:** Use Lua 5.4 for user configuration, loaded from `~/.config/zenn/init.lua`.

**Reasoning:**
- Lua is lightweight (the entire interpreter is ~200KB), embeds trivially via C API, and is already familiar to users of Hammerspoon, Neovim, and WezTerm.
- A full scripting language lets users express conditional logic, loops, and abstractions that a declarative config format (TOML, YAML) cannot. For example, binding Alt+1 through Alt+9 to workspaces is a three-line `for` loop in Lua.
- The `require("zenn")` pattern provides a clean namespace. The `LuaBridge` registers all API functions on a global `zenn` table and also installs it as a `package.preload` entry.
- Reload without restart: the `zenn.reload()` function (or `zenn reload` CLI command) creates a fresh `LuaBridge`, clears all keybindings and window rules, and re-executes the config file.

**Trade-offs:**
- Lua's C callback model (`@convention(c)` function pointers) requires the bridge to store a reference to the `LuaBridge` instance in the Lua registry as a light userdata. This is the `__zenn_bridge` key pattern used throughout `LuaBridge.swift`.
- Error reporting from Lua to the user is limited to `luaBridge.vm.errors`, which is an array of strings. There is no structured error type or line-number mapping beyond what Lua itself provides in the error message.
- Adding a system library dependency (`lua5.4` via Homebrew) increases the installation requirements. The `CLua` system library target in `Package.swift` uses `pkgConfig: "lua5.4"` to locate the headers and library.

## 5. IPC: Unix Socket + HTTP

**Decision:** Provide two IPC channels: a Unix domain socket with length-prefixed JSON, and an HTTP REST API.

**Reasoning:**
- The Unix socket is the primary channel for the CLI tool. It is fast (no TCP overhead), secure (filesystem permissions), and supports the full `Command` enum via JSON serialization.
- The HTTP API enables integration with external tools (status bars, scripts, web dashboards) that do not want to implement the length-prefixed protocol. `curl http://localhost:19876/api/v1/windows` just works.
- Both channels share the same `CommandRouter`, ensuring identical behavior regardless of the transport.

**Wire protocol (Unix socket):**
- 4-byte big-endian unsigned integer: payload length
- N bytes: JSON-encoded `Command` (request) or `CommandResponse` (response)
- One request-response pair per message. The CLI opens a connection, sends one command, reads one response, and closes.

**HTTP endpoints:**
- `GET /api/v1/windows` - list all tracked windows
- `GET /api/v1/workspaces` - list all workspaces
- `GET /api/v1/monitors` - list all monitors
- `GET /api/v1/focused` - get the focused window
- `GET /api/v1/tree` - get the tiling tree snapshot
- `POST /api/v1/command` - send any `Command` as JSON body
- `GET /api/v1/health` - health check

**Trade-offs:**
- Two server implementations means two things to maintain. The `CommandRouter` abstraction mitigates this, but the transport-level code (NIO handlers) is duplicated.
- The HTTP server binds to `127.0.0.1:19876`. If the port is already in use, the server fails to start. There is no port negotiation or fallback.
- The event subscription (`zenn subscribe`) currently only works over the Unix socket. SSE over HTTP is implemented in `EventBroadcaster` but not yet wired to the HTTP handler.

## 6. License: GPL v3

**Decision:** License the project under the GNU General Public License version 3.

**Reasoning:**
- Zenn uses macOS private APIs (via `CPrivateAPI`) that are inherently platform-specific and could be used to build proprietary derivatives. GPL v3 ensures that any derivative work that uses these APIs remains open source.
- Strong copyleft aligns with the tiling WM community's expectations. yabai (MIT) and AeroSpace (MIT) took a permissive approach, but GPL v3 provides stronger protections for contributors.
- The "or any later version" clause in the license header provides flexibility for future relicensing to GPL v4 or later if the FSF releases one.

**Trade-offs:**
- GPL v3 is incompatible with some proprietary integrations. Companies that want to bundle Zenn into proprietary products cannot do so without releasing their source.
- The swift-nio dependency is Apache 2.0, which is compatible with GPL v3. The swift-argument-parser and swift-collections are also Apache 2.0. Lua 5.4 is MIT. All dependencies are GPL-compatible.

## 7. Menu Bar App (No Dock Icon)

**Decision:** Run as a menu bar application with `LSUIElement = true` (no Dock icon, no app switcher entry).

**Reasoning:**
- A tiling WM is a background service. It should not compete for Dock space or appear in Cmd+Tab.
- The status bar icon provides at-a-glance information (current workspace number, tiling enabled/disabled) and a menu for reload, toggle, and quit.
- `AppDelegate` is the entry point rather than a `@main App` SwiftUI struct because the app needs fine-grained control over the run loop and does not have any windows of its own.

## 8. SwiftNIO for Networking

**Decision:** Use Apple's SwiftNIO for both the Unix socket server and HTTP server rather than Foundation's `URLSession` or raw POSIX sockets.

**Reasoning:**
- SwiftNIO provides non-blocking, event-driven I/O that handles multiple concurrent connections efficiently on a single thread (`numberOfThreads: 1`).
- `NIOHTTP1` provides a complete HTTP/1.1 codec, avoiding the need to write a custom HTTP parser.
- The `ServerBootstrap` API supports both TCP and Unix domain socket binding with the same handler pipeline.

**Trade-offs:**
- SwiftNIO is a substantial dependency (~50 files). For a simple request-response protocol, it is arguably overkill. However, it handles edge cases (partial reads, backpressure, connection cleanup) that would require significant code in a raw POSIX implementation.
- The CLI tool (`ZennCLI`) does NOT use SwiftNIO. It uses raw POSIX socket APIs (`socket`, `connect`, `send`, `recv`) to avoid pulling in the NIO dependency for a simple one-shot client. This means there are two independent socket implementations in the project.

## 9. Accessibility-Only (No SIP Disable)

**Decision:** Require only macOS Accessibility permission. Do not use any APIs that require disabling System Integrity Protection.

**Reasoning:**
- SIP is a critical security feature. Requiring users to disable it creates a significant barrier to adoption and a real security risk.
- The Accessibility API (`AXUIElement`) provides everything needed: read/write window position and size, observe window creation/destruction/focus/move/resize/minimize events, enumerate application windows.
- The `CPrivateAPI` module uses `CGWindowListCopyWindowInfo` (public) and a small number of private `CGS` functions for window ID resolution. These private APIs work with SIP enabled.

**Trade-offs:**
- Without SIP-disabled private APIs, some features are impossible: injection into other processes, modifying window decorations, overriding window shadows, intercepting window creation before it is rendered.
- The Accessibility permission prompt requires the user to manually toggle the switch in System Settings. There is no way to programmatically grant it.
