import XCTest
@testable import ZennCore
@testable import ZennShared

final class TreeNormalizationTests: XCTestCase {

    func testFlattenSingleChildContainer() {
        // Create root -> container -> window
        let root = ContainerNode(axis: .horizontal)
        let inner = ContainerNode(axis: .vertical, parent: root)
        let window = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        inner.appendChild(.window(window))
        root.appendChild(.container(inner))

        let normalized = TreeNormalization.normalize(root: root)

        // Should flatten: root should directly contain the window
        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized?.children.count, 1)
        XCTAssertTrue(normalized?.children[0].isWindow ?? false)
    }

    func testMergeSameAxisContainers() {
        // Create H[H[a, b], c] -> should become H[a, b, c]
        let root = ContainerNode(axis: .horizontal)
        let inner = ContainerNode(axis: .horizontal, parent: root)

        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")
        let w3 = WindowNode(windowID: WindowID(3), appBundleID: "test", appName: "Test")

        inner.appendChild(.window(w1))
        inner.appendChild(.window(w2))
        root.appendChild(.container(inner))
        root.appendChild(.window(w3))

        let normalized = TreeNormalization.normalize(root: root)

        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized?.children.count, 3)
        // All children should be windows
        for child in normalized?.children ?? [] {
            XCTAssertTrue(child.isWindow)
        }
    }

    func testRemoveEmptyContainers() {
        let root = ContainerNode(axis: .horizontal)
        let emptyContainer = ContainerNode(axis: .vertical, parent: root)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")

        root.appendChild(.container(emptyContainer))
        root.appendChild(.window(w1))

        let normalized = TreeNormalization.normalize(root: root)

        XCTAssertNotNil(normalized)
        // Empty container should be removed, leaving just the window
        XCTAssertEqual(normalized?.allWindowIDs.count, 1)
    }

    func testNormalizePreservesRatios() {
        let root = ContainerNode(axis: .horizontal)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")

        root.appendChild(.window(w1))
        root.appendChild(.window(w2))
        root.ratios = [0.6, 0.4]

        let normalized = TreeNormalization.normalize(root: root)

        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized?.children.count, 2)
        // Ratios should be preserved since no structural change occurred
        XCTAssertEqual(normalized?.ratios[0] ?? 0, 0.6, accuracy: 0.01)
        XCTAssertEqual(normalized?.ratios[1] ?? 0, 0.4, accuracy: 0.01)
    }

    func testNormalizeEmptyTreeReturnsNil() {
        let root = ContainerNode(axis: .horizontal)
        let normalized = TreeNormalization.normalize(root: root)
        XCTAssertNil(normalized)
    }
}
