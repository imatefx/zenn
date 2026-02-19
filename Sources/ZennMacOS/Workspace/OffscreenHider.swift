import Foundation
import ZennShared

/// Handles the mechanics of hiding/showing windows by moving them offscreen.
/// This implements the "virtual workspace" approach used by AeroSpace.
public class OffscreenHider {
    /// The offscreen position to move windows to.
    private let offscreenPoint = CGPoint(x: -99999, y: -99999)

    public init() {}

    /// Check if a window position indicates it's offscreen (hidden).
    public func isOffscreen(_ frame: Rect) -> Bool {
        frame.x <= -90000 || frame.y <= -90000
    }

    /// Calculate the offscreen position for a window.
    public func offscreenPosition() -> CGPoint {
        offscreenPoint
    }
}
