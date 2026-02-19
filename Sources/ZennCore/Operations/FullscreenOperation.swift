import Foundation
import ZennShared

/// Handles fullscreen/monocle toggle and floating/sticky mode changes.
public class FullscreenOperation {
    private let state: WorldState
    private let layoutEngine: LayoutEngine
    private let hookDispatcher: HookDispatcher

    public init(state: WorldState, layoutEngine: LayoutEngine, hookDispatcher: HookDispatcher) {
        self.state = state
        self.layoutEngine = layoutEngine
        self.hookDispatcher = hookDispatcher
    }

    /// Toggle the focused window's mode.
    public func setWindowMode(_ mode: WindowMode) -> [WindowID: Rect]? {
        guard let focusedID = state.focusedWindowID,
              let windowState = state.windowRegistry.window(for: focusedID),
              let workspace = state.workspace(for: windowState.workspaceID) else {
            return nil
        }

        let previousMode = windowState.mode

        // If changing to/from tiled, update the tree
        if previousMode == .tiled && mode != .tiled {
            // Save frame and remove from tree
            windowState.savedFrame = windowState.frame
            workspace.removeWindow(focusedID)
        } else if previousMode != .tiled && mode == .tiled {
            // Re-add to tree
            let windowNode = WindowNode(
                windowID: focusedID,
                appBundleID: windowState.appBundleID,
                appName: windowState.appName,
                windowTitle: windowState.windowTitle
            )
            workspace.insertWindow(windowNode)
        }

        windowState.mode = mode

        let frames = layoutEngine.applyLayout(for: workspace)

        hookDispatcher.windowModeChanged(windowID: focusedID, appName: windowState.appName)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Toggle between tiled and floating.
    public func toggleFloating() -> [WindowID: Rect]? {
        guard let focusedID = state.focusedWindowID,
              let windowState = state.windowRegistry.window(for: focusedID) else {
            return nil
        }

        let newMode: WindowMode = windowState.mode == .floating ? .tiled : .floating
        return setWindowMode(newMode)
    }

    /// Toggle between tiled and sticky.
    public func toggleSticky() -> [WindowID: Rect]? {
        guard let focusedID = state.focusedWindowID,
              let windowState = state.windowRegistry.window(for: focusedID) else {
            return nil
        }

        let newMode: WindowMode = windowState.mode == .sticky ? .tiled : .sticky
        return setWindowMode(newMode)
    }

    /// Toggle fullscreen for the focused window.
    public func toggleFullscreen() -> [WindowID: Rect]? {
        guard let focusedID = state.focusedWindowID,
              let windowState = state.windowRegistry.window(for: focusedID) else {
            return nil
        }

        let newMode: WindowMode = windowState.mode == .fullscreen ? .tiled : .fullscreen
        return setWindowMode(newMode)
    }

    /// Toggle the workspace layout mode between tiling and monocle.
    public func toggleMonocle() -> [WindowID: Rect]? {
        guard let workspace = state.focusedWorkspace else { return nil }

        workspace.layoutMode = workspace.layoutMode == .tiling ? .monocle : .tiling

        let frames = layoutEngine.applyLayout(for: workspace)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }
}
