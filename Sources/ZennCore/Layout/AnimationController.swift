import Foundation
import ZennShared

/// Controls optional smooth animations for window transitions.
public class AnimationController {
    public var isEnabled: Bool = false
    public var duration: Double = 0.2

    public init(isEnabled: Bool = false, duration: Double = 0.2) {
        self.isEnabled = isEnabled
        self.duration = duration
    }

    /// Represents a window transition from one frame to another.
    public struct Transition {
        public let windowID: WindowID
        public let fromFrame: Rect
        public let toFrame: Rect

        public init(windowID: WindowID, fromFrame: Rect, toFrame: Rect) {
            self.windowID = windowID
            self.fromFrame = fromFrame
            self.toFrame = toFrame
        }
    }

    /// Calculate transitions between current and target frames.
    public func transitions(
        current: [WindowID: Rect],
        target: [WindowID: Rect]
    ) -> [Transition] {
        var transitions: [Transition] = []
        for (windowID, targetFrame) in target {
            let currentFrame = current[windowID] ?? targetFrame
            if currentFrame != targetFrame {
                transitions.append(Transition(
                    windowID: windowID,
                    fromFrame: currentFrame,
                    toFrame: targetFrame
                ))
            }
        }
        return transitions
    }

    /// Interpolate a frame at a given progress (0.0 to 1.0).
    public func interpolate(from: Rect, to: Rect, progress: Double) -> Rect {
        let t = easeInOutCubic(progress)
        return Rect(
            x: from.x + (to.x - from.x) * t,
            y: from.y + (to.y - from.y) * t,
            width: from.width + (to.width - from.width) * t,
            height: from.height + (to.height - from.height) * t
        )
    }

    /// Cubic ease-in-out timing function.
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }
}
