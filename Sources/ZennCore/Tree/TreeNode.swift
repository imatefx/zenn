import Foundation
import ZennShared

/// A node in the binary tiling tree. Either a container (internal) or a window (leaf).
public indirect enum TreeNode {
    case container(ContainerNode)
    case window(WindowNode)

    /// The unique ID of this node.
    public var id: NodeID {
        switch self {
        case .container(let node): return node.id
        case .window(let node): return node.id
        }
    }

    /// The parent container, if any.
    public var parent: ContainerNode? {
        switch self {
        case .container(let node): return node.parent
        case .window(let node): return node.parent
        }
    }

    /// Set the parent of this node.
    public mutating func setParent(_ parent: ContainerNode?) {
        switch self {
        case .container(var node):
            node.parent = parent
            self = .container(node)
        case .window(var node):
            node.parent = parent
            self = .window(node)
        }
    }

    /// Whether this is a window (leaf) node.
    public var isWindow: Bool {
        if case .window = self { return true }
        return false
    }

    /// Whether this is a container (internal) node.
    public var isContainer: Bool {
        if case .container = self { return true }
        return false
    }

    /// Get the window node, if this is a window.
    public var windowNode: WindowNode? {
        if case .window(let node) = self { return node }
        return nil
    }

    /// Get the container node, if this is a container.
    public var containerNode: ContainerNode? {
        if case .container(let node) = self { return node }
        return nil
    }

    /// All window IDs in this subtree.
    public var allWindowIDs: [WindowID] {
        switch self {
        case .window(let node):
            return [node.windowID]
        case .container(let node):
            return node.children.flatMap { $0.allWindowIDs }
        }
    }

    /// All window nodes in this subtree (in-order traversal).
    public var allWindowNodes: [WindowNode] {
        switch self {
        case .window(let node):
            return [node]
        case .container(let node):
            return node.children.flatMap { $0.allWindowNodes }
        }
    }

    /// Count of all windows in this subtree.
    public var windowCount: Int {
        switch self {
        case .window: return 1
        case .container(let node): return node.children.reduce(0) { $0 + $1.windowCount }
        }
    }

    /// The depth of this node in the tree (0 = root).
    public var depth: Int {
        var d = 0
        var current = parent
        while let p = current {
            d += 1
            current = p.parent
        }
        return d
    }
}

extension TreeNode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .container(let node):
            return "Container(\(node.id), \(node.axis), children=\(node.children.count))"
        case .window(let node):
            return "Window(\(node.id), \(node.windowID))"
        }
    }
}
