import Foundation
import ZennShared

/// Handles resizing operations on the tiling tree.
public class ResizeOperation {
    private let state: WorldState
    private let layoutEngine: LayoutEngine
    private let hookDispatcher: HookDispatcher

    /// The default resize delta (percentage).
    public var resizeDelta: CGFloat = 0.05

    public init(state: WorldState, layoutEngine: LayoutEngine, hookDispatcher: HookDispatcher) {
        self.state = state
        self.layoutEngine = layoutEngine
        self.hookDispatcher = hookDispatcher
    }

    /// Resize the focused window in a direction (grow in that direction).
    public func resizeInDirection(_ direction: Direction, delta: CGFloat? = nil) -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        let actualDelta = delta ?? resizeDelta

        guard TreeOperations.resizeWindow(
            root: root,
            windowID: focusedID,
            direction: direction,
            delta: actualDelta
        ) else {
            return nil
        }

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Apply a resize preset to the focused workspace's root.
    public func applyPreset(_ preset: ResizePreset) -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot else {
            return nil
        }

        TreeOperations.applyPreset(root: root, preset: preset)

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Equalize all split ratios in the focused workspace.
    public func equalize() -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot else {
            return nil
        }

        equalizeRecursive(root)

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    private func equalizeRecursive(_ container: ContainerNode) {
        container.equalizeRatios()
        for child in container.children {
            if case .container(let childContainer) = child {
                equalizeRecursive(childContainer)
            }
        }
    }
}
