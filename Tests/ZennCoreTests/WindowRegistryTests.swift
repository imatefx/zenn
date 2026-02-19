import XCTest
@testable import ZennCore
@testable import ZennShared

final class WindowRegistryTests: XCTestCase {

    func testRegisterAndLookup() {
        let registry = WindowRegistry()
        let ws = WindowState(
            windowID: WindowID(1),
            appName: "Test",
            appBundleID: "com.test",
            pid: 100
        )

        registry.register(ws)

        XCTAssertEqual(registry.count, 1)
        XCTAssertTrue(registry.contains(WindowID(1)))
        XCTAssertNotNil(registry.window(for: WindowID(1)))
        XCTAssertEqual(registry.window(for: WindowID(1))?.appName, "Test")
    }

    func testUnregister() {
        let registry = WindowRegistry()
        let ws = WindowState(windowID: WindowID(1), appName: "Test", appBundleID: "com.test", pid: 100)

        registry.register(ws)
        let removed = registry.unregister(WindowID(1))

        XCTAssertNotNil(removed)
        XCTAssertEqual(registry.count, 0)
        XCTAssertFalse(registry.contains(WindowID(1)))
    }

    func testFilterByWorkspace() {
        let registry = WindowRegistry()

        let ws1 = WindowState(windowID: WindowID(1), appName: "A", appBundleID: "com.a", pid: 1)
        ws1.workspaceID = WorkspaceID(number: 1)

        let ws2 = WindowState(windowID: WindowID(2), appName: "B", appBundleID: "com.b", pid: 2)
        ws2.workspaceID = WorkspaceID(number: 2)

        let ws3 = WindowState(windowID: WindowID(3), appName: "C", appBundleID: "com.c", pid: 3)
        ws3.workspaceID = WorkspaceID(number: 1)

        registry.register(ws1)
        registry.register(ws2)
        registry.register(ws3)

        let onWorkspace1 = registry.windows(on: WorkspaceID(number: 1))
        XCTAssertEqual(onWorkspace1.count, 2)

        let onWorkspace2 = registry.windows(on: WorkspaceID(number: 2))
        XCTAssertEqual(onWorkspace2.count, 1)
    }

    func testFilterByMode() {
        let registry = WindowRegistry()

        let ws1 = WindowState(windowID: WindowID(1), appName: "A", appBundleID: "com.a", pid: 1)
        ws1.mode = .tiled
        ws1.workspaceID = WorkspaceID(number: 1)

        let ws2 = WindowState(windowID: WindowID(2), appName: "B", appBundleID: "com.b", pid: 2)
        ws2.mode = .floating
        ws2.workspaceID = WorkspaceID(number: 1)

        let ws3 = WindowState(windowID: WindowID(3), appName: "C", appBundleID: "com.c", pid: 3)
        ws3.mode = .sticky

        registry.register(ws1)
        registry.register(ws2)
        registry.register(ws3)

        XCTAssertEqual(registry.tiledWindows(on: WorkspaceID(number: 1)).count, 1)
        XCTAssertEqual(registry.floatingWindows(on: WorkspaceID(number: 1)).count, 1)
        XCTAssertEqual(registry.stickyWindows().count, 1)
    }
}
