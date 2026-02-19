import Foundation
import ZennShared

/// A concrete hook event with associated data.
public struct HookEvent: Sendable {
    public let type: HookEventType
    public let timestamp: Date
    public let data: [String: String]

    public init(type: HookEventType, data: [String: String] = [:]) {
        self.type = type
        self.timestamp = Date()
        self.data = data
    }

    /// Create a window-related event.
    public static func window(
        _ type: HookEventType,
        windowID: WindowID,
        appName: String = "",
        title: String = ""
    ) -> HookEvent {
        HookEvent(type: type, data: [
            "window_id": "\(windowID.rawValue)",
            "app_name": appName,
            "title": title,
        ])
    }

    /// Create a workspace-related event.
    public static func workspace(
        _ type: HookEventType,
        workspaceID: WorkspaceID,
        previousWorkspaceID: WorkspaceID? = nil
    ) -> HookEvent {
        var data = ["workspace_id": workspaceID.description]
        if let prev = previousWorkspaceID {
            data["previous_workspace_id"] = prev.description
        }
        return HookEvent(type: type, data: data)
    }

    /// Create an app-related event.
    public static func app(
        _ type: HookEventType,
        appName: String,
        bundleID: String
    ) -> HookEvent {
        HookEvent(type: type, data: [
            "app_name": appName,
            "bundle_id": bundleID,
        ])
    }

    /// Create a monitor-related event.
    public static func monitor(
        _ type: HookEventType,
        displayID: DisplayID
    ) -> HookEvent {
        HookEvent(type: type, data: [
            "display_id": "\(displayID.rawValue)",
        ])
    }

    /// Serializable representation for IPC.
    public var serialized: [String: String] {
        var result = data
        result["event"] = type.rawValue
        result["timestamp"] = ISO8601DateFormatter().string(from: timestamp)
        return result
    }
}
