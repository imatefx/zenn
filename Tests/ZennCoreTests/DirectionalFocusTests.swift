import XCTest
@testable import ZennCore
@testable import ZennShared

final class DirectionalFocusTests: XCTestCase {

    func testFocusRight() {
        let left = Rect(x: 0, y: 0, width: 960, height: 1080)
        let right = Rect(x: 960, y: 0, width: 960, height: 1080)

        let candidates: [(WindowID, Rect)] = [
            (WindowID(1), left),
            (WindowID(2), right),
        ]

        let target = DirectionalFocus.bestTarget(
            from: WindowID(1),
            sourceFrame: left,
            candidates: candidates,
            direction: .right
        )

        XCTAssertEqual(target, WindowID(2))
    }

    func testFocusLeft() {
        let left = Rect(x: 0, y: 0, width: 960, height: 1080)
        let right = Rect(x: 960, y: 0, width: 960, height: 1080)

        let candidates: [(WindowID, Rect)] = [
            (WindowID(1), left),
            (WindowID(2), right),
        ]

        let target = DirectionalFocus.bestTarget(
            from: WindowID(2),
            sourceFrame: right,
            candidates: candidates,
            direction: .left
        )

        XCTAssertEqual(target, WindowID(1))
    }

    func testFocusDown() {
        let top = Rect(x: 0, y: 0, width: 1920, height: 540)
        let bottom = Rect(x: 0, y: 540, width: 1920, height: 540)

        let candidates: [(WindowID, Rect)] = [
            (WindowID(1), top),
            (WindowID(2), bottom),
        ]

        let target = DirectionalFocus.bestTarget(
            from: WindowID(1),
            sourceFrame: top,
            candidates: candidates,
            direction: .down
        )

        XCTAssertEqual(target, WindowID(2))
    }

    func testFocusUp() {
        let top = Rect(x: 0, y: 0, width: 1920, height: 540)
        let bottom = Rect(x: 0, y: 540, width: 1920, height: 540)

        let candidates: [(WindowID, Rect)] = [
            (WindowID(1), top),
            (WindowID(2), bottom),
        ]

        let target = DirectionalFocus.bestTarget(
            from: WindowID(2),
            sourceFrame: bottom,
            candidates: candidates,
            direction: .up
        )

        XCTAssertEqual(target, WindowID(1))
    }

    func testNoTargetInDirection() {
        let window = Rect(x: 0, y: 0, width: 960, height: 1080)

        let candidates: [(WindowID, Rect)] = [
            (WindowID(1), window),
        ]

        let target = DirectionalFocus.bestTarget(
            from: WindowID(1),
            sourceFrame: window,
            candidates: candidates,
            direction: .right
        )

        XCTAssertNil(target)
    }

    func testPreferOverlappingWindows() {
        // Three windows: source on left, two on right (one overlapping, one not)
        let source = Rect(x: 0, y: 100, width: 960, height: 500)
        let overlapping = Rect(x: 960, y: 50, width: 960, height: 500)
        let nonOverlapping = Rect(x: 960, y: 700, width: 960, height: 300)

        let candidates: [(WindowID, Rect)] = [
            (WindowID(1), source),
            (WindowID(2), overlapping),
            (WindowID(3), nonOverlapping),
        ]

        let target = DirectionalFocus.bestTarget(
            from: WindowID(1),
            sourceFrame: source,
            candidates: candidates,
            direction: .right
        )

        XCTAssertEqual(target, WindowID(2))
    }
}
