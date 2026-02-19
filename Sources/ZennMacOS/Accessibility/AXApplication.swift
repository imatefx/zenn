import Foundation
import ApplicationServices
import AppKit
import ZennShared

/// Wrapper around an application's accessibility element.
public class AXApplication {
    /// The AXUIElement for the application.
    public let element: AXUIElement

    /// The process identifier.
    public let pid: pid_t

    /// The application name.
    public let appName: String

    /// The bundle identifier.
    public let bundleID: String

    public init(pid: pid_t, appName: String, bundleID: String) {
        self.element = AXUIElementCreateApplication(pid)
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
    }

    /// Create from an NSRunningApplication.
    public convenience init?(app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return nil }
        let name = app.localizedName ?? bundleID
        self.init(pid: app.processIdentifier, appName: name, bundleID: bundleID)
    }

    /// Get all windows of this application.
    public func windows() -> [AXWindow] {
        let elements = AXHelpers.windowElements(forPID: pid)
        return elements.compactMap { element in
            AXWindow(element: element, pid: pid)
        }
    }

    /// Get only standard (tileable) windows.
    public func tileableWindows() -> [AXWindow] {
        windows().filter { $0.isStandardWindow && !$0.isMinimized }
    }
}
