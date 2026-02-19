import Foundation
import ZennShared

/// Manages virtual workspace switching by moving windows on/offscreen.
public class VirtualWorkspaceManager {
    /// AXWindow references keyed by WindowID.
    private var axWindows: [WindowID: AXWindow] = [:]

    /// Saved positions for windows that are currently offscreen.
    private var savedPositions: [WindowID: Rect] = [:]

    public init() {}

    /// Register an AXWindow reference for a window ID.
    public func registerAXWindow(_ axWindow: AXWindow) {
        axWindows[axWindow.windowID] = axWindow
    }

    /// Unregister an AXWindow reference.
    public func unregisterAXWindow(_ windowID: WindowID) {
        axWindows.removeValue(forKey: windowID)
        savedPositions.removeValue(forKey: windowID)
    }

    /// Get the AXWindow for a window ID.
    public func axWindow(for windowID: WindowID) -> AXWindow? {
        axWindows[windowID]
    }

    /// Hide windows by moving them offscreen (for workspace switching).
    public func hideWindows(_ windowIDs: [WindowID]) {
        for windowID in windowIDs {
            guard let axWindow = axWindows[windowID] else { continue }
            // Save current frame before hiding (we need to restore size too)
            if let frame = axWindow.frame {
                savedPositions[windowID] = frame
            }
            axWindow.moveOffscreen()
        }
    }

    /// Show windows by restoring them to their calculated positions.
    public func showWindows(_ frames: [WindowID: Rect]) {
        for (windowID, frame) in frames {
            guard let axWindow = axWindows[windowID] else { continue }
            axWindow.setFrame(frame)
            savedPositions.removeValue(forKey: windowID)
        }
    }

    /// Apply calculated frames to windows (for layout updates).
    public func applyFrames(_ frames: [WindowID: Rect]) {
        for (windowID, frame) in frames {
            guard let axWindow = axWindows[windowID] else { continue }
            axWindow.setFrame(frame)
        }
    }

    /// Focus a window (raise + activate its app).
    public func focusWindow(_ windowID: WindowID) {
        guard let axWindow = axWindows[windowID] else { return }
        axWindow.focus()
    }

    /// Get the saved position for a hidden window.
    public func savedPosition(for windowID: WindowID) -> Rect? {
        savedPositions[windowID]
    }
}
