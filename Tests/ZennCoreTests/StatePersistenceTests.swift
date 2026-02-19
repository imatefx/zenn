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
        XCTAssertEqual(snapshot.focusedWindowID, 1)
        XCTAssertEqual(snapshot.monitors.count, 1)
        XCTAssertEqual(snapshot.monitors[0].displayID, 1)
    }

    func testTreeSnapshotRestore() {
        let persistence = StatePersistence(stateFilePath: "/dev/null")

        let snapshot = TreeNodeSnapshot.container(
            axis: .horizontal,
            ratios: [0.6, 0.4],
            children: [
                .window(windowID: 1, appBundleID: "com.a", appName: "A"),
                .container(
                    axis: .vertical,
                    ratios: [0.5, 0.5],
                    children: [
                        .window(windowID: 2, appBundleID: "com.b", appName: "B"),
                        .window(windowID: 3, appBundleID: "com.c", appName: "C"),
                    ]
                ),
            ]
        )

        let restored = persistence.restoreTree(from: snapshot)

        guard case .container(let root) = restored else {
            XCTFail("Expected container")
            return
        }

        XCTAssertEqual(root.axis, .horizontal)
        XCTAssertEqual(root.ratios.map { Double($0) }, [0.6, 0.4])
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(root.allWindowIDs.count, 3)
    }
}
