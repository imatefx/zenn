import Foundation
import ZennShared

/// Convenience dispatcher that creates and sends hook events.
public class HookDispatcher {
    private let registry: HookRegistry

    public init(registry: HookRegistry) {
        self.registry = registry
    }

    // MARK: - Window Events

    public func windowCreated(windowID: WindowID, appName: String, title: String) {
        registry.dispatch(.window(.windowCreated, windowID: windowID, appName: appName, title: title))
    }

    public func windowDestroyed(windowID: WindowID, appName: String) {
        registry.dispatch(.window(.windowDestroyed, windowID: windowID, appName: appName))
    }

    public func windowFocused(windowID: WindowID, appName: String, title: String) {
        registry.dispatch(.window(.windowFocused, windowID: windowID, appName: appName, title: title))
    }

    public func windowMoved(windowID: WindowID, appName: String) {
        registry.dispatch(.window(.windowMoved, windowID: windowID, appName: appName))
    }

    public func windowResized(windowID: WindowID, appName: String) {
        registry.dispatch(.window(.windowResized, windowID: windowID, appName: appName))
    }

    public func windowMinimized(windowID: WindowID, appName: String) {
        registry.dispatch(.window(.windowMinimized, windowID: windowID, appName: appName))
    }

    public func windowDeminimized(windowID: WindowID, appName: String) {
        registry.dispatch(.window(.windowDeminimized, windowID: windowID, appName: appName))
    }

    public func windowTitleChanged(windowID: WindowID, title: String) {
        registry.dispatch(.window(.windowTitleChanged, windowID: windowID, title: title))
    }

    public func windowModeChanged(windowID: WindowID, appName: String) {
        registry.dispatch(.window(.windowModeChanged, windowID: windowID, appName: appName))
    }

    // MARK: - Workspace Events

    public func workspaceSwitched(to workspaceID: WorkspaceID, from previousID: WorkspaceID?) {
        registry.dispatch(.workspace(.workspaceSwitched, workspaceID: workspaceID, previousWorkspaceID: previousID))
    }

    public func workspaceCreated(_ workspaceID: WorkspaceID) {
        registry.dispatch(.workspace(.workspaceCreated, workspaceID: workspaceID))
    }

    public func workspaceDestroyed(_ workspaceID: WorkspaceID) {
        registry.dispatch(.workspace(.workspaceDestroyed, workspaceID: workspaceID))
    }

    // MARK: - App Events

    public func appLaunched(appName: String, bundleID: String) {
        registry.dispatch(.app(.appLaunched, appName: appName, bundleID: bundleID))
    }

    public func appTerminated(appName: String, bundleID: String) {
        registry.dispatch(.app(.appTerminated, appName: appName, bundleID: bundleID))
    }

    // MARK: - Monitor Events

    public func monitorConnected(_ displayID: DisplayID) {
        registry.dispatch(.monitor(.monitorConnected, displayID: displayID))
    }

    public func monitorDisconnected(_ displayID: DisplayID) {
        registry.dispatch(.monitor(.monitorDisconnected, displayID: displayID))
    }

    // MARK: - System Events

    public func configReloaded() {
        registry.dispatch(HookEvent(type: .configReloaded))
    }

    public func tilingLayoutChanged(workspaceID: WorkspaceID) {
        registry.dispatch(.workspace(.tilingLayoutChanged, workspaceID: workspaceID))
    }
}
