import Foundation
import ZennShared
import ZennCore

/// Routes IPC commands to the appropriate operations and returns responses.
public class CommandRouter {
    private let state: WorldState
    private let focusManager: FocusManager
    private let tileOperation: TileOperation
    private let swapOperation: SwapOperation
    private let resizeOperation: ResizeOperation
    private let moveOperation: MoveOperation
    private let fullscreenOperation: FullscreenOperation
    private let hookRegistry: HookRegistry
    private let hookDispatcher: HookDispatcher

    /// Callback for applying frames to windows.
    public var onApplyFrames: (([WindowID: Rect]) -> Void)?

    /// Callback for workspace switch.
    public var onWorkspaceSwitch: ((Int) -> Void)?

    /// Callback for focus change.
    public var onFocusChange: ((WindowID) -> Void)?

    /// Callback for config reload.
    public var onReload: (() -> Void)?

    /// Callback for app quit.
    public var onQuit: (() -> Void)?

    public init(
        state: WorldState,
        focusManager: FocusManager,
        tileOperation: TileOperation,
        swapOperation: SwapOperation,
        resizeOperation: ResizeOperation,
        moveOperation: MoveOperation,
        fullscreenOperation: FullscreenOperation,
        hookRegistry: HookRegistry,
        hookDispatcher: HookDispatcher
    ) {
        self.state = state
        self.focusManager = focusManager
        self.tileOperation = tileOperation
        self.swapOperation = swapOperation
        self.resizeOperation = resizeOperation
        self.moveOperation = moveOperation
        self.fullscreenOperation = fullscreenOperation
        self.hookRegistry = hookRegistry
        self.hookDispatcher = hookDispatcher
    }

    /// Handle a command and return a response.
    public func handle(_ command: Command) -> CommandResponse {
        switch command {
        // Focus
        case .focus(let direction):
            if let windowID = focusManager.focusInDirection(direction) {
                onFocusChange?(windowID)
                return .ok("Focused \(direction)")
            }
            return .error("No window in direction \(direction)")

        case .focusCycle(let direction):
            if let windowID = focusManager.focusCycle(direction) {
                onFocusChange?(windowID)
                return .ok("Focused \(direction)")
            }
            return .error("No window to focus")

        // Window operations
        case .moveWindow(let direction):
            if let frames = moveOperation.moveInDirection(direction) {
                onApplyFrames?(frames)
                return .ok("Moved window \(direction)")
            }
            return .error("Cannot move window \(direction)")

        case .moveToWorkspace(let workspaceID):
            if let result = moveOperation.moveToWorkspace(workspaceID.number) {
                onApplyFrames?(result.source)
                return .ok("Moved to workspace \(workspaceID)")
            }
            return .error("Cannot move to workspace \(workspaceID)")

        case .moveToMonitor:
            return .error("Move to monitor not yet implemented")

        case .swapWindow(let direction):
            if let frames = swapOperation.swapInDirection(direction) {
                onApplyFrames?(frames)
                return .ok("Swapped window \(direction)")
            }
            return .error("Cannot swap window \(direction)")

        case .resizeWindow(let direction, let delta):
            if let frames = resizeOperation.resizeInDirection(direction, delta: CGFloat(delta)) {
                onApplyFrames?(frames)
                return .ok("Resized window \(direction)")
            }
            return .error("Cannot resize window \(direction)")

        case .setWindowMode(let mode):
            if let frames = fullscreenOperation.setWindowMode(mode) {
                onApplyFrames?(frames)
                return .ok("Set window mode to \(mode)")
            }
            return .error("Cannot set window mode")

        case .closeWindow:
            return .error("Close window not yet implemented")

        // Workspace
        case .switchWorkspace(let workspaceID):
            onWorkspaceSwitch?(workspaceID.number)
            return .ok("Switched to workspace \(workspaceID)")

        case .renameWorkspace:
            return .error("Rename workspace not yet implemented")

        // Layout
        case .setSplitAxis(let axis):
            if let workspace = state.focusedWorkspace {
                workspace.defaultSplitAxis = axis
                return .ok("Split axis set to \(axis)")
            }
            return .error("No focused workspace")

        case .toggleSplitAxis:
            if let workspace = state.focusedWorkspace {
                workspace.defaultSplitAxis = workspace.defaultSplitAxis.perpendicular
                return .ok("Toggled split axis")
            }
            return .error("No focused workspace")

        case .setLayoutMode(let mode):
            if let workspace = state.focusedWorkspace {
                workspace.layoutMode = mode
                return .ok("Layout mode set to \(mode)")
            }
            return .error("No focused workspace")

        case .applyPreset(let preset):
            if let frames = resizeOperation.applyPreset(preset) {
                onApplyFrames?(frames)
                return .ok("Applied preset \(preset)")
            }
            return .error("Cannot apply preset")

        // Queries
        case .queryWindows:
            let windows = state.windowRegistry.allWindows.map {
                $0.toInfo(isFocused: $0.windowID == state.focusedWindowID)
            }
            return CommandResponse(success: true, data: .windows(windows))

        case .queryWorkspaces:
            var workspaces: [WorkspaceInfo] = []
            for (_, monitor) in state.monitors {
                for (_, workspace) in monitor.workspaces {
                    workspaces.append(workspace.toInfo())
                }
            }
            return CommandResponse(success: true, data: .workspaces(workspaces))

        case .queryMonitors:
            let monitors = state.monitors.values.map { $0.toInfo() }
            return CommandResponse(success: true, data: .monitors(monitors))

        case .queryFocused:
            let focused = state.focusedWindow?.toInfo(isFocused: true)
            return CommandResponse(success: true, data: .focused(focused))

        case .queryTree(let workspaceID):
            let workspace: Workspace?
            if let wsID = workspaceID {
                workspace = state.workspace(for: wsID)
            } else {
                workspace = state.focusedWorkspace
            }
            if let root = workspace?.tileRoot {
                let snapshot = TreeTraversal.snapshot(of: root)
                return CommandResponse(success: true, data: .tree(snapshot))
            }
            return .error("No tree available")

        // System
        case .reload:
            onReload?()
            return .ok("Config reloaded")

        case .restart:
            onReload?()
            return .ok("Restarting")

        case .quit:
            onQuit?()
            return .ok("Quitting")

        // Events
        case .subscribe:
            return .ok("Subscribed") // Handled at the transport level
        }
    }
}
