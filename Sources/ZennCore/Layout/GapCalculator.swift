import Foundation
import ZennShared

/// Calculates frame adjustments based on gap configuration.
public enum GapCalculator {
    /// Apply outer gaps to a screen frame.
    public static func applyOuterGaps(to frame: Rect, gaps: GapConfig) -> Rect {
        frame.inset(
            top: gaps.outer.top,
            bottom: gaps.outer.bottom,
            left: gaps.outer.left,
            right: gaps.outer.right
        )
    }

    /// Apply inner gaps (half on each side of a window).
    public static func applyInnerGaps(to frame: Rect, gaps: GapConfig) -> Rect {
        let half = gaps.inner / 2.0
        return frame.inset(top: half, bottom: half, left: half, right: half)
    }

    /// Calculate the usable area for tiling (screen minus outer gaps).
    public static func tilingArea(screenFrame: Rect, gaps: GapConfig) -> Rect {
        applyOuterGaps(to: screenFrame, gaps: gaps)
    }
}
