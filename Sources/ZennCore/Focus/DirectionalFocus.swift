import Foundation
import ZennShared

/// Directional focus algorithms using geometric position of windows.
public enum DirectionalFocus {
    /// Score a candidate window based on how well it matches the desired direction.
    /// Lower score = better match.
    public static func score(
        from sourceFrame: Rect,
        to candidateFrame: Rect,
        direction: Direction
    ) -> Double? {
        let sourceCenter = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        let candidateCenter = CGPoint(x: candidateFrame.midX, y: candidateFrame.midY)

        let dx = candidateCenter.x - sourceCenter.x
        let dy = candidateCenter.y - sourceCenter.y

        // Check if candidate is in the correct direction
        switch direction {
        case .left:
            guard dx < 0 else { return nil }
        case .right:
            guard dx > 0 else { return nil }
        case .up:
            guard dy < 0 else { return nil }
        case .down:
            guard dy > 0 else { return nil }
        }

        // Calculate score: primary axis distance + penalized secondary axis distance
        let primaryDistance: Double
        let secondaryDistance: Double

        switch direction {
        case .left, .right:
            primaryDistance = abs(Double(dx))
            secondaryDistance = abs(Double(dy))
        case .up, .down:
            primaryDistance = abs(Double(dy))
            secondaryDistance = abs(Double(dx))
        }

        // Use overlap on the secondary axis as a bonus (windows that overlap are preferred)
        let overlapBonus = calculateOverlap(
            source: sourceFrame,
            candidate: candidateFrame,
            axis: direction.axis
        )

        return primaryDistance + secondaryDistance * 2.0 - overlapBonus * 0.5
    }

    /// Calculate the overlap between two frames on the perpendicular axis.
    private static func calculateOverlap(
        source: Rect,
        candidate: Rect,
        axis: SplitAxis
    ) -> Double {
        switch axis {
        case .horizontal:
            // For left/right movement, check vertical overlap
            let overlapStart = max(source.minY, candidate.minY)
            let overlapEnd = min(source.maxY, candidate.maxY)
            return max(0, overlapEnd - overlapStart)
        case .vertical:
            // For up/down movement, check horizontal overlap
            let overlapStart = max(source.minX, candidate.minX)
            let overlapEnd = min(source.maxX, candidate.maxX)
            return max(0, overlapEnd - overlapStart)
        }
    }

    /// Find the best focus target in a direction from a set of candidate frames.
    public static func bestTarget(
        from sourceID: WindowID,
        sourceFrame: Rect,
        candidates: [(WindowID, Rect)],
        direction: Direction
    ) -> WindowID? {
        var bestID: WindowID?
        var bestScore: Double = .infinity

        for (candidateID, candidateFrame) in candidates {
            guard candidateID != sourceID else { continue }
            if let candidateScore = score(from: sourceFrame, to: candidateFrame, direction: direction) {
                if candidateScore < bestScore {
                    bestScore = candidateScore
                    bestID = candidateID
                }
            }
        }

        return bestID
    }
}
