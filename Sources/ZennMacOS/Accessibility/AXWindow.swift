import Foundation
import ApplicationServices
import ZennShared

/// High-level wrapper around an AXUIElement representing a window.
public class AXWindow {
    /// The underlying accessibility element.
    public let element: AXUIElement

    /// The CGWindowID for this window.
    public let windowID: WindowID

    /// The PID of the owning application.
    public let pid: pid_t

    public init(element: AXUIElement, windowID: WindowID, pid: pid_t) {
        self.element = element
        self.windowID = windowID
        self.pid = pid
    }

    /// Create from an AXUIElement, looking up the window ID.
    public convenience init?(element: AXUIElement, pid: pid_t) {
        let wid = AXHelpers.windowID(from: element)
        guard !wid.isNull else { return nil }
        self.init(element: element, windowID: wid, pid: pid)
    }

    /// The window title.
    public var title: String {
        AXHelpers.title(of: element)
    }

    /// The current frame of the window.
    public var frame: Rect? {
        AXHelpers.frame(of: element)
    }

    /// Set the frame (position + size) of the window.
    @discardableResult
    public func setFrame(_ rect: Rect) -> Bool {
        AXHelpers.setFrame(rect, of: element)
    }

    /// Whether the window is minimized.
    public var isMinimized: Bool {
        AXHelpers.isMinimized(element)
    }

    /// Whether this is a standard window (not a dialog, sheet, etc.).
    public var isStandardWindow: Bool {
        AXHelpers.isStandardWindow(element)
    }

    /// Raise the window to the front.
    @discardableResult
    public func raise() -> Bool {
        AXHelpers.raise(element)
    }

    /// Focus this window (raise + activate app).
    public func focus() {
        raise()
        AXHelpers.focusApp(pid: pid)
    }

    /// Move the window offscreen (for virtual workspace hiding).
    @discardableResult
    public func moveOffscreen() -> Bool {
        AXHelpers.setPosition(CGPoint(x: 10000, y: 10000), of: element)
    }
}
