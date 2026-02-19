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
    public func createSnapshot(from state: WorldState) -> StateSnapshot {
        var snapshot = StateSnapshot()
        snapshot.focusedWindowID = state.focusedWindowID?.rawValue
        snapshot.globalGaps = state.globalGaps

        for (_, monitor) in state.monitors {
            var monitorSnap = MonitorSnapshot(
                displayID: monitor.displayID.rawValue,
                activeWorkspaceNumber: monitor.activeWorkspaceNumber,
                gaps: monitor.gaps
            )

            for (number, workspace) in monitor.workspaces {
                var wsSnap = WorkspaceSnapshot(
                    number: number,
                    name: workspace.id.name,
                    layoutMode: workspace.layoutMode,
                    defaultSplitAxis: workspace.defaultSplitAxis,
                    focusedWindowID: workspace.focusedWindowID?.rawValue,
                    gapOverride: workspace.gapOverride
                )

                if let root = workspace.tileRoot {
                    wsSnap.treeSnapshot = snapshotTreeNode(.container(root))
                    wsSnap.windowIDs = root.allWindowIDs.map { $0.rawValue }
                }

                monitorSnap.workspaces.append(wsSnap)
            }

            snapshot.monitors.append(monitorSnap)
        }

        return snapshot
    }

    private func snapshotTreeNode(_ node: TreeNode) -> TreeNodeSnapshot {
        switch node {
        case .container(let container):
            return .container(
                axis: container.axis,
                ratios: container.ratios.map { Double($0) },
                children: container.children.map { snapshotTreeNode($0) }
            )
        case .window(let window):
            return .window(
                windowID: window.windowID.rawValue,
                appBundleID: window.appBundleID,
                appName: window.appName
            )
        }
    }

    /// Restore tree structure from a snapshot (windows are re-associated during discovery).
    public func restoreTree(from snapshot: TreeNodeSnapshot) -> TreeNode {
        switch snapshot {
        case .container(let axis, let ratios, let children):
            let container = ContainerNode(axis: axis)
            for childSnap in children {
                let childNode = restoreTree(from: childSnap)
                container.appendChild(childNode)
            }
            // Override the equalized ratios with the saved ratios
            if ratios.count == container.children.count {
                container.ratios = ratios.map { CGFloat($0) }
            }
            return .container(container)

        case .window(let windowID, let appBundleID, let appName):
            let window = WindowNode(
                windowID: WindowID(windowID),
                appBundleID: appBundleID,
                appName: appName
            )
            return .window(window)
        }
    }
}
