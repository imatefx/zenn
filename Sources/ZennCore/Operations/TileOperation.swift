import Foundation
import ZennShared

/// High-level tiling operations that coordinate tree mutations with layout recalculation.
public class TileOperation {
    private let state: WorldState
    private let layoutEngine: LayoutEngine
    private let hookDispatcher: HookDispatcher

    public init(state: WorldState, layoutEngine: LayoutEngine, hookDispatcher: HookDispatcher) {
        self.state = state
        self.layoutEngine = layoutEngine
        self.hookDispatcher = hookDispatcher
    }

    /// Add a new window to the tiling tree.
    /// Returns the calculated frames for all windows on the workspace.
    public func tileWindow(
        windowID: WindowID,
        appName: String,
        appBundleID: String,
        pid: pid_t,
        title: String,
        frame: Rect,
        on workspaceID: WorkspaceID,
        monitorID: DisplayID
    ) -> [WindowID: Rect]? {
        // Check if window should be floating based on rules
        let rule = state.matchingRule(appName: appName, title: title, bundleID: appBundleID)
        let mode = rule?.mode ?? .tiled

        // Register window state
        let windowState = WindowState(
            windowID: windowID,
            appName: appName,
            appBundleID: appBundleID,
            pid: pid,
            windowTitle: title,
            frame: frame,
            mode: mode,
            workspaceID: rule?.workspace ?? workspaceID,
            monitorID: monitorID
        )
        state.windowRegistry.register(windowState)

        // If floating or sticky, don't add to tile tree
        if mode == .floating || mode == .sticky {
            hookDispatcher.windowCreated(windowID: windowID, appName: appName, title: title)
            return nil
        }

        // Add to workspace tiling tree
        guard let workspace = state.workspace(for: windowState.workspaceID) else { return nil }

        let windowNode = WindowNode(
            windowID: windowID,
            appBundleID: appBundleID,
            appName: appName,
            windowTitle: title
        )
        workspace.insertWindow(windowNode, axis: workspace.defaultSplitAxis)

        // Set focus to new window
        state.setFocus(to: windowID)

        // Recalculate layout
        let frames = layoutEngine.applyLayout(for: workspace)

        hookDispatcher.windowCreated(windowID: windowID, appName: appName, title: title)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Remove a window from the tiling tree.
    public func untileWindow(windowID: WindowID) -> [WindowID: Rect]? {
        guard let windowState = state.windowRegistry.window(for: windowID) else { return nil }
        guard let workspace = state.workspace(for: windowState.workspaceID) else { return nil }

        let appName = windowState.appName

        // Remove from tile tree
        workspace.removeWindow(windowID)

        // Unregister from window registry
        state.windowRegistry.unregister(windowID)

        // Recalculate layout
        let frames = layoutEngine.applyLayout(for: workspace)

        hookDispatcher.windowDestroyed(windowID: windowID, appName: appName)
        hookDispatcher.tilingLayoutChanged(workspaceID: workspace.id)

        return frames
    }

    /// Move a window to a different workspace.
    public func moveWindowToWorkspace(
        windowID: WindowID,
        targetWorkspaceID: WorkspaceID
    ) -> (sourceFrames: [WindowID: Rect], targetFrames: [WindowID: Rect])? {
        guard let windowState = state.windowRegistry.window(for: windowID) else { return nil }
        guard let sourceWorkspace = state.workspace(for: windowState.workspaceID) else { return nil }
        guard let targetWorkspace = state.workspace(for: targetWorkspaceID) else { return nil }

        // Remove from source workspace tree
        guard let removedNode = sourceWorkspace.removeWindow(windowID) else { return nil }

        // Add to target workspace tree
        targetWorkspace.insertWindow(removedNode)

        // Update window state
        windowState.workspaceID = targetWorkspaceID
        windowState.monitorID = targetWorkspace.monitorID

        // Recalculate both layouts
        let sourceFrames = layoutEngine.applyLayout(for: sourceWorkspace)
        let targetFrames = layoutEngine.applyLayout(for: targetWorkspace)

        hookDispatcher.tilingLayoutChanged(workspaceID: sourceWorkspace.id)
        hookDispatcher.tilingLayoutChanged(workspaceID: targetWorkspace.id)

        return (sourceFrames, targetFrames)
    }
}
