import Foundation
import ZennShared
import Collections

/// Represents a physical display/monitor with its own set of workspaces.
public class Monitor {
    /// The display ID from CoreGraphics.
    public let displayID: DisplayID

    /// Full frame of the display.
    public var frame: Rect

    /// Visible frame (excluding menu bar, dock).
    public var visibleFrame: Rect

    /// Workspaces assigned to this monitor, keyed by workspace number.
    public var workspaces: OrderedDictionary<Int, Workspace> = [:]

    /// The currently active workspace number.
    public var activeWorkspaceNumber: Int = 1

    /// Per-monitor gap configuration.
    public var gaps: GapConfig = .zero

    public init(
        displayID: DisplayID,
        frame: Rect = .zero,
        visibleFrame: Rect = .zero
    ) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    /// Get the currently active workspace.
    public var activeWorkspace: Workspace? {
        workspaces[activeWorkspaceNumber]
    }

    /// Get or create a workspace by number.
    public func workspace(number: Int, name: String? = nil) -> Workspace {
        if let existing = workspaces[number] {
            return existing
        }
        let ws = Workspace(
            id: WorkspaceID(number: number, name: name),
            monitorID: displayID
        )
        workspaces[number] = ws
        return ws
    }

    /// Ensure at least the given number of workspaces exist (1-based).
    public func ensureWorkspaces(count: Int) {
        for i in 1...count {
            _ = workspace(number: i)
        }
    }

    /// Switch to a workspace by number. Returns the previous workspace number for back-and-forth.
    @discardableResult
    public func switchToWorkspace(number: Int) -> Int {
        let previous = activeWorkspaceNumber

        // Deactivate current
        workspaces[previous]?.isActive = false

        // Ensure target exists and activate
        let target = workspace(number: number)
        target.isActive = true
        target.previousWorkspaceID = WorkspaceID(number: previous)
        activeWorkspaceNumber = number

        return previous
    }

    /// Convert to a serializable MonitorInfo snapshot.
    public func toInfo() -> MonitorInfo {
        MonitorInfo(
            displayID: displayID,
            frame: frame,
            visibleFrame: visibleFrame,
            activeWorkspaceID: WorkspaceID(number: activeWorkspaceNumber),
            workspaceIDs: workspaces.keys.sorted().map { WorkspaceID(number: $0) }
        )
    }
}
