import XCTest
@testable import ZennCore
@testable import ZennShared

final class StatePersistenceTests: XCTestCase {

    func testSnapshotRoundTrip() throws {
        let tmpPath = NSTemporaryDirectory() + "zenn-test-state-\(UUID()).json"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let persistence = StatePersistence(stateFilePath: tmpPath)

        // Create a state with some data
        let state = WorldState()
        state.globalGaps = GapConfig(inner: 8, outerAll: 12)

        let monitor = Monitor(
            displayID: DisplayID(1),
            frame: Rect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: Rect(x: 0, y: 25, width: 1920, height: 1055)
        )
        state.addMonitor(monitor)

        let workspace = monitor.workspace(number: 1)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "com.test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "com.test", appName: "Test")
        workspace.insertWindow(w1)
        workspace.insertWindow(w2)

        state.focusedWindowID = WindowID(1)

        // Save
        try persistence.save(state: state)
        XCTAssertTrue(persistence.hasSavedState)

        // Load
        let snapshot = try persistence.load()

        XCTAssertEqual(snapshot.globalGaps.inner, 8)
        XCTAssertEqual(snapshot.monitors.count, 1)
        XCTAssertEqual(snapshot.monitors[0].displayID, 1)

        // Verify workspace settings were saved (monitors have 9 workspaces by default)
        let monitorSnap = snapshot.monitors[0]
        XCTAssertEqual(monitorSnap.workspaces.count, 9)
        // Find workspace 1 in the snapshot
        let ws1 = monitorSnap.workspaces.first { $0.number == 1 }
        XCTAssertNotNil(ws1)
        XCTAssertEqual(ws1?.layoutMode, .tiling)
    }

    func testSnapshotOnlySavesWorkspaceSettings() throws {
        let tmpPath = NSTemporaryDirectory() + "zenn-test-state-settings-\(UUID()).json"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let persistence = StatePersistence(stateFilePath: tmpPath)

        let state = WorldState()
        state.globalGaps = GapConfig(inner: 10, outerAll: 5)

        let monitor = Monitor(
            displayID: DisplayID(1),
            frame: Rect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: Rect(x: 0, y: 25, width: 1920, height: 1055)
        )
        state.addMonitor(monitor)

        let workspace = monitor.workspace(number: 1)
        workspace.layoutMode = .monocle
        workspace.defaultSplitAxis = .vertical
        workspace.gapOverride = GapConfig(inner: 4, outerAll: 2)

        // Add windows (should NOT be persisted)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "com.test", appName: "Test")
        workspace.insertWindow(w1)

        try persistence.save(state: state)
        let snapshot = try persistence.load()

        // Workspace settings should be saved
        let wsSnap = snapshot.monitors[0].workspaces[0]
        XCTAssertEqual(wsSnap.layoutMode, .monocle)
        XCTAssertEqual(wsSnap.defaultSplitAxis, .vertical)
        XCTAssertEqual(wsSnap.gapOverride?.inner, 4)
    }
}
