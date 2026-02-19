import XCTest
@testable import ZennCore
@testable import ZennShared

final class TreeOperationsTests: XCTestCase {

    // MARK: - Insert Window

    func testInsertWindowIntoEmptyTree() {
        let window = makeWindowNode(id: 1)
        let root = TreeOperations.insertWindow(root: nil, window: window, nearWindowID: nil)

        XCTAssertEqual(root.children.count, 1)
        XCTAssertEqual(root.allWindowIDs, [WindowID(1)])
    }

    func testInsertMultipleWindows() {
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)
        let w3 = makeWindowNode(id: 3)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))
        root = TreeOperations.insertWindow(root: root, window: w3, nearWindowID: WindowID(2))

        XCTAssertEqual(root.children.count, 3)
        XCTAssertEqual(root.allWindowIDs.count, 3)
    }

    func testInsertWindowWithDifferentAxis() {
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        let root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil, axis: .horizontal)
        let updatedRoot = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1), axis: .vertical)

        // w2 should be in a sub-container with different axis
        XCTAssertEqual(updatedRoot.allWindowIDs.count, 2)
    }

    // MARK: - Remove Window

    func testRemoveWindow() {
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))

        let (newRoot, removed) = TreeOperations.removeWindow(root: root, windowID: WindowID(1))

        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.windowID, WindowID(1))
        XCTAssertNotNil(newRoot)
        XCTAssertEqual(newRoot?.allWindowIDs, [WindowID(2)])
    }

    func testRemoveLastWindow() {
        let w1 = makeWindowNode(id: 1)
        let root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)

        let (newRoot, removed) = TreeOperations.removeWindow(root: root, windowID: WindowID(1))

        XCTAssertNotNil(removed)
        XCTAssertNil(newRoot)
    }

    func testRemoveNonexistentWindow() {
        let w1 = makeWindowNode(id: 1)
        let root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)

        let (newRoot, removed) = TreeOperations.removeWindow(root: root, windowID: WindowID(999))

        XCTAssertNil(removed)
        XCTAssertNotNil(newRoot)
    }

    // MARK: - Swap Windows

    func testSwapWindows() {
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)
        let w3 = makeWindowNode(id: 3)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))
        root = TreeOperations.insertWindow(root: root, window: w3, nearWindowID: WindowID(2))

        let success = TreeOperations.swapWindows(root: root, windowA: WindowID(1), windowB: WindowID(3))

        XCTAssertTrue(success)

        // Check the order changed
        let windows = TreeTraversal.allWindows(in: root)
        XCTAssertEqual(windows[0].windowID, WindowID(3))
        XCTAssertEqual(windows[2].windowID, WindowID(1))
    }

    // MARK: - Resize (right/up = grow, left/down = shrink)

    func testResizeGrowRight() {
        // H[w1, w2] — resize w1 right → w1 grows
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))

        let success = TreeOperations.resizeWindow(root: root, windowID: WindowID(1), direction: .right, delta: 0.1)
        XCTAssertTrue(success)
        XCTAssertEqual(root.ratios[0], 0.6, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.4, accuracy: 0.01)
    }

    func testResizeShrinkLeft() {
        // H[w1, w2] — resize w1 left → w1 shrinks
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))

        let success = TreeOperations.resizeWindow(root: root, windowID: WindowID(1), direction: .left, delta: 0.1)
        XCTAssertTrue(success)
        XCTAssertEqual(root.ratios[0], 0.4, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.6, accuracy: 0.01)
    }

    func testResizeGrowRightSecondWindow() {
        // H[w1, w2] — resize w2 right → w2 grows
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))

        let success = TreeOperations.resizeWindow(root: root, windowID: WindowID(2), direction: .right, delta: 0.1)
        XCTAssertTrue(success)
        // w2 is last, so neighbor is w1 (idx-1 fallback) — w2 grows, w1 shrinks
        XCTAssertEqual(root.ratios[0], 0.4, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.6, accuracy: 0.01)
    }

    func testResizeShrinkLeftSecondWindow() {
        // H[w1, w2] — resize w2 left → w2 shrinks
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))

        let success = TreeOperations.resizeWindow(root: root, windowID: WindowID(2), direction: .left, delta: 0.1)
        XCTAssertTrue(success)
        // left = shrink, w2 shrinks, w1 grows
        XCTAssertEqual(root.ratios[0], 0.6, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.4, accuracy: 0.01)
    }

    // MARK: - Presets

    func testApplyPreset() {
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1))

        TreeOperations.applyPreset(root: root, preset: .masterLg)

        XCTAssertEqual(root.ratios[0], 0.6, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.4, accuracy: 0.01)

        TreeOperations.applyPreset(root: root, preset: .masterXl)

        XCTAssertEqual(root.ratios[0], 0.7, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.3, accuracy: 0.01)

        TreeOperations.applyPreset(root: root, preset: .equal)

        XCTAssertEqual(root.ratios[0], 0.5, accuracy: 0.01)
        XCTAssertEqual(root.ratios[1], 0.5, accuracy: 0.01)
    }

    // MARK: - Merge Windows

    func testMergeWindowsCreatesSubContainer() {
        // Setup: H[A, B, C] — three windows in horizontal container
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)
        let w3 = makeWindowNode(id: 3)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil, axis: .horizontal)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1), axis: .horizontal)
        root = TreeOperations.insertWindow(root: root, window: w3, nearWindowID: WindowID(2), axis: .horizontal)

        // H[w1, w2, w3], merge w3 into w2
        let success = TreeOperations.mergeWindows(root: root, sourceWindowID: WindowID(3), targetWindowID: WindowID(2))

        XCTAssertTrue(success)
        // Result should be H[w1, V[w2, w3]]
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(root.allWindowIDs.count, 3)

        // Second child should be a container with perpendicular axis
        if case .container(let subContainer) = root.children[1] {
            XCTAssertEqual(subContainer.axis, .vertical)
            XCTAssertEqual(subContainer.children.count, 2)
            XCTAssertEqual(subContainer.allWindowIDs, [WindowID(2), WindowID(3)])
        } else {
            XCTFail("Expected second child to be a container")
        }
    }

    func testMergeWindowsSameParent() {
        // Setup: H[A, B] — merge B into A
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil, axis: .horizontal)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1), axis: .horizontal)

        let success = TreeOperations.mergeWindows(root: root, sourceWindowID: WindowID(2), targetWindowID: WindowID(1))

        XCTAssertTrue(success)
        XCTAssertEqual(root.allWindowIDs.count, 2)
        // After normalization, root might be restructured since it now has a single sub-container child
        // The key thing is both windows are present
        XCTAssertTrue(root.allWindowIDs.contains(WindowID(1)))
        XCTAssertTrue(root.allWindowIDs.contains(WindowID(2)))
    }

    // MARK: - Eject Window

    func testEjectWindowFromSubContainer() {
        // Build H[w1, V[w2, w3]] manually
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)
        let w3 = makeWindowNode(id: 3)

        let root = ContainerNode(axis: .horizontal)
        root.appendChild(.window(w1))
        let sub = ContainerNode(axis: .vertical, parent: root)
        sub.appendChild(.window(w2))
        sub.appendChild(.window(w3))
        root.appendChild(.container(sub))

        // Eject w3 out of the sub-container
        let success = TreeOperations.ejectWindow(root: root, windowID: WindowID(3))
        XCTAssertTrue(success)

        // Result should be H[w1, w2, w3] (sub-container collapsed by normalization)
        XCTAssertEqual(root.allWindowIDs.count, 3)
        XCTAssertEqual(root.children.count, 3)

        let windows = TreeTraversal.allWindows(in: root)
        XCTAssertEqual(windows.map { $0.windowID }, [WindowID(1), WindowID(2), WindowID(3)])
    }

    func testEjectFromRootLevelFails() {
        let w1 = makeWindowNode(id: 1)
        let w2 = makeWindowNode(id: 2)

        var root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil, axis: .horizontal)
        root = TreeOperations.insertWindow(root: root, window: w2, nearWindowID: WindowID(1), axis: .horizontal)

        // w1 is at root level, can't eject further
        let success = TreeOperations.ejectWindow(root: root, windowID: WindowID(1))
        XCTAssertFalse(success)
    }

    func testMergeNonexistentWindowFails() {
        let w1 = makeWindowNode(id: 1)
        let root = TreeOperations.insertWindow(root: nil, window: w1, nearWindowID: nil)

        let success = TreeOperations.mergeWindows(root: root, sourceWindowID: WindowID(999), targetWindowID: WindowID(1))
        XCTAssertFalse(success)
    }

    // MARK: - Helpers

    private func makeWindowNode(id: UInt32) -> WindowNode {
        WindowNode(
            windowID: WindowID(id),
            appBundleID: "com.test.app",
            appName: "TestApp",
            windowTitle: "Window \(id)"
        )
    }
}
