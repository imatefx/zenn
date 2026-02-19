import Foundation

/// Keyboard modifier flags for keybindings.
public struct KeyModifier: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifier(rawValue: 1 << 0)
    public static let option  = KeyModifier(rawValue: 1 << 1)
    public static let control = KeyModifier(rawValue: 1 << 2)
    public static let shift   = KeyModifier(rawValue: 1 << 3)

    /// Alias for option (Lua config uses "alt").
    public static let alt = KeyModifier.option

    /// Parse a modifier string like "cmd", "alt", "ctrl", "shift".
    public static func from(string: String) -> KeyModifier? {
        switch string.lowercased() {
        case "cmd", "command", "super": return .command
        case "alt", "opt", "option": return .option
        case "ctrl", "control": return .control
        case "shift": return .shift
        default: return nil
        }
    }

    /// Parse an array of modifier strings into a combined KeyModifier set.
    public static func from(strings: [String]) -> KeyModifier {
        var result = KeyModifier()
        for s in strings {
            if let mod = from(string: s) {
                result.insert(mod)
            }
        }
        return result
    }
}

/// A keybinding definition.
public struct Keybinding: Sendable {
    public let modifiers: KeyModifier
    public let key: String
    public let action: @Sendable () -> Void

    public init(modifiers: KeyModifier, key: String, action: @escaping @Sendable () -> Void) {
        self.modifiers = modifiers
        self.key = key
        self.action = action
    }
}
