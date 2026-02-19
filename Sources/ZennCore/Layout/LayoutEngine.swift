import Foundation
import ZennShared

/// Orchestrates layout calculation for a workspace.
public class LayoutEngine {
    private let state: WorldState

    public init(state: WorldState) {
        self.state = state
    }

    /// Calculate frames for all tiled windows on a workspace.
    public func calculateLayout(for workspace: Workspace) -> [WindowID: Rect] {
        guard let root = workspace.tileRoot,
              !root.children.isEmpty else {
            return [:]
        }

        // Get the monitor for this workspace
        guard let monitor = state.monitor(for: workspace.monitorID) else {
            return [:]
        }

        let gaps = state.effectiveGaps(for: workspace)

        switch workspace.layoutMode {
        case .tiling:
            return calculateTilingLayout(root: root, monitor: monitor, gaps: gaps)
        case .monocle:
            return calculateMonocleLayout(root: root, monitor: monitor, gaps: gaps)
        }
    }

    /// Standard tiling layout with splits.
    private func calculateTilingLayout(
        root: ContainerNode,
        monitor: Monitor,
        gaps: GapConfig
    ) -> [WindowID: Rect] {
        let tilingArea = GapCalculator.tilingArea(
            screenFrame: monitor.visibleFrame,
            gaps: gaps
        )
        return FrameCalculator.calculateFrames(
            root: root,
            availableFrame: tilingArea,
            gaps: gaps
        )
    }

    /// Monocle layout: every window gets the full screen.
    private func calculateMonocleLayout(
        root: ContainerNode,
        monitor: Monitor,
        gaps: GapConfig
    ) -> [WindowID: Rect] {
        let tilingArea = GapCalculator.tilingArea(
            screenFrame: monitor.visibleFrame,
            gaps: gaps
        )
        var frames: [WindowID: Rect] = [:]
        for windowID in root.allWindowIDs {
            frames[windowID] = tilingArea
        }
        return frames
    }

    /// Recalculate and apply layout for a workspace.
    /// Returns the calculated frames for use by the window manager.
    public func applyLayout(for workspace: Workspace) -> [WindowID: Rect] {
        let frames = calculateLayout(for: workspace)

        // Update window states with calculated frames
        for (windowID, frame) in frames {
            if let windowState = state.windowRegistry.window(for: windowID) {
                windowState.frame = frame
            }
        }

        return frames
    }
}
