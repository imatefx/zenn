# IPC & CLI API Reference

Zenn exposes two IPC interfaces for external communication: a Unix domain socket and an HTTP REST API. Both are served by the running `zenn-app` daemon and share the same command router.

---

## Unix Domain Socket

**Path:** `$TMPDIR/zenn.sock` (e.g., `/var/folders/.../T/zenn.sock`)

### Wire Protocol

Messages use a length-prefixed JSON format:

```
[4 bytes: big-endian uint32 payload length][N bytes: JSON payload]
```

**Request:** The JSON payload is a `Command` enum value encoded as a tagged JSON object.

**Response:** The JSON payload is a `CommandResponse` object:

```json
{
  "success": true,
  "message": "Focused left",
  "data": null
}
```

For query commands, the `data` field contains the result:

```json
{
  "success": true,
  "message": null,
  "data": {
    "windows": [...]
  }
}
```

### Connection Lifecycle

1. Client opens a Unix domain socket connection.
2. Client sends one length-prefixed JSON command.
3. Server processes the command and sends one length-prefixed JSON response.
4. Client reads the response and closes the connection.

Connections are not persistent; each command requires a new connection.

### Command JSON Format

Commands are serialized as tagged enums. The tag is the first key in the JSON object:

```json
{"focus": {"_0": "left"}}
```

```json
{"switchWorkspace": {"_0": {"number": 2}}}
```

```json
{"queryWindows": {}}
```

```json
{"resizeWindow": {"_0": "right", "_1": 0.05}}
```

---

## HTTP REST API

**Base URL:** `http://localhost:19876`

All responses are JSON with `Content-Type: application/json` and `Access-Control-Allow-Origin: *`.

Successful responses return HTTP 200. Failed responses return HTTP 400.

### Endpoints

#### GET /api/v1/health

Health check. Returns `{"success": true, "message": "Zenn is running"}`.

```bash
curl http://localhost:19876/api/v1/health
```

---

#### GET /api/v1/windows

List all tracked windows.

**Response:**

```json
{
  "success": true,
  "data": {
    "windows": [
      {
        "windowID": {"rawValue": 1234},
        "appName": "Safari",
        "appBundleID": "com.apple.Safari",
        "title": "Apple",
        "frame": {"x": 0, "y": 25, "width": 960, "height": 1055},
        "mode": "tiled",
        "workspaceID": {"number": 1},
        "monitorID": {"rawValue": 1},
        "isFocused": true,
        "isMinimized": false
      }
    ]
  }
}
```

```bash
curl http://localhost:19876/api/v1/windows
```

---

#### GET /api/v1/workspaces

List all workspaces across all monitors.

**Response:**

```json
{
  "success": true,
  "data": {
    "workspaces": [
      {
        "id": {"number": 1},
        "monitorID": {"rawValue": 1},
        "isActive": true,
        "windowCount": 3,
        "focusedWindowID": {"rawValue": 1234},
        "layoutMode": "tiling"
      },
      {
        "id": {"number": 2},
        "monitorID": {"rawValue": 1},
        "isActive": false,
        "windowCount": 1,
        "focusedWindowID": {"rawValue": 5678},
        "layoutMode": "tiling"
      }
    ]
  }
}
```

```bash
curl http://localhost:19876/api/v1/workspaces
```

---

#### GET /api/v1/monitors

List all connected monitors.

**Response:**

```json
{
  "success": true,
  "data": {
    "monitors": [
      {
        "displayID": {"rawValue": 1},
        "frame": {"x": 0, "y": 0, "width": 1920, "height": 1080},
        "visibleFrame": {"x": 0, "y": 25, "width": 1920, "height": 1055},
        "activeWorkspaceID": {"number": 1},
        "workspaceIDs": [
          {"number": 1},
          {"number": 2},
          {"number": 3}
        ]
      }
    ]
  }
}
```

```bash
curl http://localhost:19876/api/v1/monitors
```

---

#### GET /api/v1/focused

Get the currently focused window.

**Response:**

```json
{
  "success": true,
  "data": {
    "focused": {
      "windowID": {"rawValue": 1234},
      "appName": "Terminal",
      "appBundleID": "com.apple.Terminal",
      "title": "bash",
      "frame": {"x": 0, "y": 25, "width": 960, "height": 1055},
      "mode": "tiled",
      "workspaceID": {"number": 1},
      "monitorID": {"rawValue": 1},
      "isFocused": true,
      "isMinimized": false
    }
  }
}
```

Returns `"focused": null` if no window is focused.

```bash
curl http://localhost:19876/api/v1/focused
```

---

#### GET /api/v1/tree

Get the tiling tree for the focused workspace.

**Response:**

