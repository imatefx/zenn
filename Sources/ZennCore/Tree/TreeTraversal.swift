import Foundation
import ZennShared

/// Tree traversal and search operations (read-only).
public enum TreeTraversal {
    /// Find the parent container and child index for a window with the given ID.
    public static func findWindowLocation(
        in root: ContainerNode,
        windowID: WindowID
    ) -> (container: ContainerNode, index: Int)? {
        for (index, child) in root.children.enumerated() {
            switch child {
            case .window(let node):
                if node.windowID == windowID {
                    return (root, index)
                }
            case .container(let node):
                if let result = findWindowLocation(in: node, windowID: windowID) {
                    return result
                }
            }
        }
        return nil
    }

    /// Find a window node by its window ID.
    public static func findWindowNode(
        in root: ContainerNode,
        windowID: WindowID
    ) -> WindowNode? {
        for child in root.children {
            switch child {
            case .window(let node):
                if node.windowID == windowID {
                    return node
                }
            case .container(let node):
                if let result = findWindowNode(in: node, windowID: windowID) {
                    return result
                }
            }
        }
        return nil
    }

    /// Find a node by its node ID.
    public static func findNode(
        in root: ContainerNode,
        nodeID: NodeID
    ) -> TreeNode? {
        if root.id == nodeID {
            return .container(root)
        }
        for child in root.children {
            switch child {
            case .window(let node):
                if node.id == nodeID {
                    return child
                }
            case .container(let node):
                if let result = findNode(in: node, nodeID: nodeID) {
                    return result
                }
            }
        }
        return nil
    }

    /// Get all windows in the tree in left-to-right, top-to-bottom order.
    public static func allWindows(in root: ContainerNode) -> [WindowNode] {
        var result: [WindowNode] = []
        collectWindows(node: .container(root), into: &result)
        return result
    }

    private static func collectWindows(node: TreeNode, into result: inout [WindowNode]) {
        switch node {
        case .window(let windowNode):
            result.append(windowNode)
        case .container(let containerNode):
            for child in containerNode.children {
                collectWindows(node: child, into: &result)
            }
        }
    }

    /// Find the next window in traversal order after the given window.
    public static func nextWindow(
        in root: ContainerNode,
        after windowID: WindowID
    ) -> WindowNode? {
        let windows = allWindows(in: root)
        guard let currentIndex = windows.firstIndex(where: { $0.windowID == windowID }) else {
            return windows.first
        }
        let nextIndex = (currentIndex + 1) % windows.count
        return windows[nextIndex]
    }

    /// Find the previous window in traversal order before the given window.
    public static func previousWindow(
        in root: ContainerNode,
        before windowID: WindowID
    ) -> WindowNode? {
        let windows = allWindows(in: root)
        guard let currentIndex = windows.firstIndex(where: { $0.windowID == windowID }) else {
            return windows.last
        }
        let prevIndex = (currentIndex - 1 + windows.count) % windows.count
        return windows[prevIndex]
    }

    /// Find the neighbor window in a given direction from the specified window.
    /// This uses geometric position to determine neighbors.
    public static func findNeighbor(
        in root: ContainerNode,
        from windowID: WindowID,
        direction: Direction,
        frames: [WindowID: Rect]
    ) -> WindowNode? {
        guard let fromFrame = frames[windowID] else { return nil }

        let windows = allWindows(in: root)
        var bestCandidate: WindowNode?
        var bestDistance: Double = .infinity

        let fromCenter = CGPoint(x: fromFrame.midX, y: fromFrame.midY)

        for window in windows {
            guard window.windowID != windowID,
                  let candidateFrame = frames[window.windowID] else {
                continue
            }

            let candidateCenter = CGPoint(x: candidateFrame.midX, y: candidateFrame.midY)

            // Check if the candidate is in the correct direction
            let isInDirection: Bool
            switch direction {
            case .left:
                isInDirection = candidateCenter.x < fromCenter.x
            case .right:
                isInDirection = candidateCenter.x > fromCenter.x
            case .up:
                isInDirection = candidateCenter.y < fromCenter.y
            case .down:
                isInDirection = candidateCenter.y > fromCenter.y
            }

            guard isInDirection else { continue }

            // Calculate distance (Manhattan for simplicity, weighted by axis)
            let dx = abs(candidateCenter.x - fromCenter.x)
            let dy = abs(candidateCenter.y - fromCenter.y)
            let distance: Double

            switch direction {
            case .left, .right:
                distance = Double(dx + dy * 0.5)
            case .up, .down:
                distance = Double(dy + dx * 0.5)
            }

            if distance < bestDistance {
                bestDistance = distance
                bestCandidate = window
            }
        }

        return bestCandidate
    }

    /// Create a serializable snapshot of the tree.
    public static func snapshot(of root: ContainerNode, frames: [WindowID: Rect] = [:]) -> TreeSnapshot {
        snapshotNode(.container(root), frames: frames)
    }

    private static func snapshotNode(_ node: TreeNode, frames: [WindowID: Rect]) -> TreeSnapshot {
        switch node {
        case .container(let container):
            return TreeSnapshot(
                nodeType: .container,
                id: container.id.rawValue.uuidString,
                children: container.children.map { snapshotNode($0, frames: frames) },
                axis: container.axis,
                ratios: container.ratios.map { Double($0) }
            )
        case .window(let window):
            return TreeSnapshot(
                nodeType: .window,
                id: window.id.rawValue.uuidString,
                windowID: window.windowID,
                appName: window.appName,
                windowTitle: window.windowTitle,
                frame: frames[window.windowID]
            )
        }
    }
}
