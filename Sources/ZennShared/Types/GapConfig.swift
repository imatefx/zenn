import Foundation

/// Configuration for gaps (spacing) around and between windows.
public struct GapConfig: Codable, Sendable, Equatable {
    /// Gap between adjacent tiled windows.
    public var inner: Double

    /// Gaps from screen edges (per-side).
    public var outer: EdgeGaps

    public init(inner: Double = 0, outer: EdgeGaps = .zero) {
        self.inner = inner
        self.outer = outer
    }

    public init(inner: Double = 0, outerAll: Double = 0) {
        self.inner = inner
        self.outer = EdgeGaps(top: outerAll, bottom: outerAll, left: outerAll, right: outerAll)
    }

    public static let zero = GapConfig(inner: 0, outer: .zero)
}

/// Per-side gap values.
public struct EdgeGaps: Codable, Sendable, Equatable {
    public var top: Double
    public var bottom: Double
    public var left: Double
    public var right: Double

    public init(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    public static let zero = EdgeGaps()
}
