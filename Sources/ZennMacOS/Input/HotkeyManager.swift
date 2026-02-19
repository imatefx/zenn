import Foundation
import ZennShared

/// Higher-level hotkey manager that maps modifier+key combinations to actions.
public class HotkeyManager {
    /// Registered keybindings.
    private var bindings: [(modifiers: KeyModifier, key: String, action: () -> Void)] = []

    /// The underlying event tap.
    private let eventTap: EventTapManager

    public init(eventTap: EventTapManager = EventTapManager()) {
        self.eventTap = eventTap
    }

    /// Register a keybinding.
    public func bind(modifiers: KeyModifier, key: String, action: @escaping () -> Void) {
        bindings.append((modifiers: modifiers, key: key.lowercased(), action: action))
        print("[Zenn] Bound hotkey: \(modifiers) + \(key.lowercased()) (total: \(bindings.count))")
    }

    /// Register a keybinding from modifier strings.
    public func bind(modifierStrings: [String], key: String, action: @escaping () -> Void) {
        let modifiers = KeyModifier.from(strings: modifierStrings)
        bind(modifiers: modifiers, key: key, action: action)
    }

    /// Remove all keybindings.
    public func unbindAll() {
        bindings.removeAll()
    }

    /// Start listening for hotkeys.
    public func start() -> Bool {
        eventTap.start { [weak self] modifiers, key in
            guard let self = self else { return false }
            return self.handleKey(modifiers: modifiers, key: key)
        }
    }

    /// Stop listening for hotkeys.
    public func stop() {
        eventTap.stop()
    }

    private func handleKey(modifiers: KeyModifier, key: String) -> Bool {
        let normalizedKey = key.lowercased()
        for binding in bindings {
            if binding.modifiers == modifiers && binding.key == normalizedKey {
                print("[Zenn] Hotkey matched: \(normalizedKey)")
                binding.action()
                return true  // Consumed
            }
        }
        return false  // Not consumed, pass through
    }
}
