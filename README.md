# Zenn

A fast, native macOS tiling window manager written in Swift.

Inspired by i3, AeroSpace, and yabai — with Lua scripting, virtual workspaces, and full IPC support. No SIP disable required.

## Features

- **Tiling layouts** — Horizontal/vertical splits with adjustable ratios
- **Virtual workspaces** — Independent per-monitor, numbered 1–9
- **Lua configuration** — Full scripting via `~/.config/zenn/init.lua`
- **Merge & eject** — Move windows into/out of nested splits
- **Directional focus** — Navigate left/right/up/down or cycle next/prev
- **Grow/shrink resize** — Right/up to grow, left/down to shrink
- **Floating & sticky windows** — Float above tiled, sticky across all workspaces
- **Window rules** — Auto-float by app name, title, or bundle ID
- **IPC** — Unix socket + HTTP API + CLI tool (`zenn`)
- **Hooks** — Event callbacks for window, workspace, app, and monitor events
- **Configurable gaps** — Inner + outer, per workspace or monitor
- **State persistence** — Workspace settings saved across restarts
- **Focus border** — Optional colored border overlay
- **Menu bar app** — Lives in the menu bar, no Dock icon

## Requirements

- macOS 14+ (Sonoma)
- Accessibility permissions
- Lua 5.4 (`brew install lua@5.4`)

## Building from Source

```bash
git clone https://github.com/imatefx/zenn.git
cd zenn
swift build -c release
```

The binary is at `.build/release/zenn-app`.

## Quick Start

1. Run `zenn-app`
2. Grant Accessibility permission when prompted
3. A default config is created at `~/.config/zenn/init.lua`
4. Zenn appears in your menu bar and begins tiling

## Default Keybindings

| Action | Keys |
|--------|------|
| Focus | `⌥` + Arrow Keys |
| Move window | `⌥⇧` + Arrow Keys |
| Resize (grow/shrink) | `⌥⌃` + Arrow Keys |
| Merge into split | `⌥⌃⇧` + Arrow Keys |
| Eject from split | `⌥` + `E` |
| Switch workspace | `⌥` + `1-9` |
| Move to workspace | `⌥⇧` + `1-9` |
| Toggle fullscreen | `⌥` + `F` |
| Toggle floating | `⌥⇧` + `F` |
| Toggle sticky | `⌥⇧` + `S` |
| Split vertical | `⌥` + `V` |
| Split horizontal | `⌥` + `B` |
| Equal split preset | `⌥` + `=` |
| Reload config | `⌥⇧` + `R` |

## Configuration

Edit `~/.config/zenn/init.lua`:

```lua
local zenn = require("zenn")

-- Keybindings
zenn.bind({"alt"}, "left", function() zenn.focus("left") end)
zenn.bind({"alt"}, "right", function() zenn.focus("right") end)
zenn.bind({"alt"}, "down", function() zenn.focus("down") end)
zenn.bind({"alt"}, "up", function() zenn.focus("up") end)

-- Workspaces
for i = 1, 9 do
    zenn.bind({"alt"}, tostring(i), function() zenn.workspace(i) end)
    zenn.bind({"alt", "shift"}, tostring(i), function() zenn.move_to_workspace(i) end)
end

-- Window rules
zenn.rule({ app = "Finder", floating = true })
zenn.rule({ app = "System Settings", floating = true })

-- Gaps
zenn.gaps({ inner = 8, outer = 8 })
```

See [docs/v1/config-reference.md](docs/v1/config-reference.md) for full API documentation.

## CLI

```bash
zenn focus left
zenn move right
zenn workspace 2
zenn query windows --format json
zenn subscribe --events workspace_switched
zenn reload
```

## Architecture

```
ZennShared     # Shared types (no platform deps)
ZennMacOS      # macOS accessibility, display, input APIs
ZennCore       # Tiling engine, tree, layout, focus, state
ZennLua        # Lua 5.4 config engine
ZennIPC        # Unix socket + HTTP server
ZennApp        # Menu bar application
ZennCLI        # Command-line client
```

See [docs/v1/architecture.md](docs/v1/architecture.md) for details.

## License

MIT — see [LICENSE](LICENSE).
