import Foundation

/// Wire format for IPC messages over Unix socket.
/// Format: 4-byte big-endian length prefix + JSON payload.
public struct IPCMessage: Sendable {
    /// Encode a Codable value to wire format (length-prefixed JSON).
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(value)
        var length = UInt32(json.count).bigEndian
        var data = Data(bytes: &length, count: 4)
        data.append(json)
        return data
    }

    /// Decode a Codable value from JSON data (without length prefix).
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    /// Extract the length prefix from wire data.
    public static func readLength(from data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }
        let length = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return UInt32(bigEndian: length)
    }

    /// The Unix socket path for IPC.
    public static var socketPath: String {
        let tmpDir = NSTemporaryDirectory()
        return "\(tmpDir)zenn.sock"
    }

    /// The HTTP API port.
    public static let httpPort: Int = 19876

    /// The HTTP API base URL.
    public static var httpBaseURL: String {
        "http://localhost:\(httpPort)"
    }
}
