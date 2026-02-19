# Zenn

A native macOS tiling window manager written in Swift.

Inspired by i3, AeroSpace, and yabai — with better performance and a richer feature set including sticky windows, Lua scripting configuration, comprehensive hooks, and full state persistence.

## Features

- **Tiling layouts**: Horizontal/vertical splits with configurable ratios
- **Virtual workspaces**: Independent per-monitor, numbered and named
- **Lua configuration**: Full scripting via `~/.config/zenn/init.lua`
- **Floating & sticky windows**: Float above tiled, sticky visible on all workspaces
- **Focus management**: Directional (L/R/U/D) and cycle (next/prev)
- **Resize**: Keyboard, mouse drag, and presets (50/50, 60/40, 70/30)
- **IPC**: Unix socket + HTTP API + CLI tool
- **Hooks**: Comprehensive event system for window/workspace/app/monitor events
- **Window rules**: Lua + regex matching on app name, title, bundle ID
- **State persistence**: Full tree, assignments, and positions saved across restarts
- **Configurable gaps**: Inner + outer per-side, per workspace/monitor
- **Focus border**: Configurable colored border overlay
- **Animations**: Optional smooth transitions (off by default)
- **Menu bar app**: Lives in your menu bar, no Dock icon

## Requirements

- macOS 14+ (Sonoma)
- Accessibility permissions (no SIP disable required)
- Lua 5.4 (`brew install lua@5.4`)

## Installation

### Homebrew

```bash
brew install zenn
```

### From Source

```bash
git clone https://github.com/your-org/zenn.git
cd zenn
swift build -c release
```

## Quick Start

1. Grant Accessibility permission when prompted
2. Create config at `~/.config/zenn/init.lua` (a default is created on first launch)
3. Zenn appears in your menu bar and begins tiling

## Configuration

```lua
local zenn = require("zenn")

-- Keybindings (modifier + key)
zenn.bind({"alt"}, "h", function() zenn.focus("left") end)
zenn.bind({"alt"}, "l", function() zenn.focus("right") end)
zenn.bind({"alt"}, "j", function() zenn.focus("down") end)
zenn.bind({"alt"}, "k", function() zenn.focus("up") end)

-- Window rules
zenn.rule({ app = "Finder", floating = true })
zenn.rule({ app = "System Settings", floating = true })

-- Gaps
zenn.gaps({ inner = 8, outer = 8 })
```

See [Configuration Reference](docs/v1/config-reference.md) for full documentation.

## CLI

```bash
zenn focus left
zenn move right
zenn workspace 2
zenn query windows --format json
zenn subscribe --events workspace_switched
zenn reload
```

## License

GPL v3 — see [LICENSE](LICENSE) for details.
