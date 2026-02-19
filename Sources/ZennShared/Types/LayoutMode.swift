import Foundation

/// The layout mode for a workspace.
public enum LayoutMode: String, Codable, Sendable {
    /// Binary split tiling (H/V splits).
    case tiling

    /// Single window fills the workspace (monocle/fullscreen).
    case monocle
}

/// The state of a window within the tiling system.
public enum WindowMode: String, Codable, Sendable {
    /// Window participates in tiling layout.
    case tiled

    /// Window floats above tiled windows but stays on its workspace.
    case floating

    /// Window floats above all windows and is visible on all workspaces.
    case sticky

    /// Window fills the entire workspace.
    case fullscreen
}
