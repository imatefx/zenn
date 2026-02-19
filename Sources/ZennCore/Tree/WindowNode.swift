import Foundation
import ZennShared

/// A leaf node in the tiling tree representing a single window.
public class WindowNode {
    public let id: NodeID

    /// The CGWindowID of this window.
    public let windowID: WindowID

    /// The bundle identifier of the owning application.
    public let appBundleID: String

    /// The application name.
    public let appName: String

    /// The current window title (may change).
    public var windowTitle: String

    /// Weak reference to the parent container.
    public weak var parent: ContainerNode?

    public init(
        id: NodeID = NodeID(),
        windowID: WindowID,
        appBundleID: String,
        appName: String,
        windowTitle: String = "",
        parent: ContainerNode? = nil
    ) {
        self.id = id
        self.windowID = windowID
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.parent = parent
    }

    /// The depth of this window node in the tree.
    public var depth: Int {
        var d = 0
        var current = parent
        while let p = current {
            d += 1
            current = p.parent
        }
        return d
    }
}

extension WindowNode: CustomStringConvertible {
    public var description: String {
        "WindowNode(\(id), \(windowID), \"\(appName)\")"
    }
}
