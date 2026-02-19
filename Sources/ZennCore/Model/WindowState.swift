import Foundation
import ZennShared

/// Full state for a tracked window.
public class WindowState {
    public let windowID: WindowID
    public let appName: String
    public let appBundleID: String
    public let pid: pid_t
    public var windowTitle: String
    public var frame: Rect
    public var mode: WindowMode
    public var workspaceID: WorkspaceID
    public var monitorID: DisplayID
    public var isMinimized: Bool
    public var savedFrame: Rect?  // Frame before fullscreen/float, for restoration

    public init(
        windowID: WindowID,
        appName: String,
        appBundleID: String,
        pid: pid_t,
        windowTitle: String = "",
        frame: Rect = .zero,
        mode: WindowMode = .tiled,
        workspaceID: WorkspaceID = WorkspaceID(number: 1),
        monitorID: DisplayID = DisplayID(0),
        isMinimized: Bool = false
    ) {
        self.windowID = windowID
        self.appName = appName
        self.appBundleID = appBundleID
        self.pid = pid
        self.windowTitle = windowTitle
        self.frame = frame
        self.mode = mode
        self.workspaceID = workspaceID
        self.monitorID = monitorID
        self.isMinimized = isMinimized
    }

    /// Convert to a serializable WindowInfo snapshot.
    public func toInfo(isFocused: Bool) -> WindowInfo {
        WindowInfo(
            windowID: windowID,
            appName: appName,
            appBundleID: appBundleID,
            title: windowTitle,
            frame: frame,
            mode: mode,
            workspaceID: workspaceID,
            monitorID: monitorID,
            isFocused: isFocused,
            isMinimized: isMinimized
        )
    }
}
