# Lua Configuration Reference

Zenn is configured through a Lua 5.4 script at `~/.config/zenn/init.lua`. A default configuration is created on first launch.

All API functions are accessed through the `zenn` module:

```lua
local zenn = require("zenn")
```

---

## zenn.bind(modifiers, key, callback)

Register a global hotkey binding.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `modifiers` | `table` | Array of modifier strings |
| `key` | `string` | Key name (single character or special key name) |
| `callback` | `function` | Function to call when the hotkey is pressed |

**Modifier strings:** `"cmd"` / `"command"` / `"super"`, `"alt"` / `"opt"` / `"option"`, `"ctrl"` / `"control"`, `"shift"`

**Key names:** Single characters (`"a"` through `"z"`, `"0"` through `"9"`, `"="`, `"-"`, etc.) or special keys (`"space"`, `"return"`, `"tab"`, `"escape"`, `"delete"`, `"left"`, `"right"`, `"up"`, `"down"`, `"f1"` through `"f12"`).

**Example:**

```lua
zenn.bind({"alt"}, "h", function() zenn.focus("left") end)
zenn.bind({"alt", "shift"}, "l", function() zenn.move("right") end)
zenn.bind({"cmd", "ctrl"}, "space", function() zenn.toggle_floating() end)
```

**Notes:**
- Bindings are global: they capture the key event before it reaches any application.
- On config reload, all previous bindings are cleared and re-registered.
- Multiple modifiers are combined with a logical OR of the modifier flags.

---

## zenn.focus(direction)

Move focus to the nearest window in the given direction.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `direction` | `string` | One of: `"left"`, `"right"`, `"up"`, `"down"` |

**Behavior:**
- Uses geometric proximity to find the nearest neighbor. For horizontal directions, horizontal distance is weighted more heavily; for vertical directions, vertical distance is weighted more.
- If no window exists in the given direction, the focus does not change.
- Focus changes are reflected both in the internal state and via the Accessibility API (the target window is raised and its app is activated).

**Example:**

```lua
zenn.bind({"alt"}, "h", function() zenn.focus("left") end)
zenn.bind({"alt"}, "j", function() zenn.focus("down") end)
zenn.bind({"alt"}, "k", function() zenn.focus("up") end)
zenn.bind({"alt"}, "l", function() zenn.focus("right") end)
```

---

## zenn.move(direction)

Swap the focused window with its neighbor in the given direction within the tiling tree.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `direction` | `string` | One of: `"left"`, `"right"`, `"up"`, `"down"` |

**Behavior:**
- Finds the neighbor in the specified direction using the same geometric algorithm as `focus`.
- Swaps the two windows' positions in the tree. Both windows are re-laid out.
- If no neighbor exists in the given direction, the operation is a no-op.

**Example:**

```lua
zenn.bind({"alt", "shift"}, "h", function() zenn.move("left") end)
zenn.bind({"alt", "shift"}, "l", function() zenn.move("right") end)
```

---

## zenn.move_to_workspace(number)

Move the focused window to a different workspace.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `number` | `integer` | Workspace number (1-9) |

**Behavior:**
- Removes the focused window from the current workspace's tiling tree.
- Inserts it into the target workspace's tiling tree.
- Re-tiles both the source and target workspaces.
- If the target workspace is not currently visible, the window is moved offscreen.

**Example:**

```lua
for i = 1, 9 do
    zenn.bind({"alt", "shift"}, tostring(i), function()
        zenn.move_to_workspace(i)
    end)
end
```

---

## zenn.resize(direction)

Resize the focused window by adjusting the split ratio with its neighbor.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `direction` | `string` | One of: `"left"`, `"right"`, `"up"`, `"down"` |

