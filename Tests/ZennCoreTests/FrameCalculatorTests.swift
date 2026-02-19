import XCTest
@testable import ZennCore
@testable import ZennShared

final class FrameCalculatorTests: XCTestCase {

    let screenFrame = Rect(x: 0, y: 0, width: 1920, height: 1080)
    let noGaps = GapConfig.zero

    func testSingleWindowGetsFullFrame() {
        let root = ContainerNode(axis: .horizontal)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        root.appendChild(.window(w1))

        let frames = FrameCalculator.calculateFrames(root: root, availableFrame: screenFrame, gaps: noGaps)

        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[WindowID(1)], screenFrame)
    }

    func testTwoWindowsHorizontalSplit() {
        let root = ContainerNode(axis: .horizontal)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")
        root.appendChild(.window(w1))
        root.appendChild(.window(w2))

        let frames = FrameCalculator.calculateFrames(root: root, availableFrame: screenFrame, gaps: noGaps)

        XCTAssertEqual(frames.count, 2)

        let f1 = frames[WindowID(1)]!
        let f2 = frames[WindowID(2)]!

        XCTAssertEqual(f1.width, 960, accuracy: 1)
        XCTAssertEqual(f2.width, 960, accuracy: 1)
        XCTAssertEqual(f1.x, 0, accuracy: 1)
        XCTAssertEqual(f2.x, 960, accuracy: 1)
    }

    func testTwoWindowsVerticalSplit() {
        let root = ContainerNode(axis: .vertical)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")
        root.appendChild(.window(w1))
        root.appendChild(.window(w2))

        let frames = FrameCalculator.calculateFrames(root: root, availableFrame: screenFrame, gaps: noGaps)

        let f1 = frames[WindowID(1)]!
        let f2 = frames[WindowID(2)]!

        XCTAssertEqual(f1.height, 540, accuracy: 1)
        XCTAssertEqual(f2.height, 540, accuracy: 1)
        XCTAssertEqual(f1.y, 0, accuracy: 1)
        XCTAssertEqual(f2.y, 540, accuracy: 1)
    }

    func testCustomRatios() {
        let root = ContainerNode(axis: .horizontal)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")
        root.appendChild(.window(w1))
        root.appendChild(.window(w2))
        root.ratios = [0.7, 0.3]

        let frames = FrameCalculator.calculateFrames(root: root, availableFrame: screenFrame, gaps: noGaps)

        let f1 = frames[WindowID(1)]!
        let f2 = frames[WindowID(2)]!

        XCTAssertEqual(f1.width, 1344, accuracy: 1)
        XCTAssertEqual(f2.width, 576, accuracy: 1)
    }

    func testWithGaps() {
        let gaps = GapConfig(inner: 10, outerAll: 20)
        let root = ContainerNode(axis: .horizontal)
        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")
        root.appendChild(.window(w1))
        root.appendChild(.window(w2))

        // Apply outer gaps to available frame first
        let tilingArea = GapCalculator.tilingArea(screenFrame: screenFrame, gaps: gaps)
        let frames = FrameCalculator.calculateFrames(root: root, availableFrame: tilingArea, gaps: gaps)

        let f1 = frames[WindowID(1)]!
        let f2 = frames[WindowID(2)]!

        // Each window should have inner gaps (half on each side)
        XCTAssertGreaterThan(f1.x, tilingArea.x)
        XCTAssertLessThan(f1.width + f1.x, tilingArea.maxX)
    }

    func testNestedSplits() {
        // H[V[w1, w2], w3]
        let root = ContainerNode(axis: .horizontal)
        let inner = ContainerNode(axis: .vertical, parent: root)

        let w1 = WindowNode(windowID: WindowID(1), appBundleID: "test", appName: "Test")
        let w2 = WindowNode(windowID: WindowID(2), appBundleID: "test", appName: "Test")
        let w3 = WindowNode(windowID: WindowID(3), appBundleID: "test", appName: "Test")

        inner.appendChild(.window(w1))
        inner.appendChild(.window(w2))
        root.appendChild(.container(inner))
        root.appendChild(.window(w3))

        let frames = FrameCalculator.calculateFrames(root: root, availableFrame: screenFrame, gaps: noGaps)

        XCTAssertEqual(frames.count, 3)

        let f1 = frames[WindowID(1)]!
        let f2 = frames[WindowID(2)]!
        let f3 = frames[WindowID(3)]!

        // w1 and w2 should share the left half vertically
        XCTAssertEqual(f1.width, 960, accuracy: 1)
        XCTAssertEqual(f1.height, 540, accuracy: 1)
        XCTAssertEqual(f2.width, 960, accuracy: 1)
        XCTAssertEqual(f2.height, 540, accuracy: 1)

        // w3 should take the right half
        XCTAssertEqual(f3.width, 960, accuracy: 1)
        XCTAssertEqual(f3.height, 1080, accuracy: 1)
    }
}
