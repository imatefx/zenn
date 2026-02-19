import Foundation
import ZennMacOS
#if canImport(AppKit)
import AppKit
#endif

/// Ensures accessibility permissions are granted before the app can function.
public class AccessibilityGuard {
    public init() {}

    /// Check and prompt for accessibility permission.
    /// Returns true if permission is already granted.
    public func ensureAccessibility() -> Bool {
        if AXHelpers.isAccessibilityEnabled {
            return true
        }

        // Prompt the user
        _ = AXHelpers.promptForAccessibility()

        // Give the user a moment to respond
        #if canImport(AppKit)
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Zenn needs accessibility permission to manage windows. Please grant access in System Settings > Privacy & Security > Accessibility, then relaunch Zenn."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        #endif

        return AXHelpers.isAccessibilityEnabled
    }

    /// Poll for accessibility permission in the background.
    public func waitForAccessibility(interval: TimeInterval = 1.0, callback: @escaping (Bool) -> Void) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if AXHelpers.isAccessibilityEnabled {
                timer.invalidate()
                callback(true)
            }
        }
    }
}
