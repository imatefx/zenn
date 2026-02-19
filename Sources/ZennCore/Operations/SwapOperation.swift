import Foundation
import ZennShared

/// Handles swapping window positions in the tiling tree.
public class SwapOperation {
    private let state: WorldState
    private let layoutEngine: LayoutEngine
    private let hookDispatcher: HookDispatcher

    public init(state: WorldState, layoutEngine: LayoutEngine, hookDispatcher: HookDispatcher) {
        self.state = state
        self.layoutEngine = layoutEngine
        self.hookDispatcher = hookDispatcher
    }

    /// Swap the focused window with its neighbor in the given direction.
    public func swapInDirection(_ direction: Direction) -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        // Calculate current frames
        let currentFrames = layoutEngine.calculateLayout(for: workspace)

        // Find neighbor
        guard let neighbor = TreeTraversal.findNeighbor(
            in: root,
            from: focusedID,
            direction: direction,
            frames: currentFrames
        ) else {
            return nil
        }

        // Swap in tree
        guard TreeOperations.swapWindows(
            root: root,
            windowA: focusedID,
            windowB: neighbor.windowID
        ) else {
            return nil
        }

        // Recalculate layout
        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Swap two specific windows.
    public func swapWindows(_ windowA: WindowID, _ windowB: WindowID) -> [WindowID: Rect]? {
        guard let stateA = state.windowRegistry.window(for: windowA),
              let workspace = state.workspace(for: stateA.workspaceID),
              let root = workspace.tileRoot else {
            return nil
        }

        guard TreeOperations.swapWindows(root: root, windowA: windowA, windowB: windowB) else {
            return nil
        }

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }
}
