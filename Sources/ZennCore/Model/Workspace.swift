import Foundation
import ZennShared

/// A virtual workspace containing a tiling tree.
public class Workspace {
    /// Unique identifier for this workspace.
    public let id: WorkspaceID

    /// The monitor this workspace is assigned to.
    public var monitorID: DisplayID

    /// The root of the tiling tree (nil if empty).
    public var tileRoot: ContainerNode?

    /// The currently focused window ID within this workspace.
    public var focusedWindowID: WindowID?

    /// Layout mode (tiling vs monocle).
    public var layoutMode: LayoutMode = .tiling

    /// Per-workspace gap overrides (nil = use monitor/global gaps).
    public var gapOverride: GapConfig?

    /// Whether this workspace is currently visible on its monitor.
    public var isActive: Bool = false

    /// The workspace we were on before switching to this one (for back-and-forth).
    public var previousWorkspaceID: WorkspaceID?

    /// The default split axis for new windows.
    public var defaultSplitAxis: SplitAxis = .horizontal

    public init(
        id: WorkspaceID,
        monitorID: DisplayID,
        tileRoot: ContainerNode? = nil
    ) {
        self.id = id
        self.monitorID = monitorID
        self.tileRoot = tileRoot
    }

    /// Number of tiled windows in this workspace.
    public var windowCount: Int {
        tileRoot?.children.first.map { _ in tileRoot!.allWindowIDs.count } ?? 0
    }

    /// Whether this workspace has any windows.
    public var isEmpty: Bool {
        tileRoot == nil || (tileRoot?.children.isEmpty ?? true)
    }

    /// Insert a window into the tiling tree.
    public func insertWindow(_ window: WindowNode, axis: SplitAxis? = nil) {
        let splitAxis = axis ?? defaultSplitAxis
        tileRoot = TreeOperations.insertWindow(
            root: tileRoot,
            window: window,
            nearWindowID: focusedWindowID,
            axis: splitAxis
        )
    }

    /// Remove a window from the tiling tree.
    @discardableResult
    public func removeWindow(_ windowID: WindowID) -> WindowNode? {
        guard let root = tileRoot else { return nil }
        let (newRoot, removed) = TreeOperations.removeWindow(root: root, windowID: windowID)
        tileRoot = newRoot
        if focusedWindowID == windowID {
            focusedWindowID = tileRoot?.allWindowIDs.first
        }
        return removed
    }

    /// Convert to a serializable WorkspaceInfo snapshot.
    public func toInfo() -> WorkspaceInfo {
        WorkspaceInfo(
            id: id,
            monitorID: monitorID,
            isActive: isActive,
            windowCount: tileRoot?.windowCount ?? 0,
            focusedWindowID: focusedWindowID,
            layoutMode: layoutMode
        )
    }
}
