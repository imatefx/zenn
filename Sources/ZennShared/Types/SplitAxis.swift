import Foundation

/// Axis along which a container splits its children.
public enum SplitAxis: String, Codable, Sendable {
    /// Children arranged left-to-right.
    case horizontal
    /// Children arranged top-to-bottom.
    case vertical

    /// The perpendicular axis.
    public var perpendicular: SplitAxis {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}
