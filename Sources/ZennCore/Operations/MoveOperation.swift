import Foundation
import ZennShared

/// Handles moving windows between positions, workspaces, and monitors.
public class MoveOperation {
    private let state: WorldState
    private let layoutEngine: LayoutEngine
    private let hookDispatcher: HookDispatcher

    public init(state: WorldState, layoutEngine: LayoutEngine, hookDispatcher: HookDispatcher) {
        self.state = state
        self.layoutEngine = layoutEngine
        self.hookDispatcher = hookDispatcher
    }

    /// Move the focused window in a direction (swap with neighbor).
    public func moveInDirection(_ direction: Direction) -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        let currentFrames = layoutEngine.calculateLayout(for: workspace)

        guard let neighbor = TreeTraversal.findNeighbor(
            in: root, from: focusedID, direction: direction, frames: currentFrames
        ) else {
            return nil
        }

        guard TreeOperations.swapWindows(root: root, windowA: focusedID, windowB: neighbor.windowID) else {
            return nil
        }

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Merge the focused window with its neighbor in the given direction into a sub-split.
    /// Instead of swapping, this restructures the tree by creating a new sub-container.
    public func mergeInDirection(_ direction: Direction) -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        let currentFrames = layoutEngine.calculateLayout(for: workspace)

        guard let neighbor = TreeTraversal.findNeighbor(
            in: root, from: focusedID, direction: direction, frames: currentFrames
        ) else {
            print("[Zenn] Merge: no neighbor found in direction \(direction)")
            return nil
        }

        guard TreeOperations.mergeWindows(
            root: root, sourceWindowID: focusedID, targetWindowID: neighbor.windowID
        ) else {
            print("[Zenn] Merge: tree operation failed")
            return nil
        }

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Eject the focused window from its sub-split up to the parent level.
    /// This is the inverse of merge.
    public func eject() -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        guard TreeOperations.ejectWindow(root: root, windowID: focusedID) else {
            print("[Zenn] Eject: window is already at root level or operation failed")
            return nil
        }

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Move the focused window to a specific workspace.
    public func moveToWorkspace(_ targetNumber: Int) -> (source: [WindowID: Rect], target: [WindowID: Rect])? {
        guard let focusedID = state.focusedWindowID,
              let windowState = state.windowRegistry.window(for: focusedID),
              let sourceWorkspace = state.workspace(for: windowState.workspaceID),
              let monitor = state.focusedMonitor else {
            return nil
        }

        let targetWorkspace = monitor.workspace(number: targetNumber)

        guard let removedNode = sourceWorkspace.removeWindow(focusedID) else { return nil }

        targetWorkspace.insertWindow(removedNode)

        windowState.workspaceID = targetWorkspace.id

        let sourceFrames = layoutEngine.applyLayout(for: sourceWorkspace)
        let targetFrames = layoutEngine.applyLayout(for: targetWorkspace)

        // Move focus to next window on source workspace
        if let nextWindow = sourceWorkspace.tileRoot?.allWindowIDs.first {
            state.setFocus(to: nextWindow)
        } else {
            state.focusedWindowID = nil
        }

        hookDispatcher.tilingLayoutChanged(workspaceID: sourceWorkspace.id)
        hookDispatcher.tilingLayoutChanged(workspaceID: targetWorkspace.id)

        return (source: sourceFrames, target: targetFrames)
    }
}
