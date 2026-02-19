import Foundation
import ApplicationServices
import AppKit
import ZennShared

/// Discovers existing windows on the system using CGWindowList and Accessibility APIs.
public class WindowDiscovery {
    /// Information about a discovered window.
    public struct DiscoveredWindow {
        public let windowID: WindowID
        public let axWindow: AXWindow
        public let appName: String
        public let appBundleID: String
        public let pid: pid_t
        public let title: String
        public let frame: Rect
        public let isMinimized: Bool
    }

    public init() {}

    /// Discover all visible, tileable windows across all applications.
    public func discoverWindows() -> [DiscoveredWindow] {
        var discovered: [DiscoveredWindow] = []

        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }
            let appName = app.localizedName ?? bundleID
            let pid = app.processIdentifier

            let axApp = AXApplication(pid: pid, appName: appName, bundleID: bundleID)
            let windows = axApp.windows()

            for axWindow in windows {
                // Skip non-standard windows
                guard axWindow.isStandardWindow else { continue }

                guard let frame = axWindow.frame else { continue }

                let window = DiscoveredWindow(
                    windowID: axWindow.windowID,
                    axWindow: axWindow,
                    appName: appName,
                    appBundleID: bundleID,
                    pid: pid,
                    title: axWindow.title,
                    frame: frame,
                    isMinimized: axWindow.isMinimized
                )
                discovered.append(window)
            }
        }

        return discovered
    }

    /// Get the list of visible windows from CGWindowList (for cross-referencing).
    public func cgWindowList() -> [(windowID: WindowID, ownerPID: pid_t, ownerName: String, bounds: Rect)] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { info in
            guard let windowNumber = info[kCGWindowNumber as String] as? Int,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? Double,
                  let y = boundsDict["Y"] as? Double,
                  let width = boundsDict["Width"] as? Double,
                  let height = boundsDict["Height"] as? Double,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 // Only normal layer windows
            else {
                return nil
            }

            return (
                windowID: WindowID(UInt32(windowNumber)),
                ownerPID: pid_t(ownerPID),
                ownerName: ownerName,
                bounds: Rect(x: x, y: y, width: width, height: height)
            )
        }
    }
}
