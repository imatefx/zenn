import Foundation

/// Unique identifier for a window, wrapping CGWindowID.
public struct WindowID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public var description: String {
        "WindowID(\(rawValue))"
    }

    /// Represents an invalid/null window ID.
    public static let null = WindowID(0)

    public var isNull: Bool {
        rawValue == 0
    }
}

/// Unique identifier for a tree node.
public struct NodeID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public var description: String {
        "NodeID(\(rawValue.uuidString.prefix(8)))"
    }
}

/// Unique identifier for a workspace.
public struct WorkspaceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let number: Int
    public let name: String?

    public init(number: Int, name: String? = nil) {
        self.number = number
        self.name = name
    }

    public var description: String {
        if let name = name {
            return "\(number):\(name)"
        }
        return "\(number)"
    }

    public var displayName: String {
        name ?? "\(number)"
    }
}

/// Unique identifier for a display/monitor.
public struct DisplayID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public var description: String {
        "DisplayID(\(rawValue))"
    }
}
