import Foundation

/// Snapshot of window information for IPC/serialization.
public struct WindowInfo: Codable, Sendable {
    public let windowID: WindowID
    public let appName: String
    public let appBundleID: String
    public let title: String
    public let frame: Rect
    public let mode: WindowMode
    public let workspaceID: WorkspaceID
    public let monitorID: DisplayID
    public let isFocused: Bool
    public let isMinimized: Bool

    public init(
        windowID: WindowID,
        appName: String,
        appBundleID: String,
        title: String,
        frame: Rect,
        mode: WindowMode,
        workspaceID: WorkspaceID,
        monitorID: DisplayID,
        isFocused: Bool,
        isMinimized: Bool
    ) {
        self.windowID = windowID
        self.appName = appName
        self.appBundleID = appBundleID
        self.title = title
        self.frame = frame
        self.mode = mode
        self.workspaceID = workspaceID
        self.monitorID = monitorID
        self.isFocused = isFocused
        self.isMinimized = isMinimized
    }
}

/// Snapshot of workspace information for IPC/serialization.
public struct WorkspaceInfo: Codable, Sendable {
    public let id: WorkspaceID
    public let monitorID: DisplayID
    public let isActive: Bool
    public let windowCount: Int
    public let focusedWindowID: WindowID?
    public let layoutMode: LayoutMode

    public init(
        id: WorkspaceID,
        monitorID: DisplayID,
        isActive: Bool,
        windowCount: Int,
        focusedWindowID: WindowID?,
        layoutMode: LayoutMode
    ) {
        self.id = id
        self.monitorID = monitorID
        self.isActive = isActive
        self.windowCount = windowCount
        self.focusedWindowID = focusedWindowID
        self.layoutMode = layoutMode
    }
}

/// Snapshot of monitor information for IPC/serialization.
public struct MonitorInfo: Codable, Sendable {
    public let displayID: DisplayID
    public let frame: Rect
    public let visibleFrame: Rect
    public let activeWorkspaceID: WorkspaceID
    public let workspaceIDs: [WorkspaceID]

    public init(
        displayID: DisplayID,
        frame: Rect,
        visibleFrame: Rect,
        activeWorkspaceID: WorkspaceID,
        workspaceIDs: [WorkspaceID]
    ) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.activeWorkspaceID = activeWorkspaceID
        self.workspaceIDs = workspaceIDs
    }
}
