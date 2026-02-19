import Foundation
import ZennShared

/// Manages window focus state and directional/cycle focus navigation.
public class FocusManager {
    private let state: WorldState
    private let layoutEngine: LayoutEngine

    public init(state: WorldState, layoutEngine: LayoutEngine) {
        self.state = state
        self.layoutEngine = layoutEngine
    }

    /// Move focus in a cardinal direction.
    /// Returns the window ID that should receive focus, or nil if no valid target.
    public func focusInDirection(_ direction: Direction) -> WindowID? {
        guard let currentWorkspace = state.focusedWorkspace,
              let root = currentWorkspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        // Calculate current frames for geometric neighbor finding
        let frames = layoutEngine.calculateLayout(for: currentWorkspace)

        // Find the neighbor in the given direction
        guard let neighbor = TreeTraversal.findNeighbor(
            in: root,
            from: focusedID,
            direction: direction,
            frames: frames
        ) else {
            return nil
        }

        state.setFocus(to: neighbor.windowID)
        return neighbor.windowID
    }

    /// Cycle focus to the next or previous window.
    /// Returns the window ID that should receive focus.
    public func focusCycle(_ direction: CycleDirection) -> WindowID? {
        guard let currentWorkspace = state.focusedWorkspace,
              let root = currentWorkspace.tileRoot,
              let focusedID = state.focusedWindowID else {
            return nil
        }

        let target: WindowNode?
        switch direction {
        case .next:
            target = TreeTraversal.nextWindow(in: root, after: focusedID)
        case .previous:
            target = TreeTraversal.previousWindow(in: root, before: focusedID)
        }

        guard let targetWindow = target else { return nil }

        state.setFocus(to: targetWindow.windowID)
        return targetWindow.windowID
    }

    /// Set focus to a specific window.
    public func focusWindow(_ windowID: WindowID) {
        state.setFocus(to: windowID)
    }

    /// Get the currently focused window ID.
    public var focusedWindowID: WindowID? {
        state.focusedWindowID
    }

    /// Handle a window being destroyed — move focus to a sibling.
    public func handleWindowDestroyed(_ windowID: WindowID) -> WindowID? {
        guard state.focusedWindowID == windowID else { return nil }

        // Try to find a nearby window to focus
        guard let workspace = state.focusedWorkspace,
              let root = workspace.tileRoot else {
            state.focusedWindowID = nil
            return nil
        }

        // Focus the next window, or the previous, or nil
        let windows = TreeTraversal.allWindows(in: root)
        if let next = windows.first {
            state.setFocus(to: next.windowID)
            return next.windowID
        }

        state.focusedWindowID = nil
        return nil
    }
}
