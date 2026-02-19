# User Guide

## Installation

### Homebrew (Recommended)

```bash
brew install zenn
```

This installs both the `zenn-app` daemon and the `zenn` CLI tool.

### From Source

**Prerequisites:**
- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Lua 5.4 (`brew install lua@5.4`)

**Build:**

```bash
git clone https://github.com/your-org/zenn.git
cd zenn
swift build -c release
```

The compiled binaries are at:
- `.build/release/zenn-app` (daemon)
- `.build/release/zenn` (CLI)

Copy them to a directory in your `$PATH`:

```bash
cp .build/release/zenn-app /usr/local/bin/
cp .build/release/zenn /usr/local/bin/
```

---

## First Launch

1. **Start Zenn:**

   ```bash
   zenn-app
   ```

   Or double-click the Zenn.app bundle if installed via Homebrew.

2. **Grant Accessibility Permission:**

   On first launch, macOS will prompt you to grant Accessibility access. You must enable this for Zenn to manage windows.

   Go to **System Settings > Privacy & Security > Accessibility** and toggle Zenn on.

   Zenn does not require SIP to be disabled. Only the standard Accessibility permission is needed.

3. **Menu Bar Icon:**

   Zenn runs as a menu bar application. Look for the Zenn icon in the right side of your menu bar. It does not appear in the Dock or in Cmd+Tab.

   The menu bar icon provides:
   - Current workspace number
   - Reload Configuration
   - Toggle Tiling On/Off
   - Quit

4. **Default Configuration:**

   On first launch, Zenn creates a default configuration at `~/.config/zenn/init.lua` if one does not exist. This config includes basic vi-style keybindings (Alt + h/j/k/l for focus) and sensible window rules.

---

## Configuration

The configuration file is a Lua 5.4 script located at:

```
~/.config/zenn/init.lua
```

Edit it with any text editor. After making changes, reload without restarting:

- Press **Alt+Shift+R** (default binding), or
- Run `zenn reload` from the terminal, or
- Click **Reload Configuration** in the menu bar menu.

### Minimal Configuration

```lua
local zenn = require("zenn")

-- Focus: Alt + h/j/k/l
zenn.bind({"alt"}, "h", function() zenn.focus("left") end)
zenn.bind({"alt"}, "l", function() zenn.focus("right") end)
zenn.bind({"alt"}, "j", function() zenn.focus("down") end)
zenn.bind({"alt"}, "k", function() zenn.focus("up") end)

-- Gaps
zenn.gaps({ inner = 8, outer = 8 })
```

### Understanding Modifiers

| Config Name | macOS Key |
|---|---|
| `"alt"` or `"opt"` or `"option"` | Option key |
| `"cmd"` or `"command"` or `"super"` | Command key |
| `"ctrl"` or `"control"` | Control key |
| `"shift"` | Shift key |

Combine multiple modifiers in the table:

```lua
zenn.bind({"alt", "shift"}, "h", function() ... end)
```

---

## Keybindings

The default configuration uses a vi-inspired layout. Here is a recommended binding scheme:

### Focus (navigate between windows)

| Binding | Action |
|---|---|
| Alt + H | Focus left |
| Alt + L | Focus right |
| Alt + J | Focus down |
| Alt + K | Focus up |

### Move (swap window position)

| Binding | Action |
|---|---|
| Alt + Shift + H | Move window left |
| Alt + Shift + L | Move window right |
| Alt + Shift + J | Move window down |
| Alt + Shift + K | Move window up |

### Resize (grow/shrink window)

| Binding | Action |
|---|---|
| Alt + Ctrl + H | Grow left |
| Alt + Ctrl + L | Grow right |
| Alt + Ctrl + J | Grow down |
| Alt + Ctrl + K | Grow up |

### Workspaces

| Binding | Action |
|---|---|
| Alt + 1-9 | Switch to workspace 1-9 |
| Alt + Shift + 1-9 | Move window to workspace 1-9 |

### Window Modes

| Binding | Action |
|---|---|
| Alt + F | Toggle fullscreen |
| Alt + Shift + F | Toggle floating |
| Alt + Shift + S | Toggle sticky |

### Layout

| Binding | Action |
|---|---|
| Alt + V | Set vertical split for next window |
| Alt + B | Set horizontal split for next window |
| Alt + = | Apply equal (50/50) preset |

### System

| Binding | Action |
|---|---|
| Alt + Shift + R | Reload configuration |

---

## Workspaces

Zenn provides 9 virtual workspaces per monitor, numbered 1 through 9. Workspaces are independent per monitor: if you have two monitors, each has its own set of 9 workspaces.

### How Workspaces Work

Zenn does not use macOS Spaces. Instead, it implements virtual workspaces by moving windows offscreen when they are not on the active workspace.

- Switching to workspace 2 moves all workspace 1 windows to coordinates far offscreen and restores workspace 2 windows to their calculated positions.
- Windows on inactive workspaces are not visible but remain in memory. Switching back is instant.
- Mission Control will show all windows in a flat list, regardless of workspace assignment.

### Workspace Operations

**Switch workspace:**

```lua
zenn.workspace(3)  -- switch to workspace 3
```

If you switch to the workspace you are already on, Zenn performs a "back-and-forth" switch to the previously active workspace. This is useful for toggling between two workspaces.

**Move window to workspace:**

```lua
zenn.move_to_workspace(3)  -- move focused window to workspace 3
```

