import Foundation

/// Cardinal direction for focus/move operations.
public enum Direction: String, Codable, Sendable, CaseIterable {
    case left
    case right
    case up
    case down

    /// The axis this direction lies on.
    public var axis: SplitAxis {
        switch self {
        case .left, .right: return .horizontal
        case .up, .down: return .vertical
        }
    }

    /// The opposite direction.
    public var opposite: Direction {
        switch self {
        case .left: return .right
        case .right: return .left
        case .up: return .down
        case .down: return .up
        }
    }

    /// Whether this direction is "positive" (right/down) along its axis.
    public var isPositive: Bool {
        switch self {
        case .right, .down: return true
        case .left, .up: return false
        }
    }
}

/// Cycle direction for next/previous focus.
public enum CycleDirection: String, Codable, Sendable {
    case next
    case previous
}