**Behavior:**
- Grows the focused window in the given direction by adjusting the split ratio in the parent container.
- The resize walks up the tree to find a container whose axis matches the direction. For example, resizing "right" looks for a horizontal-axis container.
- The default delta is 0.05 (5% of the container's dimension).
- Ratios are clamped so that no window's ratio drops below 0.1 (10%).

**Example:**

```lua
zenn.bind({"alt", "ctrl"}, "h", function() zenn.resize("left") end)
zenn.bind({"alt", "ctrl"}, "l", function() zenn.resize("right") end)
zenn.bind({"alt", "ctrl"}, "j", function() zenn.resize("down") end)
zenn.bind({"alt", "ctrl"}, "k", function() zenn.resize("up") end)
```

---

## zenn.workspace(number)

Switch to a workspace by number.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `number` | `integer` | Workspace number (1-9) |

**Behavior:**
- Hides all windows on the current workspace (moves offscreen).
- Activates the target workspace on the current monitor.
- Shows all windows on the target workspace at their calculated positions.
- Focuses the previously-focused window on the target workspace.
- If the target is the current workspace, performs a "back-and-forth" switch to the previously active workspace.

**Example:**

```lua
for i = 1, 9 do
    zenn.bind({"alt"}, tostring(i), function() zenn.workspace(i) end)
end
```

---

## zenn.rule(config)

Define a window rule that automatically applies settings to matching windows.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `config` | `table` | Rule configuration table |

**Config table fields:**

| Field | Type | Description |
|---|---|---|
| `app` | `string` | Regex pattern matched against the application name (case-insensitive) |
| `title` | `string` | Regex pattern matched against the window title (case-insensitive) |
| `bundle_id` | `string` | Exact match on the application's bundle identifier |
| `floating` | `boolean` | If `true`, the window floats above tiled windows |
| `sticky` | `boolean` | If `true`, the window is visible on all workspaces |
| `workspace` | `integer` | Automatically move matching windows to this workspace number |

**Matching behavior:**
- All specified fields must match for the rule to apply. Omitted fields are not checked.
- `app` and `title` use NSRegularExpression syntax with case-insensitive matching.
- If both `floating` and `sticky` are set, `sticky` takes precedence (sticky implies floating).
- Rules are evaluated in order; the first matching rule wins.
- Rules apply to windows at creation time. Existing windows are not retroactively affected on config reload.

**Example:**

```lua
-- Float utility apps
zenn.rule({ app = "System Settings", floating = true })
zenn.rule({ app = "Calculator", floating = true })
zenn.rule({ app = "Finder", title = "Copy", floating = true })

-- Sticky windows
zenn.rule({ app = "Music", sticky = true })

-- Auto-assign to workspaces
zenn.rule({ app = "Slack", workspace = 3 })
zenn.rule({ app = "Mail", workspace = 4 })
zenn.rule({ bundle_id = "com.apple.Safari", workspace = 2 })

-- Regex patterns
zenn.rule({ title = ".*Preferences.*", floating = true })
```

---

## zenn.gaps(config)

Configure the spacing between and around tiled windows.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `config` | `table` | Gap configuration table |

**Config table fields:**

| Field | Type | Description |
|---|---|---|
| `inner` | `number` | Pixel gap between adjacent tiled windows |
| `outer` | `number` | Pixel gap from screen edges (uniform on all sides) |

**Behavior:**
- Sets the global gap configuration. Gaps apply to all monitors and workspaces unless overridden.
- Gap values are in screen points (not physical pixels).
- Inner gaps are applied as half the value on each side of a window (so two adjacent windows have a full `inner` gap between them).
- Outer gaps define the padding from the screen's visible frame (already excluding the menu bar and Dock).

**Example:**

```lua
-- Comfortable spacing
zenn.gaps({ inner = 8, outer = 8 })

-- Dense layout, no gaps
zenn.gaps({ inner = 0, outer = 0 })

-- Wide outer margins
zenn.gaps({ inner = 6, outer = 16 })
```

---

## zenn.on(event, callback)

Register a callback for a window manager event (hook).

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `event` | `string` | Event type name |
| `callback` | `function` | Function called with an event data table |

**Event types:**

| Event | Data Fields | Description |
|---|---|---|
| `"window_created"` | `window_id`, `app_name`, `title` | A new window was tiled |
| `"window_destroyed"` | `window_id`, `app_name` | A window was removed |
| `"window_focused"` | `window_id`, `app_name`, `title` | Focus changed to a window |
| `"window_moved"` | `window_id`, `app_name` | A window's position changed |
| `"window_resized"` | `window_id`, `app_name` | A window's size changed |
| `"window_minimized"` | `window_id`, `app_name` | A window was minimized |
| `"window_deminimized"` | `window_id`, `app_name` | A window was restored from minimize |
| `"window_title_changed"` | `window_id`, `title` | A window's title changed |
| `"window_mode_changed"` | `window_id`, `mode` | Window mode changed (tiled/floating/sticky/fullscreen) |
| `"workspace_switched"` | `workspace_id`, `previous_workspace_id` | Active workspace changed |
| `"workspace_created"` | `workspace_id` | A new workspace was created |
| `"workspace_destroyed"` | `workspace_id` | A workspace was removed |
| `"app_launched"` | `app_name`, `bundle_id` | An application launched |
| `"app_terminated"` | `app_name`, `bundle_id` | An application quit |
| `"monitor_connected"` | `display_id` | A display was connected |
| `"monitor_disconnected"` | `display_id` | A display was disconnected |
| `"config_reloaded"` | (none) | Configuration was reloaded |
| `"tiling_layout_changed"` | (none) | The tiling layout was recalculated |

**Example:**

```lua
-- Log workspace changes
zenn.on("workspace_switched", function(event)
    print("Switched to workspace " .. event.workspace_id)
end)

-- Auto-float specific windows when they appear
zenn.on("window_created", function(event)
    if event.app_name == "Preview" then
        zenn.toggle_floating()
    end
end)

-- React to focus changes
zenn.on("window_focused", function(event)
    print("Focused: " .. event.app_name .. " - " .. event.title)
end)
```

---

## zenn.toggle_fullscreen()

Toggle the focused window between fullscreen and tiled mode.

**Behavior:**
- Fullscreen: the window fills the entire workspace area (respecting outer gaps).
- Other tiled windows remain in the tree but are not visible while a fullscreen window is active.
- Calling again restores the window to its tiled position.

---

## zenn.toggle_floating()

Toggle the focused window between floating and tiled mode.

**Behavior:**
- Floating windows are removed from the tiling tree and positioned above tiled windows.
- They stay on their assigned workspace but do not affect the tiling layout.
- Calling again reinserts the window into the tiling tree.

---

## zenn.toggle_sticky()

Toggle the focused window between sticky and tiled mode.

**Behavior:**
- Sticky windows float above all windows and are visible on all workspaces.
- They are removed from the tiling tree and not affected by workspace switching.
- Calling again restores the window to tiled mode on the current workspace.

---

## zenn.toggle_monocle()

Toggle the current workspace between tiling and monocle layout mode.

**Behavior:**
- Monocle mode: every tiled window on the workspace occupies the full workspace area. Only the focused window is visible.
- The tree structure is preserved; switching back to tiling mode restores the previous layout.
- Focus cycling (`next`/`prev`) switches between monocle windows.

---

## zenn.set_split(axis)

Set the default split axis for the next window insertion on the focused workspace.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `axis` | `string` | One of: `"horizontal"`, `"vertical"` |

**Behavior:**
- `"horizontal"`: the next window will be placed to the right of the focused window.
- `"vertical"`: the next window will be placed below the focused window.
- This sets the workspace's `defaultSplitAxis` property, which is used by `TreeOperations.insertWindow`.

**Example:**

```lua
zenn.bind({"alt"}, "b", function() zenn.set_split("horizontal") end)
zenn.bind({"alt"}, "v", function() zenn.set_split("vertical") end)
```

---

## zenn.preset(name)

Apply a resize preset to the root-level split on the focused workspace.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `name` | `string` | Preset name |

**Preset names:**

| Name | Split Ratio | Description |
|---|---|---|
| `"equal"` | 50 / 50 | Equal split |
| `"masterLg"` | 60 / 40 | Larger left pane |
| `"masterXl"` | 70 / 30 | Much larger left pane |

**Behavior:**
- Only applies when the root container has exactly 2 children.
- Directly sets the root container's ratios.
- Triggers a full layout recalculation.

**Example:**

```lua
zenn.bind({"alt"}, "=", function() zenn.preset("equal") end)
zenn.bind({"alt"}, "]", function() zenn.preset("masterLg") end)
zenn.bind({"alt"}, "\\", function() zenn.preset("masterXl") end)
```

---

## zenn.focused()

Query information about the currently focused window.

**Returns:** A table with window information, or `nil` if no window is focused.

**Return table fields:**

| Field | Type | Description |
|---|---|---|
| `id` | `integer` | The window's CGWindowID |
| `app` | `string` | Application name |
| `title` | `string` | Window title |
| `bundle_id` | `string` | Application bundle identifier |

**Example:**

```lua
local win = zenn.focused()
if win then
    print("Focused: " .. win.app .. " (" .. win.title .. ")")
end

-- Conditional behavior based on focused app
zenn.bind({"alt"}, "t", function()
    local win = zenn.focused()
    if win and win.app == "Terminal" then
        zenn.toggle_floating()
    else
        zenn.focus("down")
    end
end)
```

---

## zenn.reload()

Reload the configuration file.

**Behavior:**
- Clears all keybindings and window rules.
- Creates a fresh Lua bridge.
- Re-executes `~/.config/zenn/init.lua`.
- Re-registers all hotkeys with the event tap.
- Fires a `config_reloaded` hook event.
- Existing window assignments and tree structures are preserved.

**Example:**

```lua
zenn.bind({"alt", "shift"}, "r", function() zenn.reload() end)
```

---

## Complete Example Configuration

```lua
local zenn = require("zenn")

-- Focus: Alt + h/j/k/l
zenn.bind({"alt"}, "h", function() zenn.focus("left") end)
zenn.bind({"alt"}, "l", function() zenn.focus("right") end)
zenn.bind({"alt"}, "j", function() zenn.focus("down") end)
zenn.bind({"alt"}, "k", function() zenn.focus("up") end)

-- Move: Alt+Shift + h/j/k/l
zenn.bind({"alt", "shift"}, "h", function() zenn.move("left") end)
zenn.bind({"alt", "shift"}, "l", function() zenn.move("right") end)
zenn.bind({"alt", "shift"}, "j", function() zenn.move("down") end)
zenn.bind({"alt", "shift"}, "k", function() zenn.move("up") end)

-- Resize: Alt+Ctrl + h/j/k/l
zenn.bind({"alt", "ctrl"}, "h", function() zenn.resize("left") end)
zenn.bind({"alt", "ctrl"}, "l", function() zenn.resize("right") end)
zenn.bind({"alt", "ctrl"}, "j", function() zenn.resize("down") end)
zenn.bind({"alt", "ctrl"}, "k", function() zenn.resize("up") end)

-- Workspaces: Alt + 1-9
for i = 1, 9 do
    zenn.bind({"alt"}, tostring(i), function() zenn.workspace(i) end)
    zenn.bind({"alt", "shift"}, tostring(i), function()
        zenn.move_to_workspace(i)
    end)
end

-- Toggle modes
zenn.bind({"alt"}, "f", function() zenn.toggle_fullscreen() end)
zenn.bind({"alt", "shift"}, "f", function() zenn.toggle_floating() end)
zenn.bind({"alt", "shift"}, "s", function() zenn.toggle_sticky() end)

-- Split direction
zenn.bind({"alt"}, "v", function() zenn.set_split("vertical") end)
zenn.bind({"alt"}, "b", function() zenn.set_split("horizontal") end)

-- Layout presets
zenn.bind({"alt"}, "=", function() zenn.preset("equal") end)

-- Reload config
zenn.bind({"alt", "shift"}, "r", function() zenn.reload() end)

-- Window rules
zenn.rule({ app = "System Settings", floating = true })
zenn.rule({ app = "Calculator", floating = true })
zenn.rule({ app = "Finder", title = "Copy", floating = true })
zenn.rule({ app = "Slack", workspace = 3 })

-- Gaps
zenn.gaps({ inner = 8, outer = 8 })

-- Hooks
zenn.on("workspace_switched", function(event)
    print("[Zenn] Workspace: " .. event.workspace_id)
end)
```
