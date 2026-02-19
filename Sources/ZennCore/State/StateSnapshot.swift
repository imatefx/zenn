import Foundation
import ZennShared

/// Codable snapshot of the entire world state for persistence.
public struct StateSnapshot: Codable {
    public var monitors: [MonitorSnapshot]
    public var focusedWindowID: UInt32?
    public var globalGaps: GapConfig

    public init(monitors: [MonitorSnapshot] = [], focusedWindowID: UInt32? = nil, globalGaps: GapConfig = .zero) {
        self.monitors = monitors
        self.focusedWindowID = focusedWindowID
        self.globalGaps = globalGaps
    }
}

public struct MonitorSnapshot: Codable {
    public var displayID: UInt32
    public var activeWorkspaceNumber: Int
    public var workspaces: [WorkspaceSnapshot]
    public var gaps: GapConfig

    public init(displayID: UInt32, activeWorkspaceNumber: Int = 1, workspaces: [WorkspaceSnapshot] = [], gaps: GapConfig = .zero) {
        self.displayID = displayID
        self.activeWorkspaceNumber = activeWorkspaceNumber
        self.workspaces = workspaces
        self.gaps = gaps
    }
}

public struct WorkspaceSnapshot: Codable {
    public var number: Int
    public var name: String?
    public var layoutMode: LayoutMode
    public var defaultSplitAxis: SplitAxis
    public var windowIDs: [UInt32]
    public var treeSnapshot: TreeNodeSnapshot?
    public var focusedWindowID: UInt32?
    public var gapOverride: GapConfig?

    public init(
        number: Int,
        name: String? = nil,
        layoutMode: LayoutMode = .tiling,
        defaultSplitAxis: SplitAxis = .horizontal,
        windowIDs: [UInt32] = [],
        treeSnapshot: TreeNodeSnapshot? = nil,
        focusedWindowID: UInt32? = nil,
        gapOverride: GapConfig? = nil
    ) {
        self.number = number
        self.name = name
        self.layoutMode = layoutMode
        self.defaultSplitAxis = defaultSplitAxis
        self.windowIDs = windowIDs
        self.treeSnapshot = treeSnapshot
        self.focusedWindowID = focusedWindowID
        self.gapOverride = gapOverride
    }
}

public indirect enum TreeNodeSnapshot: Codable {
    case container(axis: SplitAxis, ratios: [Double], children: [TreeNodeSnapshot])
    case window(windowID: UInt32, appBundleID: String, appName: String)
}
