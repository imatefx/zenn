import XCTest
@testable import ZennCore
@testable import ZennShared

final class WorkspaceTests: XCTestCase {

    func testInsertAndRemoveWindow() {
        let workspace = Workspace(
            id: WorkspaceID(number: 1),
            monitorID: DisplayID(1)
        )

        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")

        workspace.insertWindow(w1)
        workspace.insertWindow(w2)

        XCTAssertEqual(workspace.windowCount, 2)
        XCTAssertFalse(workspace.isEmpty)

        workspace.removeWindow(WindowID(1))
        XCTAssertEqual(workspace.windowCount, 1)

        workspace.removeWindow(WindowID(2))
        XCTAssertTrue(workspace.isEmpty)
    }

    func testFocusUpdatesOnRemove() {
        let workspace = Workspace(
            id: WorkspaceID(number: 1),
            monitorID: DisplayID(1)
        )

        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")

        workspace.insertWindow(w1)
        workspace.insertWindow(w2)
        workspace.focusedWindowID = WindowID(1)

        workspace.removeWindow(WindowID(1))

        // Focus should move to remaining window
        XCTAssertEqual(workspace.focusedWindowID, WindowID(2))
    }

    func testWorkspaceInfo() {
        let workspace = Workspace(
            id: WorkspaceID(number: 3, name: "code"),
            monitorID: DisplayID(1)
        )
        workspace.isActive = true
        workspace.layoutMode = .tiling

        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        workspace.insertWindow(w1)
        workspace.focusedWindowID = WindowID(1)

        let info = workspace.toInfo()

        XCTAssertEqual(info.id.number, 3)
        XCTAssertEqual(info.id.name, "code")
        XCTAssertTrue(info.isActive)
        XCTAssertEqual(info.windowCount, 1)
        XCTAssertEqual(info.focusedWindowID, WindowID(1))
        XCTAssertEqual(info.layoutMode, .tiling)
    }
}

final class MonitorTests: XCTestCase {

    func testWorkspaceCreation() {
        let monitor = Monitor(displayID: DisplayID(1))
        monitor.ensureWorkspaces(count: 9)

        XCTAssertEqual(monitor.workspaces.count, 9)

        let ws3 = monitor.workspace(number: 3)
        XCTAssertEqual(ws3.id.number, 3)
    }

    func testWorkspaceSwitching() {
        let monitor = Monitor(displayID: DisplayID(1))
        monitor.ensureWorkspaces(count: 3)
        monitor.switchToWorkspace(number: 1)

        XCTAssertEqual(monitor.activeWorkspaceNumber, 1)
        XCTAssertTrue(monitor.activeWorkspace?.isActive ?? false)

        let previous = monitor.switchToWorkspace(number: 2)

        XCTAssertEqual(previous, 1)
        XCTAssertEqual(monitor.activeWorkspaceNumber, 2)
        XCTAssertTrue(monitor.activeWorkspace?.isActive ?? false)
        XCTAssertEqual(monitor.activeWorkspace?.previousWorkspaceID?.number, 1)
    }

    func testMonitorInfo() {
        let monitor = Monitor(
            displayID: DisplayID(42),
            frame: Rect(x: 0, y: 0, width: 2560, height: 1440),
            visibleFrame: Rect(x: 0, y: 25, width: 2560, height: 1415)
        )
        monitor.ensureWorkspaces(count: 3)
        monitor.switchToWorkspace(number: 1)

        let info = monitor.toInfo()

        XCTAssertEqual(info.displayID, DisplayID(42))
        XCTAssertEqual(info.frame.width, 2560)
        XCTAssertEqual(info.workspaceIDs.count, 3)
    }
}
