import Foundation
import ZennShared

/// Codable snapshot of workspace settings for persistence.
/// Does NOT include tree structure or window IDs — those are rebuilt
/// from discovered windows on each launch.
public struct StateSnapshot: Codable {
    public var monitors: [MonitorSnapshot]
    public var globalGaps: GapConfig

    public init(monitors: [MonitorSnapshot] = [], globalGaps: GapConfig = .zero) {
        self.monitors = monitors
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
    public var gapOverride: GapConfig?

    public init(
        number: Int,
        name: String? = nil,
        layoutMode: LayoutMode = .tiling,
        defaultSplitAxis: SplitAxis = .horizontal,
        gapOverride: GapConfig? = nil
    ) {
        self.number = number
        self.name = name
        self.layoutMode = layoutMode
        self.defaultSplitAxis = defaultSplitAxis
        self.gapOverride = gapOverride
    }
}
