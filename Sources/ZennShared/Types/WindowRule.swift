import Foundation

/// A rule that matches windows and applies settings.
public struct WindowRule: Codable, Sendable {
    /// Regex pattern to match app name.
    public var appNamePattern: String?

    /// Regex pattern to match window title.
    public var titlePattern: String?

    /// Exact match on bundle ID.
    public var bundleID: String?

    /// Mode to apply to matching windows.
    public var mode: WindowMode?

    /// Workspace to move matching windows to.
    public var workspace: WorkspaceID?

    /// Monitor to move matching windows to.
    public var monitor: Int?

    public init(
        appNamePattern: String? = nil,
        titlePattern: String? = nil,
        bundleID: String? = nil,
        mode: WindowMode? = nil,
        workspace: WorkspaceID? = nil,
        monitor: Int? = nil
    ) {
        self.appNamePattern = appNamePattern
        self.titlePattern = titlePattern
        self.bundleID = bundleID
        self.mode = mode
        self.workspace = workspace
        self.monitor = monitor
    }

    /// Check if this rule matches the given window properties.
    public func matches(appName: String, title: String, bundleID: String) -> Bool {
        if let pattern = appNamePattern {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return false
            }
            let range = NSRange(appName.startIndex..., in: appName)
            if regex.firstMatch(in: appName, range: range) == nil {
                return false
            }
        }

        if let pattern = titlePattern {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return false
            }
            let range = NSRange(title.startIndex..., in: title)
            if regex.firstMatch(in: title, range: range) == nil {
                return false
            }
        }

        if let requiredBundleID = self.bundleID {
            if bundleID != requiredBundleID {
                return false
            }
        }

        return true
    }
}
