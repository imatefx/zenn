import Foundation
import ZennShared

/// Calculates the frame (position + size) for each window based on the tiling tree.
public enum FrameCalculator {
    /// Calculate frames for all windows in the tree.
    /// - Parameters:
    ///   - root: The root container of the tiling tree.
    ///   - availableFrame: The total area available for tiling (after outer gaps).
    ///   - gaps: Gap configuration for inner gaps between windows.
    /// - Returns: A dictionary mapping WindowID to its calculated frame.
    public static func calculateFrames(
        root: ContainerNode,
        availableFrame: Rect,
        gaps: GapConfig
    ) -> [WindowID: Rect] {
        var frames: [WindowID: Rect] = [:]
        calculateNodeFrames(
            node: .container(root),
            frame: availableFrame,
            gaps: gaps,
            result: &frames
        )
        return frames
    }

    private static func calculateNodeFrames(
        node: TreeNode,
        frame: Rect,
        gaps: GapConfig,
        result: inout [WindowID: Rect]
    ) {
        switch node {
        case .window(let windowNode):
            // Apply inner gaps to the window frame
            let gappedFrame = GapCalculator.applyInnerGaps(to: frame, gaps: gaps)
            result[windowNode.windowID] = gappedFrame

        case .container(let container):
            guard !container.children.isEmpty else { return }

            if container.children.count == 1 {
                // Single child gets the full frame
                calculateNodeFrames(
                    node: container.children[0],
                    frame: frame,
                    gaps: gaps,
                    result: &result
                )
                return
            }

            // Split the frame among children according to ratios
            let ratios = normalizedRatios(container.ratios, count: container.children.count)

            var offset: Double = 0
            for (index, child) in container.children.enumerated() {
                let ratio = ratios[index]
                let childFrame: Rect

                switch container.axis {
                case .horizontal:
                    let childWidth = frame.width * ratio
                    childFrame = Rect(
                        x: frame.x + offset,
                        y: frame.y,
                        width: childWidth,
                        height: frame.height
                    )
                    offset += childWidth

                case .vertical:
                    let childHeight = frame.height * ratio
                    childFrame = Rect(
                        x: frame.x,
                        y: frame.y + offset,
                        width: frame.width,
                        height: childHeight
                    )
                    offset += childHeight
                }

                calculateNodeFrames(
                    node: child,
                    frame: childFrame,
                    gaps: gaps,
                    result: &result
                )
            }
        }
    }

    /// Ensure ratios are normalized (sum to 1.0) and match the expected count.
    private static func normalizedRatios(_ ratios: [CGFloat], count: Int) -> [Double] {
        if ratios.count == count {
            let total = ratios.reduce(0, +)
            if total > 0 {
                return ratios.map { Double($0 / total) }
            }
        }
        // Fallback: equal distribution
        let ratio = 1.0 / Double(count)
        return Array(repeating: ratio, count: count)
    }
}
