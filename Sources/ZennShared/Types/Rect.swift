import Foundation
import CoreGraphics

/// A rectangle with origin and size, independent of platform types.
public struct Rect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(cgRect: CGRect) {
        self.x = Double(cgRect.origin.x)
        self.y = Double(cgRect.origin.y)
        self.width = Double(cgRect.size.width)
        self.height = Double(cgRect.size.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public var origin: CGPoint {
        CGPoint(x: x, y: y)
    }

    public var size: CGSize {
        CGSize(width: width, height: height)
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2.0 }
    public var midY: Double { y + height / 2.0 }

    /// Inset the rect by the given amounts on each side.
    public func inset(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0) -> Rect {
        Rect(
            x: self.x + left,
            y: self.y + top,
            width: self.width - left - right,
            height: self.height - top - bottom
        )
    }

    /// Returns true if this rect contains the given point.
    public func contains(point: CGPoint) -> Bool {
        Double(point.x) >= x && Double(point.x) <= maxX &&
        Double(point.y) >= y && Double(point.y) <= maxY
    }

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)
}
