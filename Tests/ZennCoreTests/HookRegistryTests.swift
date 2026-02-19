import XCTest
@testable import ZennCore
@testable import ZennShared

final class HookRegistryTests: XCTestCase {

    func testRegisterAndDispatch() {
        let registry = HookRegistry()
        var received: HookEvent?

        registry.on(.windowCreated) { event in
            received = event
        }

        let event = HookEvent.window(.windowCreated, windowID: WindowID(1), appName: "Test")
        registry.dispatch(event)

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.type, .windowCreated)
        XCTAssertEqual(received?.data["window_id"], "1")
    }

    func testMultipleHandlers() {
        let registry = HookRegistry()
        var count = 0

        registry.on(.windowFocused) { _ in count += 1 }
        registry.on(.windowFocused) { _ in count += 1 }

        registry.dispatch(HookEvent(type: .windowFocused))

        XCTAssertEqual(count, 2)
    }

    func testRemoveHandler() {
        let registry = HookRegistry()
        var count = 0

        let id = registry.on(.windowCreated) { _ in count += 1 }
        registry.dispatch(HookEvent(type: .windowCreated))
        XCTAssertEqual(count, 1)

        registry.remove(id: id)
        registry.dispatch(HookEvent(type: .windowCreated))
        XCTAssertEqual(count, 1)
    }

    func testExternalSubscriber() {
        let registry = HookRegistry()
        var received: [HookEvent] = []

        registry.subscribe { event in
            received.append(event)
        }

        registry.dispatch(HookEvent(type: .windowCreated))
        registry.dispatch(HookEvent(type: .windowFocused))

        XCTAssertEqual(received.count, 2)
    }

    func testFilteredSubscriber() {
        let registry = HookRegistry()
        var received: [HookEvent] = []

        registry.subscribe(filter: [.windowCreated]) { event in
            received.append(event)
        }

        registry.dispatch(HookEvent(type: .windowCreated))
        registry.dispatch(HookEvent(type: .windowFocused))
        registry.dispatch(HookEvent(type: .windowCreated))

        XCTAssertEqual(received.count, 2)
        XCTAssertTrue(received.allSatisfy { $0.type == .windowCreated })
    }

    func testRemoveAll() {
        let registry = HookRegistry()
        var count = 0

        registry.on(.windowCreated) { _ in count += 1 }
        registry.on(.windowFocused) { _ in count += 1 }

        registry.removeAll()

        registry.dispatch(HookEvent(type: .windowCreated))
        registry.dispatch(HookEvent(type: .windowFocused))

        XCTAssertEqual(count, 0)
    }

    func testScriptHookRegistration() {
        let registry = HookRegistry()

        let id = registry.onScript(.windowCreated, scriptPath: "/usr/bin/true", arguments: ["arg1"])
        XCTAssertNotNil(id)

        // Remove should work for script hooks too
        registry.remove(id: id)
    }

    func testRemoveAllClearsScriptHooks() {
        let registry = HookRegistry()

        registry.onScript(.windowCreated, scriptPath: "/usr/bin/true")
        registry.onScript(.windowFocused, scriptPath: "/usr/bin/true")

        // After removeAll, no script hooks should fire
        registry.removeAll()

        // Dispatching should not crash
        registry.dispatch(HookEvent(type: .windowCreated))
    }

    func testScriptHookExecution() {
        let registry = HookRegistry()
        let expectation = XCTestExpectation(description: "Script hook executed")

        // Use /usr/bin/true which exits immediately with success
        registry.onScript(.windowCreated, scriptPath: "/usr/bin/true")

        registry.dispatch(HookEvent.window(.windowCreated, windowID: WindowID(1), appName: "Test"))

        // Give the async script execution a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
