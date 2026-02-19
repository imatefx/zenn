import Foundation
import ApplicationServices
import AppKit
import ZennShared
import CPrivateAPI

/// Helpers for working with the Accessibility API.
public enum AXHelpers {
    /// Check if the app has accessibility permission.
    public static var isAccessibilityEnabled: Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    /// Prompt the user for accessibility permission.
    public static func promptForAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
    }

    /// Get the CGWindowID from an AXUIElement using the private API.
    public static func windowID(from element: AXUIElement) -> WindowID {
        let cgWindowID = CPrivateAPI_GetWindowID(element)
        return WindowID(cgWindowID)
    }

    /// Get a string attribute from an AXUIElement.
    public static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let str = value as? String else { return nil }
        return str
    }

    /// Get a CGPoint attribute (position) from an AXUIElement.
    public static func positionAttribute(from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard result == .success else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    /// Get a CGSize attribute (size) from an AXUIElement.
    public static func sizeAttribute(from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard result == .success else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    /// Get the frame (position + size) of an AXUIElement.
    public static func frame(of element: AXUIElement) -> Rect? {
        guard let position = positionAttribute(from: element),
              let size = sizeAttribute(from: element) else {
            return nil
        }
        return Rect(x: Double(position.x), y: Double(position.y),
                     width: Double(size.width), height: Double(size.height))
    }

    /// Set the position of an AXUIElement.
    public static func setPosition(_ point: CGPoint, of element: AXUIElement) -> Bool {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else { return false }
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        return result == .success
    }

    /// Set the size of an AXUIElement.
    public static func setSize(_ size: CGSize, of element: AXUIElement) -> Bool {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else { return false }
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        return result == .success
    }

    /// Set both position and size of an AXUIElement.
    public static func setFrame(_ rect: Rect, of element: AXUIElement) -> Bool {
        let posResult = setPosition(rect.origin, of: element)
        let sizeResult = setSize(rect.size, of: element)
        return posResult && sizeResult
    }

    /// Get a boolean attribute from an AXUIElement.
    public static func boolAttribute(_ attribute: String, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    /// Check if a window is minimized.
    public static func isMinimized(_ element: AXUIElement) -> Bool {
        boolAttribute(kAXMinimizedAttribute, from: element) ?? false
    }

    /// Check if a window has a standard window role.
    public static func isStandardWindow(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(kAXRoleAttribute, from: element)
        let subrole = stringAttribute(kAXSubroleAttribute, from: element)
        return role == kAXWindowRole && subrole == kAXStandardWindowSubrole
    }

    /// Raise a window to the front.
    public static func raise(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }

    /// Focus/activate the application that owns this element.
    public static func focusApp(pid: pid_t) {
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    /// Get the title of a window element.
    public static func title(of element: AXUIElement) -> String {
        stringAttribute(kAXTitleAttribute, from: element) ?? ""
    }

    /// Get window elements for an application.
    public static func windowElements(forPID pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }
}