```json
{
  "success": true,
  "data": {
    "tree": {
      "nodeType": "container",
      "id": "A1B2C3D4-...",
      "axis": "horizontal",
      "ratios": [0.5, 0.5],
      "children": [
        {
          "nodeType": "window",
          "id": "E5F6G7H8-...",
          "windowID": {"rawValue": 1234},
          "appName": "Safari",
          "windowTitle": "Apple",
          "frame": {"x": 8, "y": 33, "width": 948, "height": 1039}
        },
        {
          "nodeType": "container",
          "id": "I9J0K1L2-...",
          "axis": "vertical",
          "ratios": [0.5, 0.5],
          "children": [
            {
              "nodeType": "window",
              "id": "M3N4O5P6-...",
              "windowID": {"rawValue": 5678},
              "appName": "Terminal",
              "windowTitle": "bash",
              "frame": {"x": 968, "y": 33, "width": 944, "height": 515}
            },
            {
              "nodeType": "window",
              "id": "Q7R8S9T0-...",
              "windowID": {"rawValue": 9012},
              "appName": "Code",
              "windowTitle": "main.swift",
              "frame": {"x": 968, "y": 556, "width": 944, "height": 515}
            }
          ]
        }
      ]
    }
  }
}
```

```bash
curl http://localhost:19876/api/v1/tree
```

---

#### POST /api/v1/command

Send any command as a JSON body.

**Request body:** A JSON-encoded `Command` value.

**Examples:**

```bash
# Focus left
curl -X POST http://localhost:19876/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"focus": {"_0": "left"}}'

# Switch to workspace 3
curl -X POST http://localhost:19876/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"switchWorkspace": {"_0": {"number": 3}}}'

# Resize window right by 5%
curl -X POST http://localhost:19876/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"resizeWindow": {"_0": "right", "_1": 0.05}}'

# Apply equal preset
curl -X POST http://localhost:19876/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"applyPreset": {"_0": "equal"}}'

# Reload config
curl -X POST http://localhost:19876/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"reload": {}}'
```

---

## CLI Reference

The `zenn` CLI communicates with the daemon over the Unix socket. All commands print a JSON response to stdout and exit with code 0 on success or 1 on failure.

### zenn focus

Move focus to a window in a direction.

```
zenn focus <direction>
```

**direction:** `left`, `right`, `up`, `down`, `next`, `prev`

The `next` and `prev` directions cycle through windows in tree-traversal order (left-to-right, top-to-bottom).

```bash
zenn focus left
zenn focus next
```

---

### zenn move

Swap the focused window with its neighbor.

```
zenn move <direction>
```

**direction:** `left`, `right`, `up`, `down`

```bash
zenn move right
```

---

### zenn resize

Resize the focused window.

```
zenn resize <direction> [--delta <value>]
```

**direction:** `left`, `right`, `up`, `down`
**--delta / -d:** Resize amount as a fraction (default: 0.05 = 5%)

```bash
zenn resize right
zenn resize left --delta 0.1
```

---

### zenn swap

Swap the focused window with a neighbor.

```
zenn swap <direction>
```

**direction:** `left`, `right`, `up`, `down`

```bash
zenn swap down
```

---

### zenn workspace

Switch to a workspace.

```
zenn workspace <number>
```

```bash
zenn workspace 2
```

---

### zenn move-to-workspace

Move the focused window to a workspace.

```
zenn move-to-workspace <number>
```

```bash
zenn move-to-workspace 3
```

---

### zenn layout

Change layout settings.

```
zenn layout <action> [value]
```

**Actions:**

| Action | Description |
|---|---|
| `split-h` | Set default split axis to horizontal |
| `split-v` | Set default split axis to vertical |
| `toggle-split` | Toggle the default split axis |
| `monocle` | Switch workspace to monocle mode |
| `tiling` | Switch workspace to tiling mode |
| `preset <name>` | Apply a resize preset (`equal`, `masterLg`, `masterXl`) |

```bash
zenn layout split-v
zenn layout monocle
zenn layout preset equal
zenn layout preset masterLg
```

---

### zenn toggle

Toggle a window mode on the focused window.

```
zenn toggle <mode>
```

**mode:** `floating`, `sticky`, `fullscreen`, `tiled`

```bash
zenn toggle floating
zenn toggle fullscreen
```

---

### zenn query

Query state information.

```
zenn query <target> [--format json]
```

**target:** `windows`, `workspaces`, `monitors`, `focused`, `tree`

```bash
zenn query windows
zenn query focused
zenn query tree
```

---

### zenn subscribe

Subscribe to real-time events.

```
zenn subscribe [--events <types>]
```

**--events:** Comma-separated list of event types. Omit for all events.

The connection stays open and prints each event as a JSON line.

```bash
zenn subscribe
zenn subscribe --events workspace_switched,window_focused
```

**Event types:** `window_created`, `window_destroyed`, `window_focused`, `window_moved`, `window_resized`, `window_minimized`, `window_deminimized`, `window_title_changed`, `window_mode_changed`, `workspace_switched`, `workspace_created`, `workspace_destroyed`, `app_launched`, `app_terminated`, `monitor_connected`, `monitor_disconnected`, `config_reloaded`, `tiling_layout_changed`

---

### zenn reload

Reload the configuration file.

```bash
zenn reload
```

---

### zenn quit

Quit the Zenn daemon.

```bash
zenn quit
```

---

## Error Handling

All commands return a `CommandResponse` JSON object:

```json
{
  "success": false,
  "message": "No window in direction left",
  "data": null
}
```

The CLI exits with code 1 when `success` is `false`. When the daemon is not running, the CLI prints `Error: Cannot connect to Zenn daemon. Is it running?` to stderr and exits with code 1.
