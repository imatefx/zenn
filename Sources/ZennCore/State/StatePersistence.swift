import Foundation
import ZennShared

/// Handles saving and restoring world state to/from disk.
public class StatePersistence {
    private let stateFilePath: String

    public init(stateFilePath: String? = nil) {
        if let path = stateFilePath {
            self.stateFilePath = path
        } else {
            let configDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/zenn")
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            self.stateFilePath = configDir.appendingPathComponent("state.json").path
        }
    }

    /// Save the current world state to disk.
    public func save(state: WorldState) throws {
        let snapshot = createSnapshot(from: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: URL(fileURLWithPath: stateFilePath))
    }

    /// Load state from disk.
    public func load() throws -> StateSnapshot {
        let data = try Data(contentsOf: URL(fileURLWithPath: stateFilePath))
        let decoder = JSONDecoder()
        return try decoder.decode(StateSnapshot.self, from: data)
    }

    /// Check if a saved state exists.
    public var hasSavedState: Bool {
        FileManager.default.fileExists(atPath: stateFilePath)
    }

    /// Delete saved state.
    public func deleteSavedState() {
        try? FileManager.default.removeItem(atPath: stateFilePath)
    }

    /// Create a snapshot from the current world state.
    /// Only saves workspace settings (gaps, layout mode, split axis).
    /// Tree structure and window IDs are NOT saved — they're rebuilt from
    /// discovered windows on each launch since macOS reuses CGWindowIDs.
    public func createSnapshot(from state: WorldState) -> StateSnapshot {
        var snapshot = StateSnapshot()
        snapshot.globalGaps = state.globalGaps

        for (_, monitor) in state.monitors {
            var monitorSnap = MonitorSnapshot(
                displayID: monitor.displayID.rawValue,
                activeWorkspaceNumber: monitor.activeWorkspaceNumber,
                gaps: monitor.gaps
            )

            for (number, workspace) in monitor.workspaces {
                let wsSnap = WorkspaceSnapshot(
                    number: number,
                    name: workspace.id.name,
                    layoutMode: workspace.layoutMode,
                    defaultSplitAxis: workspace.defaultSplitAxis,
                    gapOverride: workspace.gapOverride
                )
                monitorSnap.workspaces.append(wsSnap)
            }

            snapshot.monitors.append(monitorSnap)
        }

        return snapshot
    }

}
