import Foundation

/// IPC command types that can be sent from CLI to daemon.
public enum Command: Codable, Sendable {
    // Focus
    case focus(Direction)
    case focusCycle(CycleDirection)

    // Window operations
    case moveWindow(Direction)
    case moveToWorkspace(WorkspaceID)
    case moveToMonitor(DisplayID)
    case swapWindow(Direction)
    case resizeWindow(Direction, Double)
    case setWindowMode(WindowMode)
    case closeWindow

    // Workspace
    case switchWorkspace(WorkspaceID)
    case renameWorkspace(WorkspaceID, String)

    // Layout
    case setSplitAxis(SplitAxis)
    case toggleSplitAxis
    case setLayoutMode(LayoutMode)
    case applyPreset(ResizePreset)

    // Queries
    case queryWindows
    case queryWorkspaces
    case queryMonitors
    case queryFocused
    case queryTree(WorkspaceID?)

    // System
    case reload
    case restart
    case quit

    // Events
    case subscribe([HookEventType])
}

/// Response from the daemon to CLI.
public struct CommandResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let data: ResponseData?

    public init(success: Bool, message: String? = nil, data: ResponseData? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }

    public static func ok(_ message: String? = nil) -> CommandResponse {
        CommandResponse(success: true, message: message)
    }

    public static func error(_ message: String) -> CommandResponse {
        CommandResponse(success: false, message: message)
    }
}

/// Data payloads for query responses.
public enum ResponseData: Codable, Sendable {
    case windows([WindowInfo])
    case workspaces([WorkspaceInfo])
    case monitors([MonitorInfo])
    case focused(WindowInfo?)
    case tree(TreeSnapshot)
}

/// Resize presets for quick layout adjustments.
public enum ResizePreset: String, Codable, Sendable {
    case equal     // 50/50
    case masterLg  // 60/40
    case masterXl  // 70/30
}

/// Serializable snapshot of the tiling tree for IPC.
public struct TreeSnapshot: Codable, Sendable {
    public let nodeType: TreeSnapshotNodeType
    public let id: String
    public let children: [TreeSnapshot]?
    public let axis: SplitAxis?
    public let ratios: [Double]?
    public let windowID: WindowID?
    public let appName: String?
    public let windowTitle: String?
    public let frame: Rect?

    public init(
        nodeType: TreeSnapshotNodeType,
        id: String,
        children: [TreeSnapshot]? = nil,
        axis: SplitAxis? = nil,
        ratios: [Double]? = nil,
        windowID: WindowID? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        frame: Rect? = nil
    ) {
        self.nodeType = nodeType
        self.id = id
        self.children = children
        self.axis = axis
        self.ratios = ratios
        self.windowID = windowID
        self.appName = appName
        self.windowTitle = windowTitle
        self.frame = frame
    }
}

public enum TreeSnapshotNodeType: String, Codable, Sendable {
    case container
    case window
}

/// Hook event types for subscription.
public enum HookEventType: String, Codable, Sendable, CaseIterable {
    case windowCreated = "window_created"
    case windowDestroyed = "window_destroyed"
    case windowFocused = "window_focused"
    case windowMoved = "window_moved"
    case windowResized = "window_resized"
    case windowMinimized = "window_minimized"
    case windowDeminimized = "window_deminimized"
    case windowTitleChanged = "window_title_changed"
    case windowModeChanged = "window_mode_changed"
    case workspaceSwitched = "workspace_switched"
    case workspaceCreated = "workspace_created"
    case workspaceDestroyed = "workspace_destroyed"
    case appLaunched = "app_launched"
    case appTerminated = "app_terminated"
    case monitorConnected = "monitor_connected"
    case monitorDisconnected = "monitor_disconnected"
    case configReloaded = "config_reloaded"
    case tilingLayoutChanged = "tiling_layout_changed"
}