The window is removed from the current workspace's tiling tree and added to the target workspace. The current workspace re-tiles to fill the gap. If the target workspace is not visible, the window is moved offscreen.

---

## Window Rules

Window rules let you automatically configure windows based on their application name, window title, or bundle ID.

### Floating Windows

Some windows should not be tiled. System dialogs, preferences windows, and small utility apps are better floating:

```lua
zenn.rule({ app = "System Settings", floating = true })
zenn.rule({ app = "Calculator", floating = true })
zenn.rule({ app = "Archive Utility", floating = true })
```

### Title Matching

Match specific window titles using regex patterns:

```lua
-- Float Finder's copy/move progress windows but tile regular Finder windows
zenn.rule({ app = "Finder", title = "Copy", floating = true })
zenn.rule({ app = "Finder", title = "Move", floating = true })

-- Float any preferences window
zenn.rule({ title = ".*Preferences.*", floating = true })
```

### Auto-Assign Workspaces

Route applications to specific workspaces:

```lua
zenn.rule({ app = "Slack", workspace = 3 })
zenn.rule({ app = "Mail", workspace = 4 })
zenn.rule({ app = "Spotify", workspace = 5 })
```

### Sticky Windows

Make a window visible on all workspaces:

```lua
zenn.rule({ app = "Music", sticky = true })
```

### Bundle ID Matching

For more precise matching, use the application's bundle identifier:

```lua
zenn.rule({ bundle_id = "com.apple.Safari", workspace = 2 })
zenn.rule({ bundle_id = "com.googlecode.iterm2", workspace = 1 })
```

### Rule Evaluation Order

Rules are evaluated in the order they are defined. The first matching rule wins. If no rule matches, the window is tiled normally.

---

## Window Modes

Every window in Zenn is in one of four modes:

| Mode | Behavior |
|---|---|
| **Tiled** | Participates in the tiling layout. Position and size are controlled by the tree. |
| **Floating** | Removed from the tiling tree. Floats above tiled windows. User can position freely. Stays on its assigned workspace. |
| **Sticky** | Like floating, but visible on all workspaces. Not affected by workspace switching. |
| **Fullscreen** | Fills the entire workspace area. Other tiled windows remain in the tree but are hidden. |

Toggle between modes using the keybindings or CLI:

```bash
zenn toggle floating
zenn toggle fullscreen
```

---

## Layout Modes

Each workspace has a layout mode:

### Tiling (Default)

Windows are arranged according to the binary split tree. Each split divides space either horizontally (left/right) or vertically (top/bottom) based on configurable ratios.

### Monocle

Every window occupies the full workspace. Only the focused window is visible. Use focus next/prev to cycle through windows:

```lua
zenn.toggle_monocle()
```

---

## Gaps

Gaps add spacing between windows and from screen edges. Configure globally:

```lua
zenn.gaps({ inner = 8, outer = 8 })
```

- **inner:** Pixels between adjacent tiled windows.
- **outer:** Pixels from the screen edges on all four sides.

Values are in screen points. Set both to 0 for a borderless layout.

---

## Using the CLI

The `zenn` CLI tool lets you control the window manager from the terminal or from scripts.

### Query State

```bash
# List all windows as JSON
zenn query windows

# Get the focused window
zenn query focused

# Inspect the tiling tree
zenn query tree

# List workspaces
zenn query workspaces
```

### Control Windows

```bash
# Focus and move
zenn focus left
zenn move right

# Resize with custom delta
zenn resize right --delta 0.1

# Change workspace
zenn workspace 2
zenn move-to-workspace 3

# Layout operations
zenn layout preset equal
zenn layout monocle
```

### Subscribe to Events

Keep a connection open to receive real-time events:

```bash
# All events
zenn subscribe

# Specific events only
zenn subscribe --events workspace_switched,window_focused
```

This is useful for integrating with status bars or notification scripts.

### Scripting Example

Combine CLI commands in a shell script:

```bash
#!/bin/bash
# Move the focused window to workspace 2 and switch there
zenn move-to-workspace 2
zenn workspace 2
```

---

## Troubleshooting

### Zenn does not start / no menu bar icon

1. Check that Accessibility permission is granted: **System Settings > Privacy & Security > Accessibility**.
2. If you recently updated Zenn, you may need to remove and re-add it in the Accessibility list.
3. Check for error messages: run `zenn-app` from a terminal to see console output.

### Keybindings do not work

1. Verify the hotkey manager started successfully. Look for `[Zenn] Warning: Failed to start hotkey manager` in console output.
2. Some key combinations may conflict with macOS system shortcuts or other applications. Try a different modifier combination.
3. After editing the config, remember to reload: `zenn reload` or Alt+Shift+R.

### CLI says "Cannot connect to Zenn daemon"

The `zenn-app` daemon is not running. Start it first:

```bash
zenn-app
```

### Config errors

If the Lua config has syntax errors, Zenn logs them to the console:

```
[Zenn] Config error: init.lua:15: attempt to call a nil value
```

Fix the error and reload. The previous working configuration (keybindings, rules) will have been cleared by the reload attempt, so ensure the config file is valid before reloading.

### Windows are not tiling

1. Check that tiling is enabled via the menu bar menu.
2. The window may be matched by a rule that sets it to floating. Check your `zenn.rule()` definitions.
3. Some applications create non-standard windows (e.g., splash screens, tooltips) that Zenn intentionally ignores.

### Resetting to defaults

Delete the config file and restart Zenn:

```bash
rm ~/.config/zenn/init.lua
# Restart zenn-app; a new default config will be created
```
