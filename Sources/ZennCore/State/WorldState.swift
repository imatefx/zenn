import Foundation
import ZennShared
import Collections

/// The single source of truth for the entire tiling window manager state.
public class WorldState {
    /// All monitors, keyed by DisplayID.
    public var monitors: OrderedDictionary<DisplayID, Monitor> = [:]

    /// Central registry of all tracked windows.
    public let windowRegistry: WindowRegistry = WindowRegistry()

    /// The currently focused window ID.
    public var focusedWindowID: WindowID?

    /// Global gap configuration (can be overridden per-monitor and per-workspace).
    public var globalGaps: GapConfig = .zero

    /// Window rules.
    public var windowRules: [WindowRule] = []

    /// The default number of workspaces per monitor.
    public var defaultWorkspaceCount: Int = 9

    /// Maximum tree depth.
    public var maxTreeDepth: Int = 5

    /// Whether animations are enabled.
    public var animationsEnabled: Bool = false

    /// Animation duration in seconds.
    public var animationDuration: Double = 0.2

    /// Focus border configuration.
    public var focusBorderEnabled: Bool = false
    public var focusBorderColor: (r: Double, g: Double, b: Double, a: Double) = (0.2, 0.6, 1.0, 1.0)
    public var focusBorderWidth: Double = 2.0

    public init() {}

    // MARK: - Monitor Management

    /// Get the primary (main) monitor.
    public var primaryMonitor: Monitor? {
        monitors.values.first
    }

    /// Register a new monitor.
    public func addMonitor(_ monitor: Monitor) {
        monitors[monitor.displayID] = monitor
        monitor.ensureWorkspaces(count: defaultWorkspaceCount)
        // Activate workspace 1 by default
        monitor.switchToWorkspace(number: 1)
    }

    /// Remove a monitor and redistribute its windows.
    public func removeMonitor(_ displayID: DisplayID) -> Monitor? {
        monitors.removeValue(forKey: displayID)
    }

    /// Get the monitor for a display ID.
    public func monitor(for displayID: DisplayID) -> Monitor? {
        monitors[displayID]
    }

    // MARK: - Workspace Management

    /// Get a workspace by its ID across all monitors.
    public func workspace(for id: WorkspaceID) -> Workspace? {
        for monitor in monitors.values {
            if let ws = monitor.workspaces[id.number] {
                return ws
            }
        }
        return nil
    }

    /// Get the active workspace on a given monitor.
    public func activeWorkspace(on displayID: DisplayID) -> Workspace? {
        monitors[displayID]?.activeWorkspace
    }

    /// Get the workspace containing the focused window.
    public var focusedWorkspace: Workspace? {
        guard let windowID = focusedWindowID,
              let windowState = windowRegistry.window(for: windowID) else {
            return primaryMonitor?.activeWorkspace
        }
        return workspace(for: windowState.workspaceID)
    }

    /// Get the monitor containing the focused window.
    public var focusedMonitor: Monitor? {
        guard let windowID = focusedWindowID,
              let windowState = windowRegistry.window(for: windowID) else {
            return primaryMonitor
        }
        return monitors[windowState.monitorID]
    }

    // MARK: - Window Management

    /// Get the effective gap config for a workspace (workspace override > monitor > global).
    public func effectiveGaps(for workspace: Workspace) -> GapConfig {
        if let override = workspace.gapOverride {
            return override
        }
        if let monitor = monitors[workspace.monitorID] {
            if monitor.gaps != .zero {
                return monitor.gaps
            }
        }
        return globalGaps
    }

    /// Find the first matching window rule for a window.
    public func matchingRule(appName: String, title: String, bundleID: String) -> WindowRule? {
        windowRules.first { $0.matches(appName: appName, title: title, bundleID: bundleID) }
    }

    // MARK: - Focus

    /// The currently focused window state.
    public var focusedWindow: WindowState? {
        guard let id = focusedWindowID else { return nil }
        return windowRegistry.window(for: id)
    }

    /// Set focus to a window.
    public func setFocus(to windowID: WindowID) {
        focusedWindowID = windowID
        if let windowState = windowRegistry.window(for: windowID),
           let workspace = workspace(for: windowState.workspaceID) {
            workspace.focusedWindowID = windowID
        }
    }
}
