import Foundation
import ZennShared
import Collections

/// Central registry of all tracked windows.
public class WindowRegistry {
    /// All tracked windows indexed by WindowID.
    private var windows: OrderedDictionary<WindowID, WindowState> = [:]

    public init() {}

    /// Number of tracked windows.
    public var count: Int { windows.count }

    /// All window IDs.
    public var allWindowIDs: [WindowID] { Array(windows.keys) }

    /// All window states.
    public var allWindows: [WindowState] { Array(windows.values) }

    /// Register a new window.
    public func register(_ state: WindowState) {
        windows[state.windowID] = state
    }

    /// Unregister a window.
    @discardableResult
    public func unregister(_ windowID: WindowID) -> WindowState? {
        windows.removeValue(forKey: windowID)
    }

    /// Look up a window by ID.
    public func window(for id: WindowID) -> WindowState? {
        windows[id]
    }

    /// Check if a window is tracked.
    public func contains(_ windowID: WindowID) -> Bool {
        windows[windowID] != nil
    }

    /// Get all windows on a given workspace.
    public func windows(on workspaceID: WorkspaceID) -> [WindowState] {
        windows.values.filter { $0.workspaceID == workspaceID }
    }

    /// Get all windows for a given app.
    public func windows(forApp bundleID: String) -> [WindowState] {
        windows.values.filter { $0.appBundleID == bundleID }
    }

    /// Get all tiled windows on a workspace.
    public func tiledWindows(on workspaceID: WorkspaceID) -> [WindowState] {
        windows.values.filter { $0.workspaceID == workspaceID && $0.mode == .tiled }
    }

    /// Get all floating windows on a workspace.
    public func floatingWindows(on workspaceID: WorkspaceID) -> [WindowState] {
        windows.values.filter { $0.workspaceID == workspaceID && $0.mode == .floating }
    }

    /// Get all sticky windows.
    public func stickyWindows() -> [WindowState] {
        windows.values.filter { $0.mode == .sticky }
    }

    /// Get all windows for a given PID.
    public func windows(forPID pid: pid_t) -> [WindowState] {
        windows.values.filter { $0.pid == pid }
    }
}
